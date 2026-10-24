import Foundation

enum CallApiError: Error {
  case notConfigured
  case missingAccessToken
  case invalidResponse
  case http(Int)
}

/// Flutter 없이 호출해야 하는 API (수락 / 종료·거절).
/// iOS 수신 통화는 네이티브가 미디어를 소유하므로 수락 API 도 여기서 호출한다.
final class CallApiClient {
  static let shared = CallApiClient()

  private let store = NativeCredentialStore.shared
  private let session: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 10
    return URLSession(configuration: config)
  }()

  func accept(channelId: String, acceptorToken: String) async throws {
    try await send("PATCH", "/calls/\(channelId)/accept", body: ["acceptorToken": acceptorToken])
  }

  func end(channelId: String) async throws {
    try await send("DELETE", "/calls/\(channelId)/end", body: ["isTest": store.isTestCall])
  }

  private func send(_ method: String, _ path: String, body: [String: Any]) async throws {
    guard var base = store.apiBaseUrl, !base.isEmpty else { throw CallApiError.notConfigured }
    if base.hasSuffix("/") { base.removeLast() }
    guard let url = URL(string: base + path) else { throw CallApiError.notConfigured }
    guard let token = store.accessToken else { throw CallApiError.missingAccessToken }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (_, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw CallApiError.invalidResponse }
    guard (200..<300).contains(http.statusCode) else { throw CallApiError.http(http.statusCode) }
  }
}
