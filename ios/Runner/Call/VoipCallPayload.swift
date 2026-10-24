import Foundation
import os

/// os.Logger 래퍼. channelId 같은 값이 Release 로그에서 <private> 로 가려지지 않도록 public 으로 남긴다.
enum CallLog {
  private static let logger = Logger(subsystem: "dev.sintaek.voipcall", category: "call")

  static func info(_ message: String) { logger.info("\(message, privacy: .public)") }
  static func error(_ message: String) { logger.error("\(message, privacy: .public)") }
}

/// Dart / Android 와 공유하는 문자열 계약.
/// 바꿀 때는 lib/features/call/native/ 와 android/.../call/CallContract.kt 도 같이 바꿔야 한다.
enum CallContract {
  static let eventChannel = "voip_call/events"
  static let methodChannel = "voip_call/methods"

  enum Event {
    static let voipToken = "voip_token"
    static let incoming = "call_incoming"
    static let answered = "call_answered"
    static let peerAccepted = "call_peer_accepted"
    static let ended = "call_ended"
    static let muteChanged = "mute_changed"
    static let speakerChanged = "speaker_changed"
  }

  enum PushType {
    static let start = "CALL_START"
    static let accepted = "CALL_ACCEPTED"
    static let stopRinging = "STOP_RINGING"
    static let end = "CALL_END"
  }

  enum EndReason {
    static let localHangup = "localHangup"
    static let remoteHangup = "remoteHangup"
    static let declined = "declined"
    static let cancelled = "cancelled"
    static let answeredElsewhere = "answeredElsewhere"
    static let noAnswer = "noAnswer"
    static let failed = "failed"
  }
}

/// VoIP 푸시 payload.
///
/// APNs 는 JSON 숫자를 NSNumber 로, 서버 구현에 따라 문자열로 주기도 해서 숫자 필드는 관대하게 파싱한다.
/// payload 가 `{ "aps": ..., "data": { ... } }` 형태든 평평한 형태든 받는다.
struct VoipCallPayload {
  let type: String
  let channelId: String
  let callerId: Int?
  let calleeId: Int?
  let callerName: String?
  let rtcToken: String?
  let reason: String?

  init?(pushPayload: [AnyHashable: Any]) {
    var dict: [String: Any] = [:]
    for (key, value) in pushPayload {
      if let key = key as? String { dict[key] = value }
    }
    if let nested = dict["data"] as? [String: Any] {
      dict = nested
    }
    self.init(dict: dict)
  }

  init?(dict: [String: Any]) {
    guard let type = dict["type"] as? String, !type.isEmpty,
          let channelId = dict["channelId"] as? String, !channelId.isEmpty
    else { return nil }

    self.type = type
    self.channelId = channelId
    self.callerId = Self.int(dict["callerId"])
    self.calleeId = Self.int(dict["calleeId"])
    self.callerName = dict["callerName"] as? String
    self.rtcToken = dict["rtcToken"] as? String
    self.reason = dict["reason"] as? String
  }

  var displayName: String {
    if let callerName, !callerName.isEmpty { return callerName }
    return "알 수 없는 발신자"
  }

  /// Dart 의 CallWirePayload 가 읽는 형태.
  var flutterMap: [String: Any] {
    var map: [String: Any] = ["type": type, "channelId": channelId]
    if let callerId { map["callerId"] = callerId }
    if let calleeId { map["calleeId"] = calleeId }
    if let callerName { map["callerName"] = callerName }
    if let rtcToken { map["rtcToken"] = rtcToken }
    return map
  }

  private static func int(_ value: Any?) -> Int? {
    switch value {
    case let v as Int: return v
    case let v as NSNumber: return v.intValue
    case let v as String: return Int(v)
    default: return nil
    }
  }
}
