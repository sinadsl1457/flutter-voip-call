import Foundation

/// 수신된 통화 payload 보관. CALL_START 때 저장하고 CXAnswerCallAction 에서 꺼내 쓴다.
/// (CallKit 액션에는 UUID 만 오므로 RTC 토큰 등은 여기서 찾아야 한다)
final class CallStore {
  static let shared = CallStore()
  private init() {}

  private let queue = DispatchQueue(label: "dev.sintaek.voipcall.callstore")
  private var calls: [String: VoipCallPayload] = [:]

  func save(_ payload: VoipCallPayload) {
    queue.sync { calls[payload.channelId] = payload }
  }

  func get(_ channelId: String) -> VoipCallPayload? {
    queue.sync { calls[channelId] }
  }

  func remove(_ channelId: String) {
    queue.sync { _ = calls.removeValue(forKey: channelId) }
  }

  func removeAll() {
    queue.sync { calls.removeAll() }
  }
}
