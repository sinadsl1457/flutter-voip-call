import Flutter
import Foundation

/// Dart → iOS. 메서드 이름은 Dart NativeCallBridge 와 1:1.
enum CallMethodHandler {
  static func register(with messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: CallContract.methodChannel, binaryMessenger: messenger)
      .setMethodCallHandler(handle)
  }

  private static func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let store = NativeCredentialStore.shared
    let callKit = CallKitController.shared

    switch call.method {
    case "configure":
      store.apiBaseUrl = args["apiBaseUrl"] as? String
      store.rtcAppId = args["rtcAppId"] as? String
      store.isTestCall = args["isTestCall"] as? Bool ?? true
      result(nil)

    case "syncSession":
      // Dart 에서 null 을 보내면 NSNull → nil → Keychain 에서 삭제
      store.accessToken = args["accessToken"] as? String
      result(nil)

    case "releaseCall":
      guard let channelId = args["channelId"] as? String, !channelId.isEmpty else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "channelId is required", details: nil))
        return
      }
      callKit.releaseFromFlutter(channelId: channelId)
      result(nil)

    case "setMuted":
      callKit.setMutedFromFlutter(args["muted"] as? Bool ?? false)
      result(nil)

    case "setSpeaker":
      callKit.setSpeakerFromFlutter(args["enabled"] as? Bool ?? false)
      result(nil)

    case "getVoipToken":
      result(store.voipToken)

    case "canUseFullScreenIntent":
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
