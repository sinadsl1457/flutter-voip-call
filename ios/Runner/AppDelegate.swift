import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // rootViewController 캐스팅 대신 registrar 의 messenger 를 쓴다.
    // (scene 기반 라이프사이클로 옮겨도 그대로 동작)
    if let registrar = registrar(forPlugin: "VoipCallChannels") {
      CallEventStreamer.shared.register(with: registrar.messenger())
      CallMethodHandler.register(with: registrar.messenger())
    }

    // CXProvider 와 PushKit 은 didFinishLaunching 안에서 동기적으로 준비해야 한다.
    // 앱이 종료된 상태에서 VoIP 푸시로 깨어나면, 이 메서드가 끝난 직후 delegate 로 푸시가 전달되기 때문.
    _ = CallKitController.shared
    VoIPPushHandler.shared.start()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
