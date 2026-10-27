import Flutter
import UIKit

public class AboutmeForegroundServicePlugin: NSObject, FlutterPlugin {
  private static let backgroundTaskChannelName =
    "aboutme_foreground_service/background_task"
  private static let beginBackgroundTaskMethod = "beginBackgroundTask"
  private static let endBackgroundTaskMethod = "endBackgroundTask"
  private static let backgroundTaskExpiredMethod = "backgroundTaskExpired"

  private let backgroundTaskChannel: FlutterMethodChannel
  private var backgroundTasks: [String: UIBackgroundTaskIdentifier] = [:]

  private init(channel: FlutterMethodChannel) {
    backgroundTaskChannel = channel
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "aboutme_foreground_service",
      binaryMessenger: registrar.messenger()
    )
    let backgroundTaskChannel = FlutterMethodChannel(
      name: backgroundTaskChannelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = AboutmeForegroundServicePlugin(channel: backgroundTaskChannel)
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addMethodCallDelegate(instance, channel: backgroundTaskChannel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case Self.beginBackgroundTaskMethod:
      guard let taskId = call.arguments as? String, !taskId.isEmpty else {
        result(FlutterError(code: "INVALID_TASK_ID", message: "taskId is required", details: nil))
        return
      }
      result(beginBackgroundTask(taskId: taskId))
    case Self.endBackgroundTaskMethod:
      guard let taskId = call.arguments as? String, !taskId.isEmpty else {
        result(FlutterError(code: "INVALID_TASK_ID", message: "taskId is required", details: nil))
        return
      }
      endBackgroundTask(taskId: taskId)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func beginBackgroundTask(taskId: String) -> Bool {
    if backgroundTasks[taskId] != nil {
      return true
    }

    let identifier = UIApplication.shared.beginBackgroundTask(withName: taskId) { [weak self] in
      guard let self = self else { return }
      self.expireBackgroundTask(taskId: taskId)
    }
    guard identifier != .invalid else {
      return false
    }
    backgroundTasks[taskId] = identifier
    return true
  }

  private func endBackgroundTask(taskId: String) {
    guard let identifier = backgroundTasks.removeValue(forKey: taskId) else {
      return
    }
    if identifier != .invalid {
      UIApplication.shared.endBackgroundTask(identifier)
    }
  }

  private func expireBackgroundTask(taskId: String) {
    // expirationHandler 在系统给出的有限时间耗尽时执行。先释放原生句柄，
    // 再通知 Dart，避免 Dart 回调延迟造成后台任务继续占用或重复续期。
    guard let identifier = backgroundTasks.removeValue(forKey: taskId) else {
      return
    }
    if identifier != .invalid {
      UIApplication.shared.endBackgroundTask(identifier)
    }
    backgroundTaskChannel.invokeMethod(Self.backgroundTaskExpiredMethod, arguments: taskId)
  }
}
