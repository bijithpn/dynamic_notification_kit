import Flutter
import UIKit
import UserNotifications

public class DynamicNotificationKitPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let manager = LiveActivityManager()
  private var sink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "dynamic_notification_kit", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(name: "dynamic_notification_kit/events", binaryMessenger: registrar.messenger())
    let instance = DynamicNotificationKitPlugin()
    instance.manager.emit = { [weak instance] e in
      DispatchQueue.main.async { instance?.sink?(e.compactMapValues { $0 }) }
    }
    registrar.addMethodCallDelegate(instance, channel: channel)
    events.setStreamHandler(instance)
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events; return nil
  }
  public func onCancel(withArguments arguments: Any?) -> FlutterError? { sink = nil; return nil }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "getCapabilities":
      UNUserNotificationCenter.current().getNotificationSettings { s in
        let ok = s.authorizationStatus == .authorized || s.authorizationStatus == .provisional
        DispatchQueue.main.async {
          result([
            "platform": "ios",
            "osVersion": UIDevice.current.systemVersion,
            "notificationsPermitted": ok,
            "supportsLiveSurface": self.manager.liveSupported,
            "supportsPromotedOngoing": false,
            "supportsDynamicIsland": self.manager.liveSupported && LiveActivityManager.hasDynamicIsland,
            "dynamicIslandIsHeuristic": true,
          ])
        }
      }
    case "openSettings":
      DispatchQueue.main.async {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url, options: [:]) { _ in result(nil) }
        } else { result(nil) }
      }
    case "diagnose":
      result(manager.diagnose())
    case "requestPermission":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
        DispatchQueue.main.async { result(ok) }
      }
    case "startDelivery", "updateDelivery":
      run(result) { try await self.manager.delivery(args, start: call.method == "startDelivery") }
    case "start", "update":
      run(result) {
        if (args["mode"] as? String) == "minimal" { try await self.manager.minimal(args) }
        else { try await self.manager.standard(args) }
      }
    case "end":
      let id = args["id"] as? String ?? ""
      Task { await self.manager.end(id: id); DispatchQueue.main.async { result(nil) } }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func run(_ result: @escaping FlutterResult, _ work: @escaping () async throws -> Void) {
    Task {
      do { try await work(); DispatchQueue.main.async { result(nil) } }
      catch let e as KitError { DispatchQueue.main.async { result(FlutterError(code: e.code, message: e.message, details: nil)) } }
      catch { DispatchQueue.main.async { result(FlutterError(code: "platform", message: "\(error)", details: nil)) } }
    }
  }
}
