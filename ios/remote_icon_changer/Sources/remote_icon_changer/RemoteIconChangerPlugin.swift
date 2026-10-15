import Flutter
import UIKit

/// Switches the app icon with `UIApplication.setAlternateIconName`.
public class RemoteIconChangerPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "remote_icon_changer", binaryMessenger: registrar.messenger())
    let instance = RemoteIconChangerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      onMain { result(UIApplication.shared.supportsAlternateIcons) }
    case "getCurrentIcon":
      onMain { result(UIApplication.shared.alternateIconName) }
    case "setIcon":
      let args = call.arguments as? [String: Any]
      let iosName = args?["iosName"] as? String
      onMain {
        let app = UIApplication.shared
        guard app.supportsAlternateIcons else {
          result(
            FlutterError(
              code: "unsupported", message: "Alternate icons are not supported on this device",
              details: nil))
          return
        }
        if app.alternateIconName == iosName {
          result(true)
          return
        }
        app.setAlternateIconName(iosName) { error in
          DispatchQueue.main.async {
            if let error = error {
              result(
                FlutterError(
                  code: "remote_icon_changer_failed", message: error.localizedDescription,
                  details: nil))
            } else {
              result(true)
            }
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func onMain(_ block: @escaping () -> Void) {
    if Thread.isMainThread {
      block()
    } else {
      DispatchQueue.main.async(execute: block)
    }
  }
}
