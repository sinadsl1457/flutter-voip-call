import Flutter
import Foundation

/// 네이티브 → Dart 이벤트 스트림.
///
/// VoIP 푸시로 앱이 깨어난 경우, CallKit 에서 수락이 일어나는 시점에 Dart 쪽 listen 이
/// 아직 붙지 않았을 수 있다. 그동안의 이벤트는 버퍼에 쌓았다가 onListen 에서 순서대로 보낸다.
/// FlutterEventSink 는 메인 스레드에서만 호출한다.
final class CallEventStreamer: NSObject, FlutterStreamHandler {
  static let shared = CallEventStreamer()

  private struct Pending {
    let envelope: [String: Any]
    let createdAt: Date
  }

  private let maxPending = 32
  private let pendingTTL: TimeInterval = 60

  private var sink: FlutterEventSink?
  private var pending: [Pending] = []

  func register(with messenger: FlutterBinaryMessenger) {
    FlutterEventChannel(name: CallContract.eventChannel, binaryMessenger: messenger)
      .setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    flush()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  func emit(_ event: String, _ data: [String: Any] = [:]) {
    let envelope: [String: Any] = ["event": event, "data": data]
    onMain {
      if let sink = self.sink {
        sink(envelope)
      } else {
        if self.pending.count >= self.maxPending { self.pending.removeFirst() }
        self.pending.append(Pending(envelope: envelope, createdAt: Date()))
        CallLog.info("[CallEventStreamer] buffered \(event) (pending=\(self.pending.count))")
      }
    }
  }

  private func flush() {
    guard let sink else { return }
    let now = Date()
    let items = pending
    pending.removeAll()
    for item in items where now.timeIntervalSince(item.createdAt) <= pendingTTL {
      sink(item.envelope)
    }
  }

  private func onMain(_ block: @escaping () -> Void) {
    if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
  }
}
