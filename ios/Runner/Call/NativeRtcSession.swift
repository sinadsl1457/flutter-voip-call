import AgoraRtcKit
import Foundation

enum NativeRtcError: Error {
  case joinFailed(Int32)
}

/// CallKit 으로 받은 통화의 오디오 채널.
///
/// CXAnswerCallAction 은 앱이 백그라운드/종료 상태여도 바로 처리돼야 하는데, 이때 Flutter 엔진과
/// Dart 의 agora_rtc_engine 이 준비돼 있다는 보장이 없다. 그래서 iOS 수신 통화는 네이티브 Agora SDK
/// (agora_rtc_engine 플러그인이 이미 포함하고 있는 AgoraRtcKit)로 직접 채널에 들어간다.
final class NativeRtcSession: NSObject {
  static let shared = NativeRtcSession()

  /// 상대가 채널에서 나감 → CallKitController 가 통화를 종료한다.
  var onRemoteLeft: ((String) -> Void)?
  /// 재연결까지 실패.
  var onConnectionLost: ((String) -> Void)?

  private var engine: AgoraRtcEngineKit?
  private(set) var channelId: String?

  func join(appId: String, channelId: String, token: String, uid: UInt) throws {
    let engine = self.engine ?? makeEngine(appId: appId)
    self.engine = engine
    self.channelId = channelId

    let code = engine.joinChannel(byToken: token, channelId: channelId, info: nil, uid: uid) { channel, uid, elapsed in
      CallLog.info("[NativeRtcSession] joined \(String(describing: channel)) uid=\(uid) (\(elapsed)ms)")
    }
    if code != 0 {
      leave()
      throw NativeRtcError.joinFailed(code)
    }
  }

  func leave() {
    guard let engine else { return }
    engine.leaveChannel(nil)
    AgoraRtcEngineKit.destroy()
    self.engine = nil
    channelId = nil
  }

  func setMuted(_ muted: Bool) {
    engine?.muteLocalAudioStream(muted)
  }

  func setSpeaker(_ enabled: Bool) {
    engine?.setEnableSpeakerphone(enabled)
  }

  private func makeEngine(appId: String) -> AgoraRtcEngineKit {
    let engine = AgoraRtcEngineKit.sharedEngine(withAppId: appId, delegate: self)
    engine.setChannelProfile(.communication)
    engine.setClientRole(.broadcaster)
    engine.enableAudio()
    engine.disableVideo()
    engine.setDefaultAudioRouteToSpeakerphone(false)
    return engine
  }
}

extension NativeRtcSession: AgoraRtcEngineDelegate {
  func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
    CallLog.info("[NativeRtcSession] remote offline uid=\(uid) reason=\(reason.rawValue)")
    guard let channelId else { return }
    onRemoteLeft?(channelId)
  }

  func rtcEngine(
    _ engine: AgoraRtcEngineKit,
    connectionChangedTo state: AgoraConnectionState,
    reason: AgoraConnectionChangedReason
  ) {
    CallLog.info("[NativeRtcSession] connection state=\(state.rawValue) reason=\(reason.rawValue)")
    guard state == .failed, let channelId else { return }
    onConnectionLost?(channelId)
  }

  func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
    CallLog.error("[NativeRtcSession] error \(errorCode.rawValue)")
  }
}
