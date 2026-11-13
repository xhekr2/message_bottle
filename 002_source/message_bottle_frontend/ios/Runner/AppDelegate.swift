import Flutter
import Network
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // 기기의 네트워크 연결(Wi-Fi·데이터)을 지켜본다. lib/network_guard.dart 참고.
  private let pathMonitor = NWPathMonitor()
  private var online = true

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    pathMonitor.pathUpdateHandler = { [weak self] path in
      // 지금 쓸 수 있는 네트워크가 하나라도 있으면 연결된 것으로 본다(인터넷이 없는 LAN 포함).
      self?.online = path.status == .satisfied
    }
    pathMonitor.start(queue: DispatchQueue.main)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // 앱이 기기의 네트워크 연결 여부를 묻는 통로. Android의 MainActivity.kt와 같은 이름·같은 응답이다.
    let channel = FlutterMethodChannel(
      name: "message_bottle/network",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "isOnline" {
        result(self?.online ?? true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
