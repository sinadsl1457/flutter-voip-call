import Foundation
import Security

/// Flutter 가 MethodChannel 로 내려준 설정/세션 + PushKit 토큰.
///
/// VoIP 푸시로 앱이 깨어나 CallKit 에서 수락/거절이 일어날 때는 Flutter 엔진이 준비되기 전일 수 있으므로,
/// 네이티브가 서버를 직접 호출할 수 있게 디스크에 보관한다.
///
/// - 액세스 토큰: Keychain, `kSecAttrAccessibleAfterFirstUnlock`
///   → 기기가 잠긴 상태에서 VoIP 푸시를 처리할 때도 읽을 수 있어야 한다. (WhenUnlocked 면 잠금화면 수락이 실패)
/// - 나머지: UserDefaults
final class NativeCredentialStore {
  static let shared = NativeCredentialStore()
  private init() {}

  private let defaults = UserDefaults.standard
  private let keychainService = (Bundle.main.bundleIdentifier ?? "voipcall") + ".session"

  private enum Key {
    static let apiBaseUrl = "voipcall.apiBaseUrl"
    static let rtcAppId = "voipcall.rtcAppId"
    static let isTestCall = "voipcall.isTestCall"
    static let voipToken = "voipcall.voipToken"
    static let accessToken = "accessToken"
  }

  var apiBaseUrl: String? {
    get { defaults.string(forKey: Key.apiBaseUrl) }
    set { defaults.set(newValue, forKey: Key.apiBaseUrl) }
  }

  var rtcAppId: String? {
    get { defaults.string(forKey: Key.rtcAppId) }
    set { defaults.set(newValue, forKey: Key.rtcAppId) }
  }

  var isTestCall: Bool {
    get { defaults.object(forKey: Key.isTestCall) as? Bool ?? true }
    set { defaults.set(newValue, forKey: Key.isTestCall) }
  }

  var voipToken: String? {
    get { defaults.string(forKey: Key.voipToken) }
    set { defaults.set(newValue, forKey: Key.voipToken) }
  }

  var accessToken: String? {
    get { readKeychain(Key.accessToken) }
    set {
      if let newValue, !newValue.isEmpty {
        writeKeychain(Key.accessToken, newValue)
      } else {
        deleteKeychain(Key.accessToken)
      }
    }
  }

  // MARK: - Keychain

  private func query(_ account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: account,
    ]
  }

  private func readKeychain(_ account: String) -> String? {
    var q = query(account)
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
          let data = item as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private func writeKeychain(_ account: String, _ value: String) {
    let attributes: [String: Any] = [
      kSecValueData as String: Data(value.utf8),
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
    ]
    let status = SecItemUpdate(query(account) as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      let add = query(account).merging(attributes) { $1 }
      let addStatus = SecItemAdd(add as CFDictionary, nil)
      if addStatus != errSecSuccess { CallLog.error("[NativeCredentialStore] keychain add failed: \(addStatus)") }
    } else if status != errSecSuccess {
      CallLog.error("[NativeCredentialStore] keychain update failed: \(status)")
    }
  }

  private func deleteKeychain(_ account: String) {
    SecItemDelete(query(account) as CFDictionary)
  }
}
