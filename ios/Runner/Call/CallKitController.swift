import AVFoundation
import CallKit
import UIKit

/// CallKit 통화 생명주기 + 네이티브 미디어(NativeRtcSession) + Flutter 통지.
///
/// iOS 수신 통화에서 상태의 출처는 CallKit 이다.
/// - 수락/거절/종료/음소거는 시스템 UI(잠금화면 포함)에서도 일어나므로 CXProviderDelegate 에서 처리하고,
///   결과를 Flutter 로 이벤트로 보낸다.
/// - Flutter 화면에서 누른 음소거·종료도 CXCallController 트랜잭션으로 보내서 같은 delegate 경로를 탄다.
///   (직접 Agora 를 건드리면 CallKit UI 의 음소거 버튼과 Flutter 화면이 어긋난다)
final class CallKitController: NSObject {
  static let shared = CallKitController()

  private static let ringTimeout: TimeInterval = 60

  private let provider: CXProvider
  private let callController = CXCallController()
  private let store = CallStore.shared
  private let credentials = NativeCredentialStore.shared
  private let api = CallApiClient.shared
  private let rtc = NativeRtcSession.shared
  private let events = CallEventStreamer.shared

  private var uuidByChannel: [String: UUID] = [:]
  private var channelByUUID: [UUID: String] = [:]
  private var answeredChannels: Set<String> = []
  /// Flutter 가 이미 서버 종료 API 를 호출하고 요청한 종료. CXEndCallAction 에서 API 를 다시 부르지 않는다.
  private var endsRequestedByFlutter: Set<UUID> = []
  private var ringTimeouts: [String: DispatchWorkItem] = [:]
  private var observingRoute = false

  private override init() {
    let config = CXProviderConfiguration()
    config.supportsVideo = false
    config.maximumCallGroups = 1
    config.maximumCallsPerCallGroup = 1
    config.supportedHandleTypes = [.generic]
    config.includesCallsInRecents = false
    provider = CXProvider(configuration: config)
    super.init()
    // queue: nil → delegate 는 메인 큐. 이 클래스의 상태는 메인 스레드에서만 만진다.
    provider.setDelegate(self, queue: nil)

    rtc.onRemoteLeft = { [weak self] channelId in
      self?.endFromRemote(channelId: channelId, reason: CallContract.EndReason.remoteHangup)
    }
    rtc.onConnectionLost = { [weak self] channelId in
      self?.endFromRemote(channelId: channelId, reason: CallContract.EndReason.failed)
      Task { try? await self?.api.end(channelId: channelId) }
    }
  }

  func hasCall(_ channelId: String) -> Bool { uuidByChannel[channelId] != nil }

  func isAnswered(_ channelId: String) -> Bool { answeredChannels.contains(channelId) }

  // MARK: - Incoming

  /// PushKit 콜백 안에서 호출. [completion] 은 PushKit 의 completion 이다.
  func reportIncoming(_ payload: VoipCallPayload, completion: @escaping () -> Void) {
    if uuidByChannel[payload.channelId] != nil {
      // 같은 CALL_START 재전송. 이미 시스템에 리포트된 통화가 있으므로 그대로 완료.
      completion()
      return
    }

    let uuid = UUID()
    uuidByChannel[payload.channelId] = uuid
    channelByUUID[uuid] = payload.channelId
    store.save(payload)

    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(type: .generic, value: payload.callerId.map { String($0) } ?? payload.channelId)
    update.localizedCallerName = payload.displayName
    update.hasVideo = false
    update.supportsHolding = false
    update.supportsGrouping = false
    update.supportsUngrouping = false
    update.supportsDTMF = false

    provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
      defer { completion() }
      guard let self else { return }

      if let error {
        // 방해금지 모드, 차단된 발신자, 이미 다른 통화 중 등
        CallLog.error("reportNewIncomingCall failed: \(error.localizedDescription)")
        self.forget(channelId: payload.channelId, uuid: uuid)
        return
      }

      self.configureAudioSession()
      self.scheduleRingTimeout(payload.channelId)
      self.events.emit(CallContract.Event.incoming, payload.flutterMap)
    }
  }

  /// iOS 13+ 정책: VoIP 푸시를 받으면 반드시 CallKit 에 통화를 리포트해야 한다. 안 하면 앱이 종료되고,
  /// 반복되면 시스템이 VoIP 푸시 전달을 중단한다.
  /// 제어 메시지(CALL_END 등)가 VoIP 로 왔는데 이 기기에 해당 통화가 없으면, 리포트 직후 바로 종료한다.
  func reportAndEndImmediately(completion: @escaping () -> Void) {
    let uuid = UUID()
    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(type: .generic, value: "ended")
    update.localizedCallerName = "종료된 통화"
    provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] _ in
      self?.provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
      completion()
    }
  }

  // MARK: - Ending

  /// 상대 취소/종료, 링 타임아웃, 상대 RTC 이탈.
  func endFromRemote(channelId: String, reason: String) {
    if let uuid = uuidByChannel[channelId] {
      provider.reportCall(with: uuid, endedAt: Date(), reason: cxReason(reason))
      teardown(channelId: channelId, uuid: uuid)
    }
    events.emit(CallContract.Event.ended, ["channelId": channelId, "reason": reason])
  }

  /// Flutter 가 통화를 끝낸 뒤 호출 (NativeCallBridge.releaseCall).
  func releaseFromFlutter(channelId: String) {
    guard let uuid = uuidByChannel[channelId] else {
      // CallKit 을 거치지 않은 통화(발신)거나 이미 정리됨
      if rtc.channelId == channelId { rtc.leave() }
      return
    }

    endsRequestedByFlutter.insert(uuid)
    callController.request(CXTransaction(action: CXEndCallAction(call: uuid))) { [weak self] error in
      guard let error else { return }
      // 이미 시스템에서 끝난 통화 등 → 시스템에 종료만 알리고 정리
      CallLog.error("end transaction failed: \(error.localizedDescription)")
      DispatchQueue.main.async {
        guard let self else { return }
        self.endsRequestedByFlutter.remove(uuid)
        self.provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
        self.teardown(channelId: channelId, uuid: uuid)
      }
    }
  }

  // MARK: - Media control from Flutter

  func setMutedFromFlutter(_ muted: Bool) {
    guard let channelId = rtc.channelId, let uuid = uuidByChannel[channelId] else { return }
    callController.request(CXTransaction(action: CXSetMutedCallAction(call: uuid, muted: muted))) { error in
      if let error { CallLog.error("mute transaction failed: \(error.localizedDescription)") }
    }
  }

  func setSpeakerFromFlutter(_ enabled: Bool) {
    rtc.setSpeaker(enabled)
    // 실제 라우트가 바뀌면 routeChange 옵저버가 한 번 더 보내서 실제 상태로 보정한다.
    events.emit(CallContract.Event.speakerChanged, ["enabled": enabled])
  }

  // MARK: - Private

  private func teardown(channelId: String, uuid: UUID) {
    cancelRingTimeout(channelId)
    if rtc.channelId == channelId { rtc.leave() }
    store.remove(channelId)
    forget(channelId: channelId, uuid: uuid)
    if uuidByChannel.isEmpty { stopObservingRoute() }
  }

  private func forget(channelId: String, uuid: UUID) {
    uuidByChannel.removeValue(forKey: channelId)
    channelByUUID.removeValue(forKey: uuid)
    answeredChannels.remove(channelId)
  }

  private func configureAudioSession() {
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playAndRecord,
        mode: .voiceChat,
        options: [.allowBluetooth, .allowBluetoothA2DP]
      )
    } catch {
      CallLog.error("audio session category failed: \(error.localizedDescription)")
    }
  }

  private func scheduleRingTimeout(_ channelId: String) {
    cancelRingTimeout(channelId)
    let work = DispatchWorkItem { [weak self] in
      guard let self, !self.isAnswered(channelId) else { return }
      self.endFromRemote(channelId: channelId, reason: CallContract.EndReason.noAnswer)
    }
    ringTimeouts[channelId] = work
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.ringTimeout, execute: work)
  }

  private func cancelRingTimeout(_ channelId: String) {
    ringTimeouts.removeValue(forKey: channelId)?.cancel()
  }

  private func startObservingRoute() {
    guard !observingRoute else { return }
    observingRoute = true
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(audioRouteChanged),
      name: AVAudioSession.routeChangeNotification,
      object: nil
    )
  }

  private func stopObservingRoute() {
    guard observingRoute else { return }
    observingRoute = false
    NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
  }

  @objc private func audioRouteChanged(_ notification: Notification) {
    let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
    let isSpeaker = outputs.contains { $0.portType == .builtInSpeaker }
    DispatchQueue.main.async {
      self.events.emit(CallContract.Event.speakerChanged, ["enabled": isSpeaker])
    }
  }

  private func cxReason(_ reason: String) -> CXCallEndedReason {
    switch reason {
    case CallContract.EndReason.noAnswer: return .unanswered
    case CallContract.EndReason.answeredElsewhere: return .answeredElsewhere
    case CallContract.EndReason.declined: return .declinedElsewhere
    case CallContract.EndReason.failed: return .failed
    default: return .remoteEnded
    }
  }

  /// 잠금화면에서 끊은 경우 앱이 곧 suspend 될 수 있으므로 background task 로 감싼다.
  private func notifyServerEnded(_ channelId: String) {
    Task { @MainActor in
      let app = UIApplication.shared
      let taskId = app.beginBackgroundTask(withName: "voipcall.end", expirationHandler: nil)
      defer { app.endBackgroundTask(taskId) }
      do {
        try await api.end(channelId: channelId)
      } catch {
        CallLog.error("end api failed: \(error)")
      }
    }
  }
}

// MARK: - CXProviderDelegate

extension CallKitController: CXProviderDelegate {
  func providerDidReset(_ provider: CXProvider) {
    rtc.leave()
    for channelId in uuidByChannel.keys {
      events.emit(CallContract.Event.ended, ["channelId": channelId, "reason": CallContract.EndReason.failed])
    }
    ringTimeouts.values.forEach { $0.cancel() }
    ringTimeouts.removeAll()
    uuidByChannel.removeAll()
    channelByUUID.removeAll()
    answeredChannels.removeAll()
    endsRequestedByFlutter.removeAll()
    store.removeAll()
    stopObservingRoute()
  }

  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    guard let channelId = channelByUUID[action.callUUID],
          let payload = store.get(channelId),
          let calleeId = payload.calleeId, let uid = UInt(exactly: calleeId),
          let rtcToken = payload.rtcToken,
          let appId = credentials.rtcAppId, !appId.isEmpty,
          let voipToken = credentials.voipToken
    else {
      CallLog.error("answer: missing call context")
      action.fail()
      return
    }

    cancelRingTimeout(channelId)
    configureAudioSession()

    // 수락 API → RTC join → fulfill 순서. 서버가 수락을 알아야 발신자에게 CALL_ACCEPTED 가 가고,
    // 다른 기기(같은 계정)에 STOP_RINGING 이 간다. acceptorToken 은 이 기기의 VoIP 토큰.
    Task { @MainActor in
      do {
        try await api.accept(channelId: channelId, acceptorToken: voipToken)
        try rtc.join(appId: appId, channelId: channelId, token: rtcToken, uid: uid)

        answeredChannels.insert(channelId)
        startObservingRoute()
        action.fulfill()

        var data = payload.flutterMap
        data["mediaOwner"] = "native"
        data["connectedAtMs"] = Int(Date().timeIntervalSince1970 * 1000)
        events.emit(CallContract.Event.answered, data)
      } catch {
        CallLog.error("answer failed: \(error)")
        action.fail()
        // 시스템 UI 정리 + 발신자가 계속 기다리지 않도록 서버에도 종료 통지
        endFromRemote(channelId: channelId, reason: CallContract.EndReason.failed)
        notifyServerEnded(channelId)
      }
    }
  }

  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    let uuid = action.callUUID
    guard let channelId = channelByUUID[uuid] else {
      action.fulfill()
      return
    }

    let requestedByFlutter = endsRequestedByFlutter.remove(uuid) != nil
    let wasAnswered = isAnswered(channelId)
    teardown(channelId: channelId, uuid: uuid)
    // 서버 응답을 기다리지 않고 바로 fulfill 한다. 실패 시 action.fail() 하면 시스템 통화 UI 가 남는다.
    action.fulfill()

    guard !requestedByFlutter else { return }
    let reason = wasAnswered ? CallContract.EndReason.localHangup : CallContract.EndReason.declined
    events.emit(CallContract.Event.ended, ["channelId": channelId, "reason": reason])
    notifyServerEnded(channelId)
  }

  func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
    rtc.setMuted(action.isMuted)
    events.emit(CallContract.Event.muteChanged, ["muted": action.isMuted])
    action.fulfill()
  }

  func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    CallLog.info("audio session activated")
  }

  func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    CallLog.info("audio session deactivated")
  }
}
