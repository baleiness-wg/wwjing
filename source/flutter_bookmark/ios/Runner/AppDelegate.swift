import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "com.baleine.wwjing.bookmark/share"
  private var pendingShare: String?
  private var shareChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    pendingShare = SharedShareStore.read()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: engineBridge.binaryMessenger
    )
    shareChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getInitialShare":
        result(self?.pendingShare)
        self?.pendingShare = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    guard let text = SharedShareStore.read() else { return }
    SharedShareStore.clear()
    pendingShare = text
    shareChannel?.invokeMethod("shareReceived", arguments: text)
  }
}

private enum SharedShareStore {
  private static let appGroup = "group.com.baleine.wwjing.bookmark"
  private static let key = "pendingShareText"

  static func read() -> String? {
    UserDefaults(suiteName: appGroup)?.string(forKey: key)
  }

  static func clear() {
    UserDefaults(suiteName: appGroup)?.removeObject(forKey: key)
  }
}
