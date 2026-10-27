//
//  WCSessionManager.swift
//  Aboutme
//
//  Created by Claude on 2026/3/12.
//

import Foundation
import WatchConnectivity
import Speech
import UIKit
import os.log
import Flutter

// MARK: - 数据模型

struct ChatChannel: Codable {
    let id: String
    let name: String
    let description: String?
    let unreadCount: Int
    let createdAt: String?
    let lastActiveAt: String?
}

struct ChatMessage: Codable {
    let id: String
    let channelId: String
    let content: String
    let senderId: String?
    let senderName: String?
    let timestamp: String
    let isMe: Bool?
}

// MARK: - 请求类型

enum WatchRequest: String {
    case getChatChannels
    case getChatMessages
    case getDiaryEntries
    case getDiaryEntry
    case getDiaryStats
    case getActivityToday
    case getActivityData
    case getCheckinItems
    case getContactItems
    case getHabits
    case getTimers
    case getTodoTasks
    case getDayItems
    case getTrackerGoals
    case getBillItems
    case getNotes
    case getStoreProducts
    case getUserItems
    case getNodesNotebooks
    case getNodes
    case getGoodsWarehouses
    case getGoodsItems
    case getCalendarEvents
    case getCalendarAlbumEntries
    case getAssistantResponse
}

// MARK: - WCSession Manager

class WCSessionManager: NSObject, ObservableObject {
    static let shared = WCSessionManager()
    private let logger = Logger(subsystem: "com.aboutme.ios", category: "WCSession")

    private var methodChannel: FlutterMethodChannel?

    private static let assistantStatusDefaultsKey = "watchAssistant.statuses"
    private static let assistantMaxStatusCount = 30
    private static let assistantMaxTextCharacters = 12_000
    private static let assistantMaxTextBytes = 48 * 1024
    private var assistantStatuses: [String: [String: Any]] = [:]
    private var assistantSpeechTasks: [String: SFSpeechRecognitionTask] = [:]
    private var assistantSpeechRecognizers: [String: SFSpeechRecognizer] = [:]
    private var assistantSpeechTimeouts: [String: DispatchWorkItem] = [:]
    private var assistantPendingAudio: [String: (url: URL, sessionId: String, duration: Double)] = [:]
    private var flutterReady = false
    private var assistantPreparingRequests = Set<String>()

    @Published var isConnected = false
    @Published var isReachable = false

    private override init() {
        super.init()
        loadAssistantStatuses()
        NotificationCenter.default.addObserver(self, selector: #selector(assistantAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil)
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
            logger.info("WCSession 初始化完成")
        } else {
            logger.error("WCSession 不支持")
        }
    }

    private func loadAssistantStatuses() {
        guard let stored = UserDefaults.standard.dictionary(forKey: Self.assistantStatusDefaultsKey) else {
            return
        }
        assistantStatuses = stored.reduce(into: [:]) { result, entry in
            if let status = entry.value as? [String: Any] {
                var restored = status
                if let state = status["status"] as? String, state == "pending" || state == "processing" {
                    restored["status"] = "failed"
                    restored["error"] = "iPhone 处理已中断，请重新录音；如请求包含记录操作，请先检查是否已完成"
                }
                result[entry.key] = restored
            }
        }
    }

    private func saveAssistantStatuses() {
        let sorted = assistantStatuses.sorted {
            let lhs = ($0.value["updatedAt"] as? Double) ?? 0
            let rhs = ($1.value["updatedAt"] as? Double) ?? 0
            return lhs > rhs
        }
        assistantStatuses = Dictionary(uniqueKeysWithValues: sorted.prefix(Self.assistantMaxStatusCount).map { ($0.key, $0.value) })
        UserDefaults.standard.set(assistantStatuses, forKey: Self.assistantStatusDefaultsKey)
    }

    // 设置 MethodChannel 用于与 Flutter 通信
    func setupMethodChannel(_ controller: FlutterViewController) {
        methodChannel = FlutterMethodChannel(
            name: "github.hunmer.aboutme/watch_connectivity",
            binaryMessenger: controller.binaryMessenger
        )
        methodChannel?.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(FlutterError(code: "UNAVAILABLE", message: "WatchConnectivity 不可用", details: nil))
                return
            }
            DispatchQueue.main.async {
                switch call.method {
                case "watchAssistantReady":
                    self.flutterReady = true
                    self.dispatchPendingAssistantAudio()
                    result(true)
                case "watchAssistantUpdateStatus":
                    guard let args = call.arguments as? [String: Any],
                          let requestId = args["requestId"] as? String,
                          let status = args["status"] as? String else {
                        result(FlutterError(code: "INVALID_ARGS", message: "缺少助手请求状态参数", details: nil))
                        return
                    }
                    self.updateAssistantStatus(
                        requestId: requestId,
                        status: status,
                        text: args["text"] as? String,
                        transcription: args["transcription"] as? String,
                        error: args["error"] as? String
                    )
                    result(true)
                case "updateAssistantResponse":
                    guard let args = call.arguments as? [String: Any],
                          let requestId = args["requestId"] as? String,
                          let status = args["status"] as? String else {
                        result(FlutterError(code: "INVALID_ARGS", message: "缺少助手请求状态参数", details: nil))
                        return
                    }
                    self.updateAssistantStatus(
                        requestId: requestId,
                        status: status,
                        text: args["text"] as? String,
                        transcription: args["transcription"] as? String,
                        error: args["error"] as? String
                    )
                    result(true)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        logger.info("WatchConnectivity MethodChannel 已配置")
    }
}

// MARK: - WCSessionDelegate

extension WCSessionManager: WCSessionDelegate {

    // iOS 必需方法
    func sessionDidBecomeInactive(_ session: WCSession) {
        logger.info("WCSession 已变为非活动状态")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        logger.info("WCSession 已停用")
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isConnected = (activationState == .activated)
            if let error = error {
                self.logger.error("WCSession 激活失败: \(error.localizedDescription)")
            } else {
                self.logger.info("WCSession 已激活，状态: \(activationState.rawValue)")
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            self.logger.info("Watch reachable 状态变更: \(session.isReachable)")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        logger.info("收到消息: \(message)")
    }

    // 处理来自 watchOS 的消息请求
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("===== 收到消息（带回复）: \(message) =====")

        guard let requestString = message["request"] as? String else {
            logger.error("请求中没有 request 字段")
            replyHandler([
                "success": false,
                "error": "无效的请求格式"
            ])
            return
        }

        logger.info("请求类型: \(requestString)")

        guard let requestType = WatchRequest(rawValue: requestString) else {
            logger.error("未知的请求类型: \(requestString)")
            replyHandler([
                "success": false,
                "error": "无效的请求类型: \(requestString)"
            ])
            return
        }

        logger.info("开始处理请求: \(requestString)")
        switch requestType {
        case .getChatChannels:
            handleGetChatChannels(replyHandler: replyHandler)
        case .getChatMessages:
            guard let channelId = message["channelId"] as? String else {
                replyHandler([
                    "success": false,
                    "error": "缺少 channelId 参数"
                ])
                return
            }
            handleGetChatMessages(channelId: channelId, replyHandler: replyHandler)
        case .getDiaryEntries:
            handleGetDiaryEntries(replyHandler: replyHandler)
        case .getDiaryEntry:
            guard let date = message["date"] as? String else {
                replyHandler([
                    "success": false,
                    "error": "缺少 date 参数"
                ])
                return
            }
            handleGetDiaryEntry(date: date, replyHandler: replyHandler)
        case .getDiaryStats:
            handleGetDiaryStats(replyHandler: replyHandler)
        case .getActivityToday:
            handleGetActivityToday(replyHandler: replyHandler)
        case .getActivityData:
            if let date = message["date"] as? String {
                handleGetActivityData(date: date, replyHandler: replyHandler)
            } else {
                handleGetActivityData(date: nil, replyHandler: replyHandler)
            }
        case .getCheckinItems:
            handleGetCheckinItems(replyHandler: replyHandler)
        case .getContactItems:
            handleGetContactItems(replyHandler: replyHandler)
        case .getHabits:
            handleGetHabits(replyHandler: replyHandler)
        case .getTimers:
            handleGetTimers(replyHandler: replyHandler)
        case .getTodoTasks:
            handleGetTodoTasks(replyHandler: replyHandler)
        case .getDayItems:
            handleGetDayItems(replyHandler: replyHandler)
        case .getTrackerGoals:
            handleGetTrackerGoals(replyHandler: replyHandler)
        case .getBillItems:
            handleGetBillItems(replyHandler: replyHandler)
        case .getNotes:
            handleGetNotes(replyHandler: replyHandler)
        case .getStoreProducts:
            handleGetStoreProducts(replyHandler: replyHandler)
        case .getUserItems:
            handleGetUserItems(replyHandler: replyHandler)
        case .getNodesNotebooks:
            handleGetNodesNotebooks(replyHandler: replyHandler)
        case .getNodes:
            guard let notebookId = message["notebookId"] as? String else {
                replyHandler([
                    "success": false,
                    "error": "缺少 notebookId 参数"
                ])
                return
            }
            handleGetNodes(notebookId: notebookId, replyHandler: replyHandler)
        case .getGoodsWarehouses:
            handleGetGoodsWarehouses(replyHandler: replyHandler)
        case .getGoodsItems:
            if let warehouseId = message["warehouseId"] as? String {
                handleGetGoodsItems(warehouseId: warehouseId, replyHandler: replyHandler)
            } else {
                handleGetGoodsItems(warehouseId: nil, replyHandler: replyHandler)
            }
        case .getCalendarEvents:
            handleGetCalendarEvents(replyHandler: replyHandler)
        case .getCalendarAlbumEntries:
            handleGetCalendarAlbumEntries(replyHandler: replyHandler)
        case .getAssistantResponse:
            guard let requestId = message["requestId"] as? String, !requestId.isEmpty else {
                replyHandler(["success": false, "error": "缺少 requestId 参数"])
                return
            }
            DispatchQueue.main.async {
                replyHandler(["success": true, "data": self.assistantResponse(for: requestId)])
            }
        }
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let metadata = file.metadata,
              metadata["request"] as? String == "sendAssistantAudio",
              let requestId = metadata["requestId"] as? String, !requestId.isEmpty,
              let sessionId = metadata["sessionId"] as? String, !sessionId.isEmpty else { return }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch_assistant_\(UUID().uuidString).m4a")
        do {
            let size = try file.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0, size <= 1_000_000 else {
                throw NSError(domain: "WatchAssistant", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "录音文件为空或过大"])
            }
            // 系统会在此回调返回后清理接收文件，必须同步复制。
            try FileManager.default.copyItem(at: file.fileURL, to: destination)
            let duration = (metadata["duration"] as? NSNumber)?.doubleValue ?? 0
            DispatchQueue.main.async {
                self.handleAssistantAudioFile(url: destination, requestId: requestId,
                                              sessionId: sessionId, duration: duration)
            }
        } catch {
            DispatchQueue.main.async {
                guard self.assistantStatuses[requestId] == nil else { return }
                self.updateAssistantStatus(requestId: requestId, status: "pending", text: nil, transcription: nil, error: nil)
                self.failAssistantTranscription(requestId: requestId, error: "保存录音失败：\(error.localizedDescription)")
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        logger.info("收到应用上下文更新: \(applicationContext)")
    }

    // MARK: - 请求处理方法

    private func handleGetChatChannels(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getChatChannels 请求")

        // 通过 MethodChannel 向 Flutter 请求频道列表
        methodChannel?.invokeMethod("getWatchChatChannels", arguments: nil) { result in
            // Flutter 的 result 可能是错误对象 (FlutterError)
            if let flutterError = result as? FlutterError {
                self.logger.error("获取频道列表失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            // 直接返回字典数组给 watchOS
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    private func handleGetChatMessages(channelId: String, replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getChatMessages 请求: channelId=\(channelId)")

        // 通过 MethodChannel 向 Flutter 请求消息列表
        methodChannel?.invokeMethod("getWatchChatMessages", arguments: ["channelId": channelId]) { result in
            // Flutter 的 result 可能是错误对象 (FlutterError)
            if let flutterError = result as? FlutterError {
                self.logger.error("获取消息列表失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            // 直接返回字典数组给 watchOS
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    private func handleGetDiaryEntries(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getDiaryEntries 请求")

        // 通过 MethodChannel 向 Flutter 请求日记列表
        methodChannel?.invokeMethod("getWatchDiaryEntries", arguments: nil) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取日记列表失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    private func handleGetDiaryEntry(date: String, replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getDiaryEntry 请求: date=\(date)")

        // 通过 MethodChannel 向 Flutter 请求日记详情
        methodChannel?.invokeMethod("getWatchDiaryEntry", arguments: ["date": date]) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取日记详情失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [String: Any] else {
                self.logger.error("无效的返回数据格式")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    private func handleGetDiaryStats(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getDiaryStats 请求")

        // 通过 MethodChannel 向 Flutter 请求日记统计
        methodChannel?.invokeMethod("getWatchDiaryStats", arguments: nil) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取日记统计失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [String: Any] else {
                self.logger.error("无效的返回数据格式")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    // MARK: - 活动相关处理方法

    private func handleGetActivityToday(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getActivityToday 请求")

        // 通过 MethodChannel 向 Flutter 请求今日活动统计
        methodChannel?.invokeMethod("getWatchActivityToday", arguments: nil) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取今日活动统计失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [String: Any] else {
                self.logger.error("无效的返回数据格式")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    private func handleGetActivityData(date: String?, replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getActivityData 请求: date=\(date ?? "nil")")

        var arguments: [String: Any]? = nil
        if let date = date {
            arguments = ["date": date]
        }

        // 通过 MethodChannel 向 Flutter 请求活动数据
        methodChannel?.invokeMethod("getWatchActivityData", arguments: arguments) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取活动数据失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    // MARK: - 日历事件相关处理方法

    private func handleGetCalendarEvents(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getCalendarEvents 请求")

        // 通过 MethodChannel 向 Flutter 请求日历事件数据
        methodChannel?.invokeMethod("getWatchCalendarEvents", arguments: nil) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取日历事件数据失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式: \(String(describing: result))")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            self.logger.info("成功获取日历事件数据，数据条数: \(data.count)")
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    // MARK: - 日历相册相关处理方法

    private func handleGetCalendarAlbumEntries(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getCalendarAlbumEntries 请求")

        // 通过 MethodChannel 向 Flutter 请求日历相册数据
        methodChannel?.invokeMethod("getWatchCalendarAlbumEntries", arguments: nil) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取日历相册数据失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式: \(String(describing: result))")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            self.logger.info("成功获取日历相册数据，数据条数: \(data.count)")
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    // MARK: - 公开方法（主动向 watchOS 发送数据）

    /// 发送频道列表到 watchOS
    func sendChatChannelsToWatch(_ channels: [ChatChannel]) {
        guard WCSession.default.isReachable else {
            logger.warning("Watch 不可达，无法发送数据")
            return
        }

        do {
            let jsonData = try JSONEncoder().encode(channels)
            if let jsonDicts = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                WCSession.default.transferUserInfo(["chatChannels": jsonDicts])
                logger.info("已发送频道列表到 watchOS")
            }
        } catch {
            logger.error("编码频道数据失败: \(error.localizedDescription)")
        }
    }

    /// 发送消息到 watchOS
    func sendMessagesToWatch(_ messages: [ChatMessage], channelId: String) {
        guard WCSession.default.isReachable else {
            logger.warning("Watch 不可达，无法发送数据")
            return
        }

        do {
            let jsonData = try JSONEncoder().encode(messages)
            if let jsonDicts = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                WCSession.default.transferUserInfo([
                    "chatMessages": jsonDicts,
                    "channelId": channelId
                ])
                logger.info("已发送消息到 watchOS")
            }
        } catch {
            logger.error("编码消息数据失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 打卡相关处理方法

    private func handleGetCheckinItems(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getCheckinItems 请求")

        // 通过 MethodChannel 向 Flutter 请求打卡数据
        methodChannel?.invokeMethod("getWatchCheckinItems", arguments: nil) { result in
            // Flutter 的 result 可能是错误对象 (FlutterError)
            if let flutterError = result as? FlutterError {
                self.logger.error("获取打卡数据失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式: \(String(describing: result))")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            self.logger.info("成功获取打卡数据，数据条数: \(data.count)")
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    // MARK: - 联系人相关处理方法

    private func handleGetContactItems(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getContactItems 请求")

        // 通过 MethodChannel 向 Flutter 请求联系人数据
        methodChannel?.invokeMethod("getWatchContactItems", arguments: nil) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取联系人数据失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式: \(String(describing: result))")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            self.logger.info("成功获取联系人数据，数据条数: \(data.count)")
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    // MARK: - 习惯相关处理方法

    private func handleGetHabits(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getHabits 请求")

        // 通过 MethodChannel 向 Flutter 请求习惯数据
        methodChannel?.invokeMethod("getWatchHabits", arguments: nil) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取习惯数据失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式: \(String(describing: result))")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            self.logger.info("成功获取习惯数据，数据条数: \(data.count)")
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    // MARK: - 计时器相关处理方法

    private func handleGetTimers(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getTimers 请求")

        // 通过 MethodChannel 向 Flutter 请求计时器数据
        methodChannel?.invokeMethod("getWatchTimers", arguments: nil) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取计时器数据失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式: \(String(describing: result))")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            self.logger.info("成功获取计时器数据，数据条数: \(data.count)")
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    // MARK: - 待办任务相关处理方法

    private func handleGetTodoTasks(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getTodoTasks 请求")

        // 通过 MethodChannel 向 Flutter 请求待办任务数据
        methodChannel?.invokeMethod("getWatchTodoTasks", arguments: nil) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取待办任务数据失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式: \(String(describing: result))")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            self.logger.info("成功获取待办任务数据，数据条数: \(data.count)")
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    // MARK: - 纪念日相关处理方法

    private func handleGetDayItems(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getDayItems 请求")

        // 通过 MethodChannel 向 Flutter 请求纪念日数据
        methodChannel?.invokeMethod("getWatchDayItems", arguments: nil) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取纪念日数据失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式: \(String(describing: result))")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            self.logger.info("成功获取纪念日数据，数据条数: \(data.count)")
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    // MARK: - 目标追踪相关处理方法

    private func handleGetTrackerGoals(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getTrackerGoals 请求")

        // 通过 MethodChannel 向 Flutter 请求追踪目标数据
        methodChannel?.invokeMethod("getWatchTrackerGoals", arguments: nil) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取追踪目标数据失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式: \(String(describing: result))")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            self.logger.info("成功获取追踪目标数据，数据条数: \(data.count)")
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    // MARK: - 账单相关处理方法

    private func handleGetBillItems(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getBillItems 请求")

        // 通过 MethodChannel 向 Flutter 请求账单数据
        methodChannel?.invokeMethod("getWatchBillItems", arguments: nil) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取账单数据失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式: \(String(describing: result))")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            self.logger.info("成功获取账单数据，数据条数: \(data.count)")
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    // MARK: - 笔记相关处理方法

    private func handleGetNotes(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getNotes 请求")

        // 通过 MethodChannel 向 Flutter 请求笔记数据
        methodChannel?.invokeMethod("getWatchNotes", arguments: nil) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取笔记数据失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式: \(String(describing: result))")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            self.logger.info("成功获取笔记数据，数据条数: \(data.count)")
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    // MARK: - 商店相关处理方法

    private func handleGetStoreProducts(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getStoreProducts 请求")

        // 通过 MethodChannel 向 Flutter 请求商品数据
        methodChannel?.invokeMethod("getWatchStoreProducts", arguments: nil) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取商品数据失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式: \(String(describing: result))")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            self.logger.info("成功获取商品数据，数据条数: \(data.count)")
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    private func handleGetUserItems(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getUserItems 请求")

        // 通过 MethodChannel 向 Flutter 请求用户物品数据
        methodChannel?.invokeMethod("getWatchUserItems", arguments: nil) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取用户物品数据失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式: \(String(describing: result))")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            self.logger.info("成功获取用户物品数据，数据条数: \(data.count)")
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    // MARK: - 节点笔记本相关处理方法

    private func handleGetNodesNotebooks(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getNodesNotebooks 请求")

        // 通过 MethodChannel 向 Flutter 请求节点笔记本数据
        methodChannel?.invokeMethod("getWatchNodesNotebooks", arguments: nil) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取节点笔记本数据失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式: \(String(describing: result))")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            self.logger.info("成功获取节点笔记本数据，数据条数: \(data.count)")
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    private func handleGetNodes(notebookId: String, replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getNodes 请求: notebookId=\(notebookId)")

        // 通过 MethodChannel 向 Flutter 请求节点数据
        methodChannel?.invokeMethod("getWatchNodes", arguments: ["notebookId": notebookId]) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取节点数据失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式: \(String(describing: result))")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            self.logger.info("成功获取节点数据，数据条数: \(data.count)")
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    // MARK: - 物品管理相关处理方法

    private func handleGetGoodsWarehouses(replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getGoodsWarehouses 请求")

        // 通过 MethodChannel 向 Flutter 请求仓库数据
        methodChannel?.invokeMethod("getWatchGoodsWarehouses", arguments: nil) { result in
            if let flutterError = result as? FlutterError {
                self.logger.error("获取仓库数据失败: \(flutterError.message ?? "未知错误")")
                replyHandler([
                    "success": false,
                    "error": flutterError.message ?? "未知错误"
                ])
                return
            }

            guard let data = result as? [[String: Any]] else {
                self.logger.error("无效的返回数据格式: \(String(describing: result))")
                replyHandler([
                    "success": false,
                    "error": "无效的返回数据格式"
                ])
                return
            }

            self.logger.info("成功获取仓库数据，数据条数: \(data.count)")
            replyHandler([
                "success": true,
                "data": data
            ])
        }
    }

    private func handleGetGoodsItems(warehouseId: String?, replyHandler: @escaping ([String: Any]) -> Void) {
        logger.info("处理 getGoodsItems 请求: warehouseId=\(warehouseId ?? "all")")
        var arguments: [String: Any]? = nil
        if let warehouseId = warehouseId { arguments = ["warehouseId": warehouseId] }
        methodChannel?.invokeMethod("getWatchGoodsItems", arguments: arguments) { result in
            if let flutterError = result as? FlutterError {
                replyHandler(["success": false, "error": flutterError.message ?? "未知错误"])
                return
            }
            guard let data = result as? [[String: Any]] else {
                replyHandler(["success": false, "error": "无效的返回数据格式"])
                return
            }
            replyHandler(["success": true, "data": data])
        }
    }

    // MARK: - Apple Watch 助手录音

    private func handleAssistantAudioFile(url: URL, requestId: String, sessionId: String, duration: Double) {
        guard assistantStatuses[requestId] == nil else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        assistantPendingAudio[requestId] = (url, sessionId, duration)
        updateAssistantStatus(requestId: requestId, status: "pending", text: nil, transcription: nil, error: nil)
        dispatchPendingAssistantAudio()
    }

    @objc private func assistantAppDidBecomeActive() {
        dispatchPendingAssistantAudio()
    }

    private func dispatchPendingAssistantAudio() {
        guard flutterReady, methodChannel != nil, UIApplication.shared.applicationState == .active,
              assistantPreparingRequests.isEmpty else { return }
        for requestId in Array(assistantPendingAudio.keys) {
            startAssistantTranscription(requestId: requestId)
            break
        }
    }

    private func startAssistantTranscription(requestId: String) {
        guard assistantSpeechTasks[requestId] == nil,
              !assistantPreparingRequests.contains(requestId),
              assistantPendingAudio[requestId] != nil else { return }
        assistantPreparingRequests.insert(requestId)
        updateAssistantStatus(requestId: requestId, status: "processing", text: nil, transcription: nil, error: nil)

        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            beginAssistantTranscription(requestId: requestId)
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if status == .authorized {
                        self.beginAssistantTranscription(requestId: requestId)
                    } else {
                        self.failAssistantTranscription(requestId: requestId, error: "未获得语音识别授权")
                    }
                }
            }
        case .denied:
            failAssistantTranscription(requestId: requestId, error: "语音识别权限被拒绝")
        case .restricted:
            failAssistantTranscription(requestId: requestId, error: "当前设备限制使用语音识别")
        @unknown default:
            failAssistantTranscription(requestId: requestId, error: "语音识别授权状态未知")
        }
    }

    private func beginAssistantTranscription(requestId: String) {
        guard let pending = assistantPendingAudio[requestId],
              let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")),
              recognizer.isAvailable else {
            failAssistantTranscription(requestId: requestId, error: "语音识别服务不可用")
            return
        }
        let request = SFSpeechURLRecognitionRequest(url: pending.url)
        request.shouldReportPartialResults = true
        assistantSpeechRecognizers[requestId] = recognizer
        let timeout = DispatchWorkItem { [weak self] in
            self?.failAssistantTranscription(requestId: requestId, error: "语音识别超时")
        }
        assistantSpeechTimeouts[requestId] = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 45, execute: timeout)
        assistantSpeechTasks[requestId] = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.assistantPendingAudio[requestId] != nil,
                      self.assistantSpeechTasks[requestId] != nil else { return }
                if let error {
                    self.failAssistantTranscription(requestId: requestId, error: "语音识别失败: \(error.localizedDescription)")
                } else if let result, result.isFinal {
                    let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if text.isEmpty {
                        self.failAssistantTranscription(requestId: requestId, error: "未识别到语音内容")
                    } else {
                        self.finishAssistantTranscription(requestId: requestId, transcription: text)
                    }
                }
            }
        }
    }

    private func finishAssistantTranscription(requestId: String, transcription: String) {
        guard let pending = assistantPendingAudio[requestId] else { return }
        assistantSpeechTimeouts.removeValue(forKey: requestId)?.cancel()
        assistantSpeechTasks.removeValue(forKey: requestId)?.cancel()
        assistantSpeechRecognizers.removeValue(forKey: requestId)
        updateAssistantStatus(requestId: requestId, status: "processing", text: nil, transcription: transcription, error: nil)
        methodChannel?.invokeMethod("onAssistantAudio", arguments: [
            "requestId": requestId,
            "sessionId": pending.sessionId,
            "transcription": transcription,
        ]) { [weak self] result in
            guard let self else { return }
            if let error = result as? FlutterError {
                self.failAssistantTranscription(requestId: requestId, error: error.message ?? "Flutter 未接受助手录音")
            } else if let response = result as? [String: Any], response["accepted"] as? Bool == true {
                self.cleanupAssistantAudioFile(requestId: requestId)
            } else {
                self.failAssistantTranscription(requestId: requestId, error: "iPhone 助手尚未就绪，请打开 aboutme 后重试")
            }
        }
    }

    private func failAssistantTranscription(requestId: String, error: String) {
        assistantSpeechTimeouts.removeValue(forKey: requestId)?.cancel()
        assistantSpeechTasks.removeValue(forKey: requestId)?.cancel()
        assistantSpeechRecognizers.removeValue(forKey: requestId)
        updateAssistantStatus(
            requestId: requestId,
            status: "failed",
            text: nil,
            transcription: assistantStatuses[requestId]?["transcription"] as? String,
            error: error
        )
        cleanupAssistantAudioFile(requestId: requestId)
    }

    private func cleanupAssistantAudioFile(requestId: String) {
        assistantPreparingRequests.remove(requestId)
        guard let pending = assistantPendingAudio.removeValue(forKey: requestId) else { return }
        try? FileManager.default.removeItem(at: pending.url)
        dispatchPendingAssistantAudio()
    }

    private func updateAssistantStatus(
        requestId: String,
        status: String,
        text: String?,
        transcription: String?,
        error: String?
    ) {
        guard ["pending", "processing", "completed", "failed"].contains(status) else { return }
        if assistantStatuses[requestId] == nil && status != "pending" {
            logger.warning("忽略未知助手请求状态: \(requestId)")
            return
        }
        if let current = assistantStatuses[requestId]?["status"] as? String,
           current == "completed" || current == "failed" {
            return
        }
        var actualStatus = status
        var actualText = text
        var actualError = error
        if status == "completed" {
            let candidate = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if candidate.isEmpty {
                actualStatus = "failed"
                actualError = "AI 返回为空"
                actualText = nil
            } else {
                actualText = limitAssistantText(candidate)
            }
        }
        var value = assistantStatuses[requestId] ?? [String: Any]()
        value["status"] = actualStatus
        value["updatedAt"] = Date().timeIntervalSince1970
        if let actualText { value["text"] = actualText }
        if let transcription { value["transcription"] = transcription }
        if let actualError { value["error"] = actualError }
        assistantStatuses[requestId] = value
        saveAssistantStatuses()
        if actualStatus == "completed" || actualStatus == "failed" {
            cleanupAssistantAudioFile(requestId: requestId)
        }
    }

    private func assistantResponse(for requestId: String) -> [String: Any] {
        guard let status = assistantStatuses[requestId] else { return ["status": "pending"] }
        var response: [String: Any] = ["status": status["status"] as? String ?? "pending"]
        for key in ["text", "transcription", "error"] {
            if let value = status[key] { response[key] = value }
        }
        return response
    }

    private func limitAssistantText(_ text: String) -> String {
        let suffix = "\n\n[回复过长，已截断]"
        if text.count <= Self.assistantMaxTextCharacters && text.utf8.count <= Self.assistantMaxTextBytes {
            return text
        }
        var body = String(text.prefix(Self.assistantMaxTextCharacters))
        while (body + suffix).count > Self.assistantMaxTextCharacters ||
              (body + suffix).utf8.count > Self.assistantMaxTextBytes {
            guard !body.isEmpty else { break }
            body.removeLast()
        }
        return body + suffix
    }

}
