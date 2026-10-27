//
//  ChatGPTTestView.swift
//  aboutme_watchos Watch App
//
//  复刻 apple_watch_chatgpt_ui_animation.html 的 4 屏 UI 动画：
//  0. Splash（OpenAI 图标）
//  1. Home（搜索 / 时间 / 新建 + 两张 prompt 卡片）
//  2. Voice（云朵 Orb：Connecting → Listening → Speaking + EQ 均衡器）
//  3. Chat（气泡逐步显现 + 滚动 + AAPL 股票折线描线动画）
//  28.2s 后自动循环；交互按钮（新建 / Orb / 返回 / 关闭 / 迷你 Orb）全部移植。
//  设计画布 248x308（HTML 表冠屏逻辑尺寸），等比缩放铺满表盘。
//

import SwiftUI

// MARK: - SVG 采样路径数据（由 svg2swift 脚本生成，viewBox 坐标）

// OpenAI logo, viewBox 24x24
private let openAILogoPoints: [[CGFloat]] = [
    [22.3,9.8,22.4,9.4,22.5,9.0,22.6,8.6,22.6,8.2,22.6,7.7,22.6,7.3,22.5,6.9,22.4,6.5,22.3,6.1,22.1,5.7,22.0,5.3,21.8,4.9,21.4,4.4,21.0,3.9,20.6,3.4,20.1,3.0,19.5,2.7,19.0,2.4,18.4,2.2,17.8,2.0,17.2,1.9,16.5,1.9,15.9,1.9,15.3,2.0,14.5,1.3,13.6,0.7,12.6,0.3,11.6,0.1,10.5,0.0,9.5,0.1,8.5,0.4,7.5,0.9,6.7,1.6,6.0,2.3,5.4,3.2,5.0,4.2,4.6,4.3,4.2,4.4,3.8,4.6,3.4,4.8,3.0,5.0,2.7,5.2,2.3,5.5,2.0,5.7,1.7,6.1,1.5,6.4,1.2,6.7,1.0,7.1,0.7,7.6,0.5,8.2,0.3,8.9,0.2,9.5,0.2,10.1,0.2,10.8,0.3,11.4,0.5,12.0,0.7,12.6,1.0,13.2,1.3,13.7,1.7,14.2,1.6,14.6,1.5,15.0,1.5,15.4,1.4,15.8,1.4,16.3,1.5,16.7,1.5,17.1,1.6,17.5,1.7,17.9,1.9,18.3,2.0,18.7,2.2,19.1,2.6,19.6,3.0,20.1,3.4,20.6,3.9,21.0,4.5,21.3,5.0,21.6,5.6,21.8,6.2,22.0,6.9,22.1,7.5,22.1,8.1,22.1,8.8,22.0,9.0,22.3,9.4,22.6,9.7,22.8,10.0,23.1,10.4,23.3,10.8,23.5,11.2,23.6,11.6,23.8,12.0,23.9,12.4,23.9,12.8,24.0,13.3,24.0,13.9,24.0,14.5,23.9,15.1,23.7,15.7,23.5,16.3,23.2,16.8,22.8,17.3,22.4,17.8,22.0,18.2,21.5,18.5,21.0,18.8,20.4,19.0,19.8,19.4,19.7,19.8,19.6,20.2,19.4,20.6,19.2,21.0,19.0,21.3,18.8,21.7,18.5,22.0,18.2,22.3,17.9,22.6,17.6,22.8,17.3,23.0,16.9,23.3,16.3,23.5,15.7,23.7,15.1,23.8,14.5,23.8,13.9,23.8,13.2,23.7,12.6,23.5,12.0,23.3,11.4,23.0,10.8,22.7,10.3,22.3,9.8],
    [13.3,22.4,13.0,22.4,12.7,22.4,12.5,22.4,12.2,22.3,12.0,22.2,11.7,22.2,11.5,22.1,11.3,22.0,11.0,21.8,10.8,21.7,10.6,21.5,10.4,21.4,15.3,18.5,15.4,18.5,15.4,18.5,15.5,18.4,15.5,18.4,15.6,18.3,15.6,18.3,15.6,18.2,15.6,18.1,15.7,18.1,15.7,18.0,15.7,17.9,15.7,17.9,17.7,12.3,17.7,12.3,17.7,12.3,17.7,12.3,17.7,12.3,17.7,12.3,17.7,12.3,17.7,12.3,17.7,12.3,17.7,12.3,17.8,12.3,17.8,12.3,17.8,12.4,17.7,18.2,17.7,18.8,17.5,19.4,17.3,19.9,17.0,20.4,16.6,20.9,16.2,21.3,15.8,21.7,15.2,22.0,14.7,22.2,14.1,22.3,13.6,22.4,13.3,22.4],
    [3.6,18.3,3.5,18.1,3.4,17.8,3.3,17.6,3.2,17.4,3.1,17.1,3.1,16.8,3.0,16.6,3.0,16.3,3.0,16.1,3.0,15.8,3.0,15.5,3.1,15.3,8.0,18.1,8.0,18.2,8.1,18.2,8.2,18.2,8.2,18.2,8.3,18.2,8.4,18.2,8.4,18.2,8.5,18.2,8.6,18.2,8.6,18.2,8.7,18.2,8.8,18.1,14.6,17.1,14.6,17.1,14.6,17.1,14.6,17.1,14.6,17.1,14.6,17.1,14.6,17.1,14.6,17.1,14.6,17.1,14.6,17.1,14.6,17.2,14.6,17.2,14.6,17.2,9.5,20.1,8.9,20.3,8.4,20.5,7.8,20.5,7.2,20.5,6.6,20.5,6.0,20.3,5.5,20.1,5.0,19.8,4.5,19.4,4.1,19.0,3.8,18.6,3.6,18.3],
    [2.3,7.9,2.5,7.7,2.6,7.5,2.8,7.3,3.0,7.1,3.2,6.9,3.3,6.7,3.6,6.5,3.8,6.4,4.0,6.3,4.2,6.1,4.5,6.0,4.7,5.9,4.7,11.6,4.7,11.7,4.7,11.8,4.7,11.8,4.8,11.9,4.8,12.0,4.8,12.0,4.9,12.1,4.9,12.1,5.0,12.2,5.0,12.2,5.1,12.3,10.9,15.6,8.9,16.8,8.9,16.8,8.9,16.8,8.9,16.8,8.9,16.8,8.9,16.8,8.8,16.8,8.8,16.8,8.8,16.8,8.8,16.8,8.8,16.8,8.8,16.8,4.0,14.0,3.5,13.7,3.1,13.3,2.7,12.9,2.3,12.4,2.1,11.8,1.9,11.3,1.8,10.7,1.7,10.1,1.8,9.5,1.9,9.0,2.1,8.4,2.3,7.9],
    [18.9,11.8,15.1,7.2,15.1,7.2,15.1,7.2,15.1,7.2,15.1,7.2,15.1,7.2,15.2,7.2,15.2,7.2,15.2,7.2,15.2,7.2,15.2,7.2,15.2,7.2,15.2,7.2,20.4,10.2,21.0,10.8,21.5,11.4,21.9,12.2,22.2,13.0,22.3,13.8,22.2,14.7,22.0,15.5,21.6,16.3,21.1,16.9,20.5,17.5,19.7,17.9,19.3,12.4,19.3,12.4,19.3,12.3,19.3,12.2,19.3,12.2,19.3,12.1,19.2,12.0,19.2,12.0,19.1,11.9,19.1,11.9,19.0,11.8,19.0,11.8,18.9,11.8],
    [20.9,8.7,16.0,5.9,16.0,5.8,15.9,5.8,15.8,5.8,15.8,5.8,15.7,5.8,15.6,5.8,15.6,5.8,15.5,5.8,15.4,5.8,15.4,5.8,15.3,5.8,15.2,5.9,9.4,6.9,9.4,6.9,9.4,6.9,9.4,6.9,9.4,6.9,9.4,6.9,9.4,6.9,9.4,6.9,9.4,6.9,9.4,6.8,9.4,6.8,9.4,6.8,9.4,6.8,14.6,3.9,15.4,3.6,16.3,3.5,17.1,3.5,18.0,3.7,18.7,4.0,19.4,4.5,20.0,5.1,20.5,5.8,20.8,6.6,21.0,7.4,21.0,8.3,20.9,8.7],
    [8.3,12.9,6.3,11.7,6.3,11.7,6.3,11.7,6.3,11.7,6.3,11.7,6.3,11.7,6.3,11.7,6.3,11.7,6.3,11.7,6.3,11.7,6.3,11.7,6.2,11.6,6.2,6.1,6.3,5.2,6.6,4.4,7.0,3.7,7.5,3.0,8.1,2.4,8.8,2.0,9.6,1.7,10.5,1.6,11.3,1.6,12.1,1.8,12.9,2.1,13.6,2.6,8.7,5.5,8.6,5.5,8.6,5.5,8.5,5.6,8.5,5.6,8.5,5.7,8.4,5.7,8.4,5.8,8.4,5.9,8.3,5.9,8.3,6.0,8.3,6.1,8.3,6.1],
    [9.4,10.5,14.6,10.5,12.0,15.0,9.4,13.5]
]

// 宠物卡片缩略图, viewBox 40x40
private let petHairPoints: [[CGFloat]] = [
    [10.0,14.0,10.0,13.4,10.1,12.8,10.2,12.2,10.4,11.7,10.6,11.1,10.8,10.6,11.1,10.2,11.4,9.7,11.7,9.3,12.1,8.9,12.5,8.5,12.9,8.1,13.4,7.8,13.9,7.5,14.4,7.2,15.0,7.0,15.5,6.7,16.1,6.5,16.7,6.4,17.3,6.2,18.0,6.1,18.6,6.1,19.3,6.0,20.0,6.0,20.1,6.0,20.2,6.1,20.4,6.1,20.7,6.2,21.1,6.4,21.6,6.5,22.1,6.7,22.6,7.0,23.2,7.2,23.8,7.5,24.4,7.8,25.0,8.1,25.6,8.5,26.2,8.9,26.8,9.3,27.4,9.7,27.9,10.2,28.4,10.6,28.9,11.1,29.3,11.7,29.6,12.2,29.8,12.8,29.9,13.4,30.0,14.0,30.0,30.0,10.0,30.0,10.0,14.0]
]
private let petSweaterPoints: [[CGFloat]] = [
    [6.0,40.0,6.1,39.0,6.3,38.1,6.6,37.2,6.8,36.3,7.1,35.5,7.5,34.8,7.9,34.0,8.3,33.3,8.8,32.7,9.3,32.1,9.8,31.5,10.4,31.0,11.0,30.5,11.6,30.1,12.3,29.7,13.0,29.3,13.8,29.0,14.6,28.8,15.4,28.5,16.3,28.3,17.1,28.2,18.1,28.1,19.0,28.0,20.0,28.0,20.1,28.0,20.3,28.1,20.6,28.2,21.0,28.3,21.5,28.5,22.0,28.8,22.7,29.0,23.4,29.3,24.2,29.7,25.0,30.1,25.8,30.5,26.6,31.0,27.5,31.5,28.3,32.1,29.1,32.7,29.9,33.3,30.7,34.0,31.4,34.8,32.0,35.5,32.6,36.3,33.1,37.2,33.5,38.1,33.8,39.0,34.0,40.0,6.0,40.0]
]
private let petCatPoints: [[CGFloat]] = [
    [12.0,27.0,12.0,26.6,12.1,26.1,12.1,25.7,12.2,25.3,12.4,25.0,12.5,24.6,12.7,24.2,12.9,23.9,13.2,23.6,13.4,23.3,13.7,23.0,14.0,22.7,14.3,22.4,14.7,22.2,15.0,22.0,15.4,21.8,15.8,21.6,16.2,21.4,16.6,21.3,17.1,21.2,17.6,21.1,18.0,21.1,18.5,21.0,19.0,21.0,19.0,21.0,19.1,21.1,19.3,21.1,19.5,21.2,19.8,21.3,20.1,21.4,20.4,21.6,20.8,21.8,21.2,22.0,21.6,22.2,22.1,22.4,22.5,22.7,22.9,23.0,23.4,23.3,23.8,23.6,24.2,23.9,24.6,24.2,24.9,24.6,25.2,25.0,25.5,25.3,25.7,25.7,25.9,26.1,26.0,26.6,26.0,27.0,26.0,40.0,12.0,40.0,12.0,27.0]
]

/// 扁平点集 [x0,y0,x1,y1,...] → 封闭 Path
private func pathFromPoints(_ data: [[CGFloat]]) -> Path {
    var p = Path()
    for sub in data {
        guard sub.count >= 4 else { continue }
        p.move(to: CGPoint(x: sub[0], y: sub[1]))
        var i = 2
        while i + 1 < sub.count {
            p.addLine(to: CGPoint(x: sub[i], y: sub[i + 1]))
            i += 2
        }
        p.closeSubpath()
    }
    return p
}

// MARK: - 状态与时间轴

enum ChatGPTScreen { case splash, home, voice, chat }
enum ChatGPTOrbMode { case connecting, listening, speaking }
enum ChatGPTExitStyle { case up, left }

@MainActor
final class ChatGPTTestViewModel: ObservableObject {
    @Published var screen: ChatGPTScreen = .splash
    @Published var exitingScreen: ChatGPTScreen?
    @Published var exitStyle: ChatGPTExitStyle = .up
    @Published var ambientGlow = false
    @Published var composeGlow = false
    @Published var orbMode: ChatGPTOrbMode = .connecting
    @Published var orbExpanded = false
    @Published var voiceStatus = "Connecting..."
    @Published var listeningVisible = false
    @Published var chatUserShown = false
    @Published var chatAiShown = false
    @Published var chatStockShown = false
    @Published var chatScroll: CGFloat = 0

    /// HTML view-layer 过渡: 0.52s cubic-bezier(0.22, 1, 0.36, 1)
    static let uiTransition = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.52)

    private var task: Task<Void, Never>?
    private var clearExitTask: Task<Void, Never>?
    // 云层动画时间: 按模式速度累计（speaking 2.4 / listening 1.65 / 其它 0.8）
    private var cloudAccum: Double = 0
    private var cloudAnchor = Date()
    private var cloudSpeed: Double = 0.8

    // MARK: 云时间 / 能量 / 呼吸（与 renderLoop 公式一致, nowMs 为毫秒）

    func cloudTime() -> Double {
        cloudAccum + Date().timeIntervalSince(cloudAnchor) * cloudSpeed
    }

    static func energy(mode: ChatGPTOrbMode, nowMs: Double) -> CGFloat {
        switch mode {
        case .listening: return 0.22 + abs(sin(nowMs * 0.007) * cos(nowMs * 0.011)) * 0.55
        case .speaking: return 0.35 + abs(sin(nowMs * 0.0085) * sin(nowMs * 0.0042)) * 0.75
        case .connecting: return 0.1
        }
    }

    static func breathScale(mode: ChatGPTOrbMode, nowMs: Double) -> CGFloat {
        switch mode {
        case .listening: return 1 + abs(sin(nowMs * 0.007) * cos(nowMs * 0.011)) * 0.035
        case .speaking: return 1 + abs(sin(nowMs * 0.0085) * sin(nowMs * 0.0042)) * 0.055
        // 相对系数: HTML 为 0.24 + sin*0.018 = 0.24 * (1 + sin*0.075)
        case .connecting: return 1 + sin(nowMs * 0.005) * 0.075
        }
    }

    private func setMode(_ m: ChatGPTOrbMode) {
        let now = Date()
        cloudAccum += now.timeIntervalSince(cloudAnchor) * cloudSpeed
        cloudAnchor = now
        cloudSpeed = m == .speaking ? 2.4 : m == .listening ? 1.65 : 0.8
        orbMode = m
    }

    // MARK: 屏切换（含退出层过渡）

    func showScreen(_ new: ChatGPTScreen, exit: ChatGPTExitStyle?) {
        let old = screen
        screen = new
        if let exit, old != new {
            exitingScreen = old
            exitStyle = exit
            clearExitTask?.cancel()
            let prev = old
            clearExitTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 600_000_000)
                if let self, self.exitingScreen == prev { self.exitingScreen = nil }
            }
        } else {
            exitingScreen = nil
        }
    }

    /// 每层的 (透明度, 缩放, Y偏移)，对应 CSS 的 view-layer transform 规则
    func visuals(for s: ChatGPTScreen) -> (opacity: Double, scale: CGFloat, y: CGFloat) {
        let active = screen == s
        let exiting = exitingScreen == s
        switch s {
        case .splash:
            if exiting, exitStyle == .up { return (0, 0.86, -16) }
            return (active ? 1 : 0, 1.04, 0)
        case .home:
            if exiting, exitStyle == .left { return (0, 0.92, 0) }
            return (active ? 1 : 0, active ? 1 : 0.94, active ? 0 : 12)
        case .voice:
            return (active ? 1 : 0, active ? 1 : 0.95, 0)
        case .chat:
            return (active ? 1 : 0, active ? 1 : 0.96, 0)
        }
    }

    // MARK: 28.2s 编舞时间轴（HTML runFullSequence）

    func runSequence() {
        task?.cancel()
        task = Task { await playTimeline() }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func sleep(_ ms: UInt64) async throws {
        try await Task.sleep(nanoseconds: ms * 1_000_000)
    }

    private func playTimeline() async {
        // 00:00 - Splash 起始态
        ambientGlow = false
        composeGlow = false
        setMode(.connecting)
        orbExpanded = false
        voiceStatus = "Connecting..."
        listeningVisible = false
        chatReset()
        exitingScreen = nil
        screen = .splash
        do {
            // 00:01.35 - Splash 上浮退出 → Home
            try await sleep(1350)
            showScreen(.home, exit: .up)
            // 00:02.75 - 右上角新建按钮 tap 高亮
            try await sleep(1400)
            composeGlow = true
            // 00:03.45 - 进入语音模式（Connecting），屏幕边缘蓝光亮起
            try await sleep(700)
            composeGlow = false
            showScreen(.voice, exit: .left)
            ambientGlow = true
            // 00:05.3 - Orb 弹性展开为云球（Listening）
            try await sleep(1850)
            setMode(.listening)
            orbExpanded = true
            voiceStatus = "Listening..."
            listeningVisible = true
            // 00:11.3 - AI 回应（Tap to interrupt）
            try await sleep(6000)
            setMode(.speaking)
            listeningVisible = false
            voiceStatus = "Tap to interrupt"
            // 00:21.2 - 聊天记录页: 用户气泡
            try await sleep(9900)
            showScreen(.chat, exit: nil)
            chatScroll = 0
            try await sleep(120)
            chatUserShown = true
            // 00:22.6 - 上滚 + 分析师目标价文本
            try await sleep(1280)
            chatScroll = -44
            chatAiShown = true
            // 00:24.2 - 继续上滚 + AAPL 折线描线
            try await sleep(1600)
            chatScroll = -156
            chatStockShown = true
            // 00:28.2 - 循环
            try await sleep(4000)
            runSequence()
        } catch {}
    }

    private func chatReset() {
        chatScroll = 0
        chatUserShown = false
        chatAiShown = false
        chatStockShown = false
    }

    // MARK: 交互（HTML 直接交互控制）

    func tapCompose() {
        task?.cancel()
        composeGlow = true
        task = Task {
            try? await sleep(260)
            composeGlow = false
            showScreen(.voice, exit: .left)
            ambientGlow = true
            setMode(.connecting)
            orbExpanded = false
            voiceStatus = "Connecting..."
            listeningVisible = false
            try? await sleep(1400)
            setMode(.listening)
            orbExpanded = true
            voiceStatus = "Listening..."
            listeningVisible = true
            try? await sleep(4800)
            setMode(.speaking)
            listeningVisible = false
            voiceStatus = "Tap to interrupt"
        }
    }

    func tapOrb() {
        task?.cancel()
        if orbMode == .speaking {
            chatReset()
            showScreen(.chat, exit: nil)
            task = Task {
                try? await sleep(120)
                chatUserShown = true
                try? await sleep(780)
                chatScroll = -44
                chatAiShown = true
                try? await sleep(1200)
                chatScroll = -156
                chatStockShown = true
            }
        } else {
            setMode(.speaking)
            orbExpanded = true
            listeningVisible = false
            voiceStatus = "Tap to interrupt"
        }
    }

    /// 返回按钮（voice 返回 / 关闭、chat 返回）: 动画回到 Home，5s 后恢复完整循环
    func backToHome() {
        task?.cancel()
        ambientGlow = false
        showScreen(.home, exit: nil)
        task = Task {
            try? await sleep(5000)
            if screen == .home { runSequence() }
        }
    }

    func tapMiniOrb() {
        task?.cancel()
        setMode(.listening)
        orbExpanded = true
        voiceStatus = "Listening..."
        listeningVisible = true
        showScreen(.voice, exit: nil)
    }
}

// MARK: - 云朵 Orb 渲染（复刻 drawCloudOrb: 天空渐变 + 6 团体积云 + 球面高光）

private struct CloudOrbCanvas: View {
    @ObservedObject var vm: ChatGPTTestViewModel
    var timeScale: Double = 1
    var fixedEnergy: CGFloat? = nil
    var size: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, canvasSize in
                let nowMs = timeline.date.timeIntervalSinceReferenceDate * 1000
                let energy = fixedEnergy ?? ChatGPTTestViewModel.energy(mode: vm.orbMode, nowMs: nowMs)
                Self.draw(&ctx, size: min(canvasSize.width, canvasSize.height),
                          t: vm.cloudTime() * timeScale, energy: energy)
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

        // 深空天空底渐变
        ctx.fill(full, with: .linearGradient(
            Gradient(stops: skyStops),
            startPoint: .zero,
            endPoint: CGPoint(x: size * 0.3, y: size)))

        // 6 团漂浮体积云
        for (i, b) in blobs.enumerated() {
            let ox = sin(t * b.sx + Double(i) * 1.7) * Double(size * (0.08 + energy * 0.09))
            let oy = cos(t * b.sy + Double(i) * 2.1) * Double(size * (0.07 + energy * 0.08))
            let cx = b.x * Double(size) + ox
            let cy = b.y * Double(size) + oy
            let rad = Double(b.rad) * Double(size) * (1 + sin(t * 2.2 + Double(i)) * Double(energy) * 0.12)
            ctx.fill(full, with: .radialGradient(
                Gradient(stops: [
                    .init(color: b.base.opacity(0.95), location: 0),
                    .init(color: b.mid.opacity(0.45), location: 0.55),
                    .init(color: .clear, location: 1),
                ]),
                center: CGPoint(x: cx, y: cy),
                startRadius: rad * 0.05,
                endRadius: rad))
        }

        // 球面内缘阴影 + 高光
        ctx.fill(full, with: .radialGradient(
            Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: Color(red: 14/255, green: 58/255, blue: 138/255).opacity(0.08), location: 0.78),
                .init(color: Color(red: 200/255, green: 230/255, blue: 1).opacity(0.38), location: 1),
            ]),
            center: CGPoint(x: r * 0.8, y: r * 0.75),
            startRadius: r * 0.2,
            endRadius: r))
    }
}

// MARK: - 主视图

struct ChatGPTTestView: View {
    @StateObject private var vm = ChatGPTTestViewModel()

    private let dialSize = CGSize(width: 248, height: 308)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                screenLayer(.splash) { SplashLayer(vm: vm) }
                screenLayer(.home) { HomeLayer(vm: vm) }
                screenLayer(.voice) { VoiceLayer(vm: vm) }
                screenLayer(.chat) { ChatLayer(vm: vm) }
                AmbientGlowOverlay(active: vm.ambientGlow)
                GlassReflectionOverlay()
            }
            .scaleEffect(x: geo.size.width / dialSize.width,
                         y: geo.size.height / dialSize.height,
                         anchor: .center)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { vm.runSequence() }
        .onDisappear { vm.stop() }
    }

    private func screenLayer<Content: View>(_ s: ChatGPTScreen,
                                            @ViewBuilder content: () -> Content) -> some View {
        let v = vm.visuals(for: s)
        return content()
            .scaleEffect(v.scale)
            .offset(y: v.y)
            .opacity(v.opacity)
            .animation(ChatGPTTestViewModel.uiTransition, value: vm.screen)
            .animation(ChatGPTTestViewModel.uiTransition, value: vm.exitingScreen)
            .allowsHitTesting(vm.screen == s)
    }
}

// MARK: - 屏 0: Splash

private struct SplashLayer: View {
    @ObservedObject var vm: ChatGPTTestViewModel

    var body: some View {
        ZStack {
            dialBackground(stops: [
                (0.0, Color(red: 10/255, green: 25/255, blue: 54/255)),
                (0.75, Color(red: 2/255, green: 4/255, blue: 8/255)),
            ], center: CGPoint(x: 124, y: 92))
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 38/255, green: 43/255, blue: 54/255).opacity(0.85))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
                    Canvas { ctx, _ in
                        ctx.fill(pathFromPoints(openAILogoPoints)
                            .applying(CGAffineTransform(scaleX: 32.0 / 24, y: 32.0 / 24)),
                                 with: .color(Color.white.opacity(0.85)))
                    }
                    .frame(width: 32, height: 32)
                }
                .frame(width: 58, height: 58)
                Text("ChatGPT")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
            VStack(spacing: 0) {
                Text("10:09")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.35))
                    .padding(.top, 13)
                Spacer()
            }
        }
    }
}

// MARK: - 屏 1: Home

private struct HomeLayer: View {
    @ObservedObject var vm: ChatGPTTestViewModel

    var body: some View {
        dialBackground(stops: [
            (0.0, Color(red: 13/255, green: 33/255, blue: 71/255)),
            (0.55, Color(red: 4/255, green: 7/255, blue: 15/255)),
            (1.0, Color(red: 2/255, green: 3/255, blue: 6/255)),
        ], center: CGPoint(x: 124, y: 0))
        .overlay(
            VStack(spacing: 0) {
                homeHeader
                promptCard(
                    thumb: PetThumbView(),
                    title: "Create a cartoon\nof my pet",
                    subtitle: "Illustration of my pet hanging around outside",
                    subtitleOpacity: 1)
                promptCard(
                    thumb: ScreenThumbView(),
                    title: "What can\nChatGPT do",
                    subtitle: "Illustration of my pet hanging",
                    subtitleOpacity: 0.6)
                Spacer(minLength: 0)
            }
            .padding(EdgeInsets(top: 14, leading: 12, bottom: 10, trailing: 12))
        )
    }

    private var homeHeader: some View {
        HStack(spacing: 0) {
            GlassCircleButton(size: 38) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
            }
            Spacer()
            VStack(spacing: 0) {
                Text("10:09").font(.system(size: 14.5, weight: .medium)).foregroundColor(.white)
                Text("ChatGPT").font(.system(size: 14.5, weight: .medium))
                    .foregroundColor(Color(red: 77/255, green: 163/255, blue: 1))
            }
            Spacer()
            composeButton
        }
        .padding(.bottom, 10)
    }

    private var composeButton: some View {
        let glow = vm.composeGlow
        return Button {
            vm.tapCompose()
        } label: {
            ZStack {
                Circle()
                    .fill(glow ? Color.white : Color(red: 34/255, green: 42/255, blue: 56/255).opacity(0.82))
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(glow ? Color(red: 9/255, green: 13/255, blue: 22/255) : .white)
                if glow {
                    Circle()
                        .stroke(Color(red: 59/255, green: 130/255, blue: 246/255).opacity(0.45), lineWidth: 5)
                        .shadow(color: Color(red: 59/255, green: 130/255, blue: 246/255).opacity(0.9),
                                radius: 11)
                }
            }
            .frame(width: 38, height: 38)
            .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
            .scaleEffect(glow ? 0.93 : 1)
        }
        .buttonStyle(ChatGPTPressStyle())
        .animation(.easeOut(duration: 0.2), value: glow)
    }

    private func promptCard<Thumb: View>(thumb: Thumb, title: String, subtitle: String, subtitleOpacity: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                thumb
                Text(title)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundColor(.white)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            Text(subtitle)
                .font(.system(size: 12.5))
                .foregroundColor(Color(red: 139/255, green: 149/255, blue: 167/255)
                    .opacity(subtitleOpacity))
                .lineSpacing(1)
        }
        .padding(EdgeInsets(top: 11, leading: 12, bottom: 11, trailing: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 23/255, green: 28/255, blue: 38/255).opacity(0.9))
                .shadow(color: .black.opacity(0.35), radius: 7, y: 2)
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.white.opacity(0.06), lineWidth: 1))
        .padding(.bottom, 9)
    }
}

// MARK: - 屏 2: Voice（云朵 Orb）

private struct VoiceLayer: View {
    @ObservedObject var vm: ChatGPTTestViewModel

    var body: some View {
        dialBackground(stops: [
            (0.0, Color(red: 9/255, green: 25/255, blue: 54/255)),
            (0.68, Color(red: 3/255, green: 6/255, blue: 14/255)),
            (1.0, Color(red: 1/255, green: 2/255, blue: 4/255)),
        ], center: CGPoint(x: 124, y: 129))
        .overlay(
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    GlassCircleButton(size: 38) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                    } action: { vm.backToHome() }
                    Spacer()
                    Text("10:09")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.trailing, 1)
                }
                Spacer(minLength: 0)
                VoiceOrbView(vm: vm)
                ZStack {
                    Text(vm.voiceStatus)
                        .id(vm.voiceStatus)
                        .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.3), value: vm.voiceStatus)
                .padding(.top, 12)
                Spacer(minLength: 0)
                voiceBottomBar
            }
            .padding(EdgeInsets(top: 16, leading: 16, bottom: 18, trailing: 16))
        )
    }

    private var voiceBottomBar: some View {
        HStack(spacing: 0) {
            // 暂停（双空心条）
            Button {} label: {
                ZStack {
                    Circle()
                        .fill(Color(red: 37/255, green: 43/255, blue: 56/255))
                        .overlay(Circle().stroke(Color.white.opacity(0.05), lineWidth: 1))
                    HStack(spacing: 3.5) {
                        Capsule().stroke(Color.white.opacity(0.9), lineWidth: 1.6)
                            .frame(width: 4.5, height: 13)
                        Capsule().stroke(Color.white.opacity(0.9), lineWidth: 1.6)
                            .frame(width: 4.5, height: 13)
                    }
                }
                .frame(width: 40, height: 40)
            }
            .buttonStyle(ChatGPTPressStyle())
            Spacer()
            ListeningIndicator(vm: vm)
            Spacer()
            // 结束（红叉）
            Button {
                vm.backToHome()
            } label: {
                ZStack {
                    Circle().fill(Color(red: 220/255, green: 56/255, blue: 56/255))
                        .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 40, height: 40)
            }
            .buttonStyle(ChatGPTPressStyle())
        }
    }
}

/// 主云球：弹性展开 + 按模式呼吸 + Connecting 白点遮罩
private struct VoiceOrbView: View {
    @ObservedObject var vm: ChatGPTTestViewModel

    var body: some View {
        TimelineView(.animation) { timeline in
            let nowMs = timeline.date.timeIntervalSinceReferenceDate * 1000
            CloudOrbCanvas(vm: vm, size: 116)
                .clipShape(Circle())
                .overlay(
                    // Connecting 阶段整球覆白（对应 whiteFade）
                    Circle().fill(Color.white)
                        .opacity(vm.orbMode == .connecting ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5), value: vm.orbMode)
                )
                .scaleEffect(ChatGPTTestViewModel.breathScale(mode: vm.orbMode, nowMs: nowMs))
        }
        .scaleEffect(vm.orbExpanded ? 1 : 0.24)
        .animation(.timingCurve(0.34, 1.45, 0.64, 1, duration: 0.72), value: vm.orbExpanded)
        .shadow(color: vm.orbExpanded
                ? Color(red: 45/255, green: 130/255, blue: 1).opacity(0.42)
                : Color.white.opacity(0.35),
                radius: vm.orbExpanded ? 16 : 10)
        .animation(.easeInOut(duration: 0.6), value: vm.orbExpanded)
        .frame(width: 116, height: 116)
        .contentShape(Circle())
        .onTapGesture { vm.tapOrb() }
    }
}

/// 麦克风 + 4 根逐帧跳动的均衡器药丸
private struct ListeningIndicator: View {
    @ObservedObject var vm: ChatGPTTestViewModel

    var body: some View {
        TimelineView(.animation) { timeline in
            let nowMs = timeline.date.timeIntervalSinceReferenceDate * 1000
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 6.5,
                               height: 6 + abs(sin(nowMs * 0.009 + Double(i) * 1.1)) * 10)
                }
            }
        }
        .opacity(vm.listeningVisible ? 1 : 0)
        .scaleEffect(vm.listeningVisible ? 1 : 0.9)
        .offset(y: vm.listeningVisible ? 0 : 4)
        .animation(.easeOut(duration: 0.35), value: vm.listeningVisible)
    }
}

// MARK: - 屏 3: Chat（气泡 + 滚动 + 股票折线）

private struct ChatLayer: View {
    @ObservedObject var vm: ChatGPTTestViewModel

    var body: some View {
        dialBackground(stops: [
            (0.0, Color(red: 12/255, green: 31/255, blue: 68/255)),
            (0.65, Color(red: 4/255, green: 8/255, blue: 17/255)),
            (1.0, Color(red: 2/255, green: 3/255, blue: 7/255)),
        ], center: CGPoint(x: 124, y: 46))
        .overlay(
            ZStack(alignment: .top) {
                chatTrack
                chatTopMask
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    chatBottomBar
                }
            }
        )
    }

    // MARK: 滚动轨道

    private var chatTrack: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 用户气泡
            Text("Hey ChatGPT, is\nApple stock\nexpected to go up?")
                .font(.system(size: 14.5))
                .foregroundColor(Color(red: 243/255, green: 246/255, blue: 1))
                .lineSpacing(3)
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 31/255, green: 38/255, blue: 51/255).opacity(0.88))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
                )
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1))
                .opacity(vm.chatUserShown ? 1 : 0)
                .offset(y: vm.chatUserShown ? 0 : 14)
                .animation(.easeOut(duration: 0.45), value: vm.chatUserShown)

            // AI 文本
            chatAiText
                .foregroundColor(Color(red: 226/255, green: 232/255, blue: 240/255))
                .padding(.horizontal, 2)
                .opacity(vm.chatAiShown ? 1 : 0)
                .offset(y: vm.chatAiShown ? 0 : 16)
                .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.5), value: vm.chatAiShown)

            StockCardView(shown: vm.chatStockShown)
                .opacity(vm.chatStockShown ? 1 : 0)
                .offset(y: vm.chatStockShown ? 0 : 18)
                .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.55), value: vm.chatStockShown)
        }
        .padding(EdgeInsets(top: 62, leading: 14, bottom: 86, trailing: 14))
        .offset(y: vm.chatScroll)
        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.85), value: vm.chatScroll)
    }

    private var chatAiText: Text {
        let bold = Font.system(size: 14.5, weight: .semibold)
        return Text("The 32 analysts' 12-month price targets for Apple average ")
            + Text("$239.78").font(bold).foregroundColor(.white)
            + Text(", ranging from ")
            + Text("$180").font(bold).foregroundColor(.white)
            + Text(" to ")
            + Text("$300").font(bold).foregroundColor(.white)
            + Text(".")
    }

    // MARK: 顶部渐变遮罩

    private var chatTopMask: some View {
        HStack(spacing: 0) {
            GlassCircleButton(size: 38) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
            } action: { vm.backToHome() }
            Spacer()
            Text("10:09")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .padding(.top, 6)
                .padding(.trailing, 1)
        }
        .padding(EdgeInsets(top: 15, leading: 16, bottom: 0, trailing: 16))
        .frame(height: 58, alignment: .top)
        .background(
            LinearGradient(stops: [
                .init(color: Color(red: 3/255, green: 7/255, blue: 16/255).opacity(0.92), location: 0),
                .init(color: Color(red: 3/255, green: 7/255, blue: 16/255).opacity(0.45), location: 0.72),
                .init(color: .clear, location: 1),
            ], startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: 底部操作栏

    private var chatBottomBar: some View {
        HStack(spacing: 0) {
            GlassCircleButton(size: 38) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 15))
            }
            Spacer()
            MiniOrbView(vm: vm)
                .onTapGesture { vm.tapMiniOrb() }
            Spacer()
            GlassCircleButton(size: 38) {
                Image(systemName: "keyboard")
                    .font(.system(size: 16))
            }
        }
        .padding(EdgeInsets(top: 0, leading: 18, bottom: 12, trailing: 18))
        .frame(height: 74)
        .background(
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: Color(red: 2/255, green: 5/255, blue: 12/255).opacity(0.65), location: 0.28),
                .init(color: Color(red: 2/255, green: 5/255, blue: 12/255).opacity(0.96), location: 0.65),
            ], startPoint: .top, endPoint: .bottom)
        )
    }
}

// MARK: - AAPL 股票卡（描线动画）

private struct StockCardView: View {
    let shown: Bool

    /// 折线关键点（HTML SVG 220x60 viewBox）
    static let linePoints: [(CGFloat, CGFloat)] = [
        (2, 47), (16, 44), (28, 49), (42, 46), (56, 50), (70, 43), (84, 46), (98, 48),
        (112, 31), (125, 34), (138, 24), (152, 33), (166, 15), (180, 24), (194, 12), (207, 20), (218, 8),
    ]

    var body: some View {
        let green = Color(red: 34/255, green: 197/255, blue: 94/255)
        return VStack(alignment: .leading, spacing: 0) {
            Text("AAPL")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(green)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("254.49").font(.system(size: 12.5, weight: .medium)).foregroundColor(.white)
                Text("+5%").font(.system(size: 11, weight: .semibold)).foregroundColor(green)
            }
            .padding(.top, 2)
            ZStack {
                // 4 列网格
                Canvas { ctx, size in
                    var p = Path()
                    for i in 1...3 {
                        let x = size.width * CGFloat(i) / 4
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    ctx.stroke(p, with: .color(.white.opacity(0.07)), lineWidth: 1)
                }
                // 面积
                areaShape
                    .fill(LinearGradient(stops: [
                        .init(color: green.opacity(0.38), location: 0),
                        .init(color: green.opacity(0), location: 1),
                    ], startPoint: .top, endPoint: .bottom))
                // 白色折线（stroke-dashoffset 描线）
                StockLineShape(progress: shown ? 1 : 0)
                    .stroke(Color.white,
                            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 1.2), value: shown)
            }
            .frame(width: 198, height: 54)
            .padding(.vertical, 2)
            HStack(spacing: 0) {
                ForEach(["2023", "2024", "2025", "2025"].indices, id: \.self) { i in
                    Text(["2023", "2024", "2025", "2025"][i])
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(EdgeInsets(top: 10, leading: 11, bottom: 8, trailing: 11))
        .background(
            ZStack {
                LinearGradient(stops: [
                    .init(color: Color(red: 11/255, green: 60/255, blue: 36/255), location: 0),
                    .init(color: Color(red: 7/255, green: 41/255, blue: 24/255), location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(green.opacity(0.22), lineWidth: 1))
    }

    private var areaShape: some Shape {
        Path { p in
            let pts = Self.linePoints
            p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
            for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
            p.addLine(to: CGPoint(x: 218, y: 60))
            p.addLine(to: CGPoint(x: 2, y: 60))
            p.closeSubpath()
        }
        .scaledToFit()
    }
}

/// 220x60 坐标折线, progress ∈ [0,1] 从左往右描线
private struct StockLineShape: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let pts = StockCardView.linePoints
        p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
        for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
        let s = rect.width / 220
        return p.trimmedPath(from: 0, to: max(0.001, progress))
            .applying(CGAffineTransform(scaleX: s, y: s))
    }
}

// MARK: - 底栏迷你云球

private struct MiniOrbView: View {
    @ObservedObject var vm: ChatGPTTestViewModel

    private let barHeights: [CGFloat] = [7, 15, 19, 11, 6]

    var body: some View {
        CloudOrbCanvas(vm: vm, timeScale: 0.8, fixedEnergy: 0.25, size: 50)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1).blur(radius: 1.5))
            .shadow(color: Color(red: 45/255, green: 125/255, blue: 1).opacity(0.45), radius: 8, y: 2)
            .overlay(
                HStack(alignment: .center, spacing: 2.5) {
                    ForEach(barHeights, id: \.self) { h in
                        Capsule()
                            .fill(Color(red: 7/255, green: 17/255, blue: 36/255))
                            .frame(width: 2.4, height: h)
                    }
                }
            )
            .frame(width: 50, height: 50)
    }
}

// MARK: - 缩略图

/// 卡片1: 宠物卡通缩略图
private struct PetThumbView: View {
    var body: some View {
        Canvas { ctx, _ in
            // 40x40 viewBox 坐标
            ctx.fill(Path(CGRect(x: 0, y: 0, width: 40, height: 40)),
                     with: .color(Color(red: 251/255, green: 191/255, blue: 36/255)))
            ctx.fill(pathFromPoints(petHairPoints),
                     with: .color(Color(red: 49/255, green: 16/255, blue: 47/255)))
            ctx.fill(pathFromPoints(petSweaterPoints),
                     with: .color(Color(red: 192/255, green: 132/255, blue: 252/255)))
            ctx.fill(Path(ellipseIn: CGRect(x: 20 - 5.2, y: 15.5 - 6, width: 10.4, height: 12)),
                     with: .color(Color(red: 217/255, green: 119/255, blue: 87/255)))
            // 怀里的白猫
            ctx.fill(pathFromPoints(petCatPoints),
                     with: .color(Color(red: 248/255, green: 250/255, blue: 252/255)))
            ctx.fill(polygon([(13, 23), (14, 18), (17, 22)]),
                     with: .color(Color(red: 248/255, green: 250/255, blue: 252/255)))
            ctx.fill(polygon([(21, 22), (24, 18), (25, 23)]),
                     with: .color(Color(red: 248/255, green: 250/255, blue: 252/255)))
            ctx.fill(Path(ellipseIn: CGRect(x: 15.5, y: 23.5, width: 2, height: 2)),
                     with: .color(Color(red: 30/255, green: 41/255, blue: 59/255)))
            ctx.fill(Path(ellipseIn: CGRect(x: 20.5, y: 23.5, width: 2, height: 2)),
                     with: .color(Color(red: 30/255, green: 41/255, blue: 59/255)))
            ctx.fill(Path(ellipseIn: CGRect(x: 17.8, y: 25.2, width: 2.4, height: 1.6)),
                     with: .color(Color(red: 244/255, green: 114/255, blue: 182/255)))
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func polygon(_ pts: [(CGFloat, CGFloat)]) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
        for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
        p.closeSubpath()
        return p
    }
}

/// 卡片2: 3D 屏幕缩略图
private struct ScreenThumbView: View {
    var body: some View {
        ZStack {
            Color(red: 15/255, green: 23/255, blue: 42/255)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(LinearGradient(stops: [
                        .init(color: Color(red: 30/255, green: 27/255, blue: 75/255), location: 0),
                        .init(color: Color(red: 59/255, green: 7/255, blue: 100/255), location: 0.5),
                        .init(color: Color(red: 6/255, green: 78/255, blue: 59/255), location: 1),
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color(red: 74/255, green: 222/255, blue: 128/255), lineWidth: 0.8))
                VStack(alignment: .leading, spacing: 3.2) {
                    bar(16, 2.5, Color(red: 74/255, green: 222/255, blue: 128/255), 1)
                    bar(22, 2, .white, 0.8)
                    bar(19, 2, Color(red: 192/255, green: 132/255, blue: 252/255), 0.85)
                    bar(13, 2, Color(red: 56/255, green: 189/255, blue: 248/255), 0.8)
                }
                .padding(EdgeInsets(top: 5, leading: 4, bottom: 0, trailing: 0))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: 32, height: 26)
            .offset(x: -0.5, y: 0.5)
            .rotationEffect(.degrees(-14))
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func bar(_ w: CGFloat, _ h: CGFloat, _ c: Color, _ op: Double) -> some View {
        RoundedRectangle(cornerRadius: 1).fill(c.opacity(op)).frame(width: w, height: h)
    }
}

// MARK: - 共享组件

/// 玻璃圆形按钮（搜索 / 返回 / 麦克风 / 键盘）
private struct GlassCircleButton<Icon: View>: View {
    var size: CGFloat
    @ViewBuilder var icon: () -> Icon
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            ZStack {
                Circle()
                    .fill(Color(red: 34/255, green: 42/255, blue: 56/255).opacity(0.82))
                icon()
                    .foregroundColor(Color.white.opacity(0.9))
            }
            .frame(width: size, height: size)
            .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(ChatGPTPressStyle())
    }
}

/// 按压缩放（HTML active scale 0.9 + 回弹）
private struct ChatGPTPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// 屏幕边缘环境蓝光（voice 模式点亮, 0.7s 淡入）
private struct AmbientGlowOverlay: View {
    let active: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 55, style: .continuous)
                .stroke(Color(red: 43/255, green: 118/255, blue: 1).opacity(0.48), lineWidth: 14)
                .blur(radius: 7)
            RoundedRectangle(cornerRadius: 55, style: .continuous)
                .stroke(Color(red: 95/255, green: 165/255, blue: 1).opacity(0.38), lineWidth: 3)
                .blur(radius: 2)
        }
        .opacity(active ? 1 : 0)
        .animation(.easeInOut(duration: 0.7), value: active)
        .allowsHitTesting(false)
    }
}

/// 蓝宝石玻璃斜向反光（常显）
private struct GlassReflectionOverlay: View {
    var body: some View {
        LinearGradient(stops: [
            .init(color: Color.white.opacity(0.08), location: 0),
            .init(color: Color.white.opacity(0.015), location: 0.28),
            .init(color: .clear, location: 0.45),
            .init(color: .clear, location: 0.80),
            .init(color: Color(red: 59/255, green: 130/255, blue: 246/255).opacity(0.06), location: 1),
        ], startPoint: UnitPoint(x: 0.12, y: 0.18), endPoint: UnitPoint(x: 0.88, y: 0.82))
        .allowsHitTesting(false)
    }
}

/// 248x308 设计画布的径向背景（farthest-corner 半径）
private func dialBackground(stops: [(Double, Color)], center: CGPoint) -> some View {
    let corners = [CGPoint(x: 0, y: 0), CGPoint(x: 248, y: 0),
                   CGPoint(x: 0, y: 308), CGPoint(x: 248, y: 308)]
    let far = corners.map { pow($0.x - center.x, 2) + pow($0.y - center.y, 2) }.max()!.squareRoot()
    let unit = UnitPoint(x: center.x / 248, y: center.y / 308)
    return RadialGradient(
        stops: stops.map { Gradient.Stop(color: $0.1, location: $0.0) },
        center: unit, startRadius: 0, endRadius: far)
}

#Preview {
    NavigationView {
        ChatGPTTestView()
    }
}
