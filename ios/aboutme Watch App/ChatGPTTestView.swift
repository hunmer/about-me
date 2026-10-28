//
//  ChatGPTTestView.swift
//  aboutme_watchos Watch App
//

import SwiftUI
import Combine
import AVFoundation
import WatchKit

enum ChatGPTScreen { case home, voice, chat }
enum ChatGPTOrbMode { case connecting, listening, speaking }

private enum AssistantPhase {
    case idle, preparing, recording, waiting, completed, failed
}

struct WatchAssistantMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    var text: String
}

@MainActor
final class ChatGPTTestViewModel: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var screen: ChatGPTScreen = .home
    @Published var orbMode: ChatGPTOrbMode = .connecting
    @Published var voiceStatus = "点击开始录音"
    @Published var recordedSeconds: Double = 0
    @Published var audioLevel: CGFloat = 0
    @Published var messages: [WatchAssistantMessage] = []
    @Published private var phase: AssistantPhase = .idle
    @Published private(set) var errorMessage: String?

    static let uiTransition = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.45)

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var operationTask: Task<Void, Never>?
    private var meterTask: Task<Void, Never>?
    private var requestId: String?
    private var userMessageId: UUID?
    private let sessionId: String
    private static let pendingRequestKey = "watchAssistant.pendingRequest"
    private var canQueryAgain = false
    private let cloudAnchor = Date()

    override init() {
        let pending = UserDefaults.standard.dictionary(forKey: Self.pendingRequestKey)
        sessionId = pending?["sessionId"] as? String ?? UUID().uuidString
        super.init()
        if let id = pending?["requestId"] as? String {
            requestId = id
            recordedSeconds = pending?["duration"] as? Double ?? 0
            canQueryAgain = true
            phase = .failed
            voiceStatus = "有一条语音请求尚未获取结果"
            let message = WatchAssistantMessage(isUser: true, text: "语音消息 · \(Int(recordedSeconds)) 秒")
            messages.append(message)
            userMessageId = message.id
        }
    }

    var isRecording: Bool { phase == .recording }
    var isWaiting: Bool { phase == .waiting || phase == .preparing }
    var hasError: Bool { phase == .failed }
    var canResumeRequest: Bool { canQueryAgain }
    var primaryTitle: String {
        if isRecording { return "结束并发送" }
        if isWaiting { return "等待回复" }
        return canQueryAgain ? "重新查询结果" : "开始录音"
    }
    var primaryIcon: String {
        if isRecording { return "stop.fill" }
        return canQueryAgain ? "arrow.clockwise" : "mic.fill"
    }
    var durationText: String {
        String(format: "%02d:%02d", Int(recordedSeconds) / 60, Int(recordedSeconds) % 60)
    }

    func cloudTime() -> Double {
        Date().timeIntervalSince(cloudAnchor) * (orbMode == .listening ? 1.65 : 0.8)
    }

    static func energy(mode: ChatGPTOrbMode, nowMs: Double) -> CGFloat {
        mode == .listening ? 0.4 : 0.1 + abs(sin(nowMs * 0.002)) * 0.12
    }

    func startRecording() {
        guard !isRecording, !isWaiting else { return }
        operationTask?.cancel()
        requestId = nil
        canQueryAgain = false
        errorMessage = nil
        phase = .preparing
        voiceStatus = "准备麦克风…"
        orbMode = .connecting
        screen = .voice
        operationTask = Task { [weak self] in
            guard let self else { return }
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
            }
            guard !Task.isCancelled else { return }
            guard granted else {
                fail("麦克风权限未开启，请在手表设置中允许 aboutme 使用麦克风")
                return
            }
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.record, mode: .default)
                try audioSession.setActive(true)
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("assistant-\(UUID().uuidString).m4a")
                recordingURL = url
                let audioRecorder = try AVAudioRecorder(url: url, settings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 16_000,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderBitRateKey: 32_000,
                    AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
                ])
                recorder = audioRecorder
                audioRecorder.delegate = self
                audioRecorder.isMeteringEnabled = true
                guard audioRecorder.record(forDuration: 60) else {
                    throw NSError(domain: "WatchAssistant", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "无法开始录音，请重试"])
                }
                recordedSeconds = 0
                phase = .recording
                voiceStatus = "正在聆听，点击结束发送"
                orbMode = .listening
                WKInterfaceDevice.current().play(.start)
                meterTask = Task { [weak self] in
                    while !Task.isCancelled {
                        guard let self, let recorder = self.recorder else { return }
                        recorder.updateMeters()
                        self.recordedSeconds = max(self.recordedSeconds, recorder.currentTime)
                        self.audioLevel = CGFloat(pow(10, recorder.averagePower(forChannel: 0) / 40))
                        do { try await Task.sleep(nanoseconds: 100_000_000) } catch { return }
                    }
                }
            } catch {
                discardRecording()
                fail(error.localizedDescription)
            }
        }
    }

    func primaryAction() {
        if isRecording {
            sendRecording()
        } else if canQueryAgain, let requestId {
            errorMessage = nil
            phase = .waiting
            screen = .voice
            pollResponse(requestId: requestId)
        } else {
            startRecording()
        }
    }

    private func sendRecording() {
        guard isRecording, let recorder, let url = recordingURL else { return }
        let duration = max(recordedSeconds, recorder.currentTime)
        recorder.delegate = nil
        recorder.stop()
        self.recorder = nil
        meterTask?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false)
        guard duration >= 0.5 else {
            discardRecording()
            fail("录音太短，请说完后再发送")
            return
        }
        let id = UUID().uuidString
        do {
            try WCSessionManager.shared.sendAssistantAudio(
                url: url, requestId: id, sessionId: sessionId, duration: duration)
            // 文件交给 WCSession 后保留，待传输结束回调清理。
            recordingURL = nil
            requestId = id
            UserDefaults.standard.set([
                "requestId": id, "sessionId": sessionId, "duration": duration,
            ], forKey: Self.pendingRequestKey)
            canQueryAgain = true
            recordedSeconds = duration
            let message = WatchAssistantMessage(isUser: true, text: "语音消息 · \(Int(duration)) 秒")
            messages.append(message)
            userMessageId = message.id
            phase = .waiting
            orbMode = .connecting
            WKInterfaceDevice.current().play(.stop)
            pollResponse(requestId: id)
        } catch {
            discardRecording()
            fail(error.localizedDescription)
        }
    }

    private func pollResponse(requestId: String) {
        operationTask?.cancel()
        operationTask = Task { [weak self] in
            guard let self else { return }
            let deadline = Date().addingTimeInterval(180)
            var lastConnectionError: String?
            var unknownResponseCount = 0
            while !Task.isCancelled, Date() < deadline {
                voiceStatus = WCSessionManager.shared.isReachable
                    ? "等待 iPhone 接收录音…" : "请在 iPhone 打开 aboutme"
                do {
                    let response = try await WCSessionManager.shared.getAssistantResponse(requestId: requestId)
                    try Task.checkCancellation()
                    lastConnectionError = nil
                    if response.known == false {
                        unknownResponseCount += 1
                        if unknownResponseCount >= 10 {
                            fail("iPhone 未收到这次录音，请重新录音", queryAgain: false)
                            return
                        }
                    } else {
                        unknownResponseCount = 0
                    }
                    if let transcription = response.transcription, !transcription.isEmpty,
                        let index = messages.firstIndex(where: { $0.id == self.userMessageId }) {
                        messages[index].text = transcription
                    }
                    switch response.status {
                    case "completed":
                        guard let text = response.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            fail("助手返回了空回复，请重新录音", queryAgain: false)
                            return
                        }
                        messages.append(WatchAssistantMessage(isUser: false, text: text))
                        phase = .completed
                        canQueryAgain = false
                        self.requestId = nil
                        UserDefaults.standard.removeObject(forKey: Self.pendingRequestKey)
                        orbMode = .speaking
                        voiceStatus = "回复已收到"
                        screen = .chat
                        WKInterfaceDevice.current().play(.success)
                        return
                    case "failed":
                        fail(response.error ?? "助手请求失败，请在 iPhone 检查 AI 配置", queryAgain: false)
                        return
                    case "processing":
                        voiceStatus = "助手正在处理…"
                    default:
                        voiceStatus = "等待 iPhone 处理，请打开 aboutme"
                    }
                } catch is CancellationError {
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                    lastConnectionError = error.localizedDescription
                    voiceStatus = lastConnectionError ?? "连接中断，正在重试…"
                }
                do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
            }
            guard !Task.isCancelled else { return }
            fail(lastConnectionError ?? "等待回复超时，请打开 iPhone aboutme 后重新查询结果", queryAgain: true)
        }
    }

    private func fail(_ message: String, queryAgain: Bool = false) {
        phase = .failed
        canQueryAgain = queryAgain
        if !queryAgain {
            requestId = nil
            UserDefaults.standard.removeObject(forKey: Self.pendingRequestKey)
        }
        errorMessage = message
        voiceStatus = message
        orbMode = .connecting
        screen = .voice
        WKInterfaceDevice.current().play(.failure)
    }

    private func discardRecording() {
        meterTask?.cancel()
        recorder?.delegate = nil
        recorder?.stop()
        recorder = nil
        if let recordingURL { try? FileManager.default.removeItem(at: recordingURL) }
        recordingURL = nil
        audioLevel = 0
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func backToHome() {
        if isRecording || phase == .preparing {
            operationTask?.cancel()
            discardRecording()
            phase = .idle
        }
        screen = .home
    }

    func showConversation() { screen = .chat }

    func resumeRequest() {
        if isWaiting || canQueryAgain {
            screen = .voice
            if canQueryAgain && !isWaiting { primaryAction() }
        } else {
            startRecording()
        }
    }

    func stop() {
        operationTask?.cancel()
        discardRecording()
        if isWaiting {
            phase = requestId == nil ? .idle : .failed
            canQueryAgain = requestId != nil
        } else if isRecording {
            phase = .idle
        }
    }

    func interruptRecording() {
        guard isRecording || phase == .preparing else { return }
        operationTask?.cancel()
        discardRecording()
        fail("录音已中断，请重新录音")
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            guard self.recorder === recorder, self.isRecording else { return }
            if flag {
                self.sendRecording()
            } else {
                self.discardRecording()
                self.fail("录音失败，请重试")
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            guard self.recorder === recorder else { return }
            self.discardRecording()
            self.fail(error?.localizedDescription ?? "录音编码失败，请重试")
        }
    }
}

struct ChatGPTTestView: View {
    @StateObject private var vm = ChatGPTTestViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    private let dialSize = CGSize(width: 248, height: 308)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                dialBackground(stops: [
                    (0, Color(red: 13/255, green: 33/255, blue: 71/255)),
                    (0.65, Color(red: 4/255, green: 8/255, blue: 17/255)),
                    (1, Color(red: 2/255, green: 3/255, blue: 7/255)),
                ], center: CGPoint(x: 124, y: 46))
                switch vm.screen {
                case .home: homeLayer
                case .voice: voiceLayer
                case .chat: chatLayer
                }
                AmbientGlowOverlay(active: vm.isRecording || vm.isWaiting)
            }
            .frame(width: dialSize.width, height: dialSize.height)
            .scaleEffect(x: geo.size.width / dialSize.width,
                         y: geo.size.height / dialSize.height)
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(ChatGPTTestViewModel.uiTransition, value: vm.screen)
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { vm.stop() }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            if let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
               type == AVAudioSession.InterruptionType.began.rawValue {
                vm.interruptRecording()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { vm.interruptRecording() }
        }
    }

    private var homeLayer: some View {
        VStack(spacing: 10) {
            header(title: "个人助手", back: { dismiss() })
            Button { vm.resumeRequest() } label: {
                VStack(spacing: 8) {
                    CloudOrbCanvas(vm: vm, size: 64)
                        .clipShape(Circle())
                        .shadow(color: .blue.opacity(0.5), radius: 12)
                    Text(vm.isWaiting ? "查看请求进度" : vm.canResumeRequest ? "获取上次回复" : "说说你想做什么")
                        .font(.system(size: 17, weight: .semibold))
                    Text("点击录音 · 最长 60 秒")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.06)))
            }
            .buttonStyle(ChatGPTPressStyle())
            Button { vm.showConversation() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                    Text(vm.messages.isEmpty ? "对话记录" : "查看对话 · \(vm.messages.count) 条")
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 10))
                }
                .font(.system(size: 13))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.06)))
            }
            .buttonStyle(ChatGPTPressStyle())
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 14, leading: 14, bottom: 12, trailing: 14))
    }

    private var voiceLayer: some View {
        VStack(spacing: 8) {
            header(title: "语音助手", back: { vm.backToHome() })
            Spacer(minLength: 0)
            CloudOrbCanvas(vm: vm, size: 90)
                .clipShape(Circle())
                .overlay {
                    if vm.isWaiting { ProgressView().tint(.white) }
                    if vm.hasError {
                        Image(systemName: "exclamationmark").font(.system(size: 30, weight: .bold))
                    }
                }
                .shadow(color: .blue.opacity(0.5), radius: 15)
                .scaleEffect(vm.isRecording ? 1 + vm.audioLevel * 0.07 : 1)
                .onTapGesture { if vm.isRecording { vm.primaryAction() } }
            Text(vm.isRecording ? vm.durationText : vm.hasError ? "暂时无法完成" : "正在等待回复")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .monospacedDigit()
            ScrollView {
                Text(vm.voiceStatus)
                    .font(.system(size: 12))
                    .foregroundStyle(vm.hasError ? .orange : .secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 42)
            Spacer(minLength: 0)
            Button { vm.primaryAction() } label: {
                Label(vm.primaryTitle, systemImage: vm.primaryIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(vm.isRecording ? Color.red : Color.blue))
            }
            .buttonStyle(ChatGPTPressStyle())
            .disabled(vm.isWaiting)
            .opacity(vm.isWaiting ? 0.5 : 1)
        }
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 18, trailing: 18))
    }

    private var chatLayer: some View {
        VStack(spacing: 6) {
            header(title: "个人助手", back: { vm.backToHome() })
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if vm.messages.isEmpty {
                            Text("还没有对话，点击下方麦克风开始。")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 20)
                        }
                        ForEach(vm.messages) { message in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(message.isUser ? "你" : "个人助手")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(message.isUser ? .secondary : Color.cyan)
                                Text(message.text)
                                    .font(.system(size: 14))
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 18)
                                .fill(.white.opacity(message.isUser ? 0.09 : 0.03)))
                            .id(message.id)
                        }
                        if vm.isWaiting {
                            ProgressView("等待回复…").font(.system(size: 12))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onAppear {
                    if let last = vm.messages.last { proxy.scrollTo(last.id, anchor: .top) }
                }
                .onChange(of: vm.messages.count) { _, _ in
                    if let last = vm.messages.last { proxy.scrollTo(last.id, anchor: .top) }
                }
            }
            Button { vm.resumeRequest() } label: {
                Label(vm.isWaiting ? "查看请求进度" : "继续说", systemImage: "mic.fill")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(.blue.opacity(0.8)))
            }
            .buttonStyle(ChatGPTPressStyle())
        }
        .padding(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14))
    }

    private func header(title: String, back: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.white.opacity(0.09)))
            }
            .buttonStyle(ChatGPTPressStyle())
            Text(title).font(.system(size: 14, weight: .medium))
            Spacer(minLength: 0)
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.white)
    }
}

private struct CloudOrbCanvas: View {
    @ObservedObject var vm: ChatGPTTestViewModel
    var size: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
            Canvas { ctx, canvasSize in
                let nowMs = timeline.date.timeIntervalSinceReferenceDate * 1000
                let energy = vm.isRecording ? vm.audioLevel : ChatGPTTestViewModel.energy(mode: vm.orbMode, nowMs: nowMs)
                Self.draw(&ctx, size: min(canvasSize.width, canvasSize.height), t: vm.cloudTime(), energy: energy)
            }
        }
        .frame(width: size, height: size)
    }

    private static let skyStops: [Gradient.Stop] = [
        .init(color: Color(red: 238/255, green: 247/255, blue: 255/255), location: 0),
        .init(color: Color(red: 142/255, green: 202/255, blue: 255/255), location: 0.32),
        .init(color: Color(red: 29/255, green: 116/255, blue: 245/255), location: 0.65),
        .init(color: Color(red: 8/255, green: 51/255, blue: 143/255), location: 1),
    ]

    private static let blobs: [(x: Double, y: Double, rad: Double, sx: Double, sy: Double,
                                mid: Color, base: Color)] = [
        (0.36, 0.28, 0.52, 0.9, 0.7, .init(red: 1, green: 253/255, blue: 246/255), .init(red: 1, green: 253/255, blue: 246/255)),
        (0.68, 0.38, 0.46, -0.8, 0.6, Color.white, Color.white),
        (0.25, 0.56, 0.44, 0.7, -0.9, .init(red: 240/255, green: 249/255, blue: 255/255), .init(red: 240/255, green: 249/255, blue: 1)),
        (0.55, 0.48, 0.48, -0.6, -0.7, .init(red: 1, green: 252/255, blue: 240/255), .init(red: 1, green: 252/255, blue: 240/255)),
        (0.52, 0.84, 0.55, 1.1, 0.5, .init(red: 11/255, green: 78/255, blue: 209/255), .init(red: 11/255, green: 78/255, blue: 209/255)),
        (0.75, 0.74, 0.45, -0.9, 0.8, .init(red: 26/255, green: 108/255, blue: 245/255), .init(red: 26/255, green: 108/255, blue: 245/255)),
    ]

    static func draw(_ ctx: inout GraphicsContext, size: CGFloat, t: Double, energy: CGFloat) {
        let r = size / 2
        ctx.clip(to: Path(ellipseIn: CGRect(x: 0, y: 0, width: size, height: size)))
        let full = Path(CGRect(x: 0, y: 0, width: size, height: size))
        ctx.fill(full, with: .linearGradient(Gradient(stops: skyStops),
            startPoint: .zero, endPoint: CGPoint(x: size * 0.3, y: size)))
        for (i, b) in blobs.enumerated() {
            let ox = sin(t * b.sx + Double(i) * 1.7) * Double(size * (0.08 + energy * 0.09))
            let oy = cos(t * b.sy + Double(i) * 2.1) * Double(size * (0.07 + energy * 0.08))
            let rad = Double(b.rad) * Double(size) * (1 + sin(t * 2.2 + Double(i)) * Double(energy) * 0.12)
            ctx.fill(full, with: .radialGradient(Gradient(stops: [
                .init(color: b.base.opacity(0.95), location: 0),
                .init(color: b.mid.opacity(0.45), location: 0.55),
                .init(color: .clear, location: 1),
            ]), center: CGPoint(x: b.x * Double(size) + ox, y: b.y * Double(size) + oy),
                startRadius: rad * 0.05, endRadius: rad))
        }
        ctx.fill(full, with: .radialGradient(Gradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: Color(red: 14/255, green: 58/255, blue: 138/255).opacity(0.08), location: 0.78),
            .init(color: Color(red: 200/255, green: 230/255, blue: 1).opacity(0.38), location: 1),
        ]), center: CGPoint(x: r * 0.8, y: r * 0.75), startRadius: r * 0.2, endRadius: r))
    }
}

private struct ChatGPTPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

private struct AmbientGlowOverlay: View {
    let active: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 55, style: .continuous)
            .stroke(Color(red: 43/255, green: 118/255, blue: 1).opacity(0.4), lineWidth: 10)
            .blur(radius: 7)
            .opacity(active ? 1 : 0)
            .animation(.easeInOut(duration: 0.7), value: active)
            .allowsHitTesting(false)
    }
}

private func dialBackground(stops: [(Double, Color)], center: CGPoint) -> some View {
    let corners = [CGPoint(x: 0, y: 0), CGPoint(x: 248, y: 0),
                   CGPoint(x: 0, y: 308), CGPoint(x: 248, y: 308)]
    let far = corners.map { pow($0.x - center.x, 2) + pow($0.y - center.y, 2) }.max()!.squareRoot()
    return RadialGradient(stops: stops.map { Gradient.Stop(color: $0.1, location: $0.0) },
        center: UnitPoint(x: center.x / 248, y: center.y / 308), startRadius: 0, endRadius: far)
}

#Preview {
    NavigationView {
        ChatGPTTestView()
    }
}
