import Foundation
import PushKit

/// PushKit(VoIP 푸시) 수신.
///
/// 서버 계약상 VoIP 푸시는 CALL_START 전용이고, 제어 메시지(CALL_ACCEPTED / STOP_RINGING / CALL_END)는
/// 일반 APNs(FCM)로 온다. 다만 서버 설정 실수나 과거 버전 서버를 대비해 제어 메시지가 VoIP 로 와도 처리한다.
/// 이때도 "VoIP 푸시마다 CallKit 리포트" 정책은 지켜야 한다 (CallKitController.reportAndEndImmediately).
final class VoIPPushHandler: NSObject {
  static let shared = VoIPPushHandler()

  private var registry: PKPushRegistry?

  func start() {
    let registry = PKPushRegistry(queue: .main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    self.registry = registry
  }
}

extension VoIPPushHandler: PKPushRegistryDelegate {
  func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    guard type == .voIP else { return }
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    NativeCredentialStore.shared.voipToken = token
    CallEventStreamer.shared.emit(CallContract.Event.voipToken, ["token": token])
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    guard type == .voIP else { return }
    NativeCredentialStore.shared.voipToken = nil
    CallEventStreamer.shared.emit(CallContract.Event.voipToken, ["token": NSNull()])
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else {
      completion()
      return
    }

    let callKit = CallKitController.shared
    guard let call = VoipCallPayload(pushPayload: payload.dictionaryPayload) else {
      CallLog.error("VoIP push: unparsable payload")
      callKit.reportAndEndImmediately(completion: completion)
      return
    }
    CallLog.info("VoIP push: \(call.type) channel=\(call.channelId)")

    switch call.type {
    case CallContract.PushType.start:
      callKit.reportIncoming(call, completion: completion)

    case CallContract.PushType.stopRinging, CallContract.PushType.end:
      let fallback = call.type == CallContract.PushType.end
        ? CallContract.EndReason.remoteHangup
        : CallContract.EndReason.cancelled
      let reason = call.reason ?? fallback

      if call.type == CallContract.PushType.stopRinging, callKit.isAnswered(call.channelId) {
        // 이 기기가 받은 통화 — 무시. (활성 CallKit 통화가 있으므로 별도 리포트는 필요 없다)
        completion()
        return
      }
      if callKit.hasCall(call.channelId) {
        callKit.endFromRemote(channelId: call.channelId, reason: reason)
        completion()
      } else {
        CallEventStreamer.shared.emit(CallContract.Event.ended, ["channelId": call.channelId, "reason": reason])
        callKit.reportAndEndImmediately(completion: completion)
      }

    case CallContract.PushType.accepted:
      CallEventStreamer.shared.emit(CallContract.Event.peerAccepted, ["channelId": call.channelId])
      callKit.reportAndEndImmediately(completion: completion)

    default:
      callKit.reportAndEndImmediately(completion: completion)
    }
  }
}
