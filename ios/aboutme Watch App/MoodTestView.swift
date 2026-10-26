//
//  MoodTestView.swift
//  aboutme_watchos Watch App
//
//  复刻 gemini-code-1793030591089.html 的 4 屏心情记录 UI：
//  1. How Are You Feeling? 心情气泡选择
//  2. 今日心情大表情
//  3. 周历史列表（Mar 16 - 22）
//  4. Update My Mood 毛玻璃更新层
//

import SwiftUI
import Combine

// MARK: - 心情类型

enum MoodFace: String, CaseIterable, Identifiable {
    case yellow
    case purple
    case greenStraight
    case blue
    case red

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yellow: return "Happy Day!"
        case .purple: return "Tired Day!"
        case .greenStraight: return "Calm Day"
        case .blue: return "Sad Day"
        case .red: return "Angry Day"
        }
    }

    var color: Color {
        switch self {
        case .yellow: return Color(red: 251/255, green: 217/255, blue: 117/255)
        case .purple: return Color(red: 162/255, green: 136/255, blue: 248/255)
        case .greenStraight: return Color(red: 134/255, green: 210/255, blue: 184/255)
        case .blue: return Color(red: 127/255, green: 162/255, blue: 248/255)
        case .red: return Color(red: 235/255, green: 110/255, blue: 85/255)
        }
    }
}

// MARK: - 表情绘制（100x100 设计坐标，对应 HTML 的 SVG viewBox）

enum MoodFaceRenderer {
    static let ink = Color(red: 20/255, green: 20/255, blue: 20/255)

    static func draw(face: MoodFace, tilted: Bool = false, in ctx: inout GraphicsContext) {
        // 底圆
        ctx.fill(Path(ellipseIn: CGRect(x: 0, y: 0, width: 100, height: 100)), with: .color(face.color))

        // 腮红（仅开心脸）
        if face == .yellow {
            drawBlush(cx: 24, cy: 54, r: 11, in: &ctx)
            drawBlush(cx: 76, cy: 54, r: 11, in: &ctx)
        }

        // 五官组整体旋转：GraphicsContext 为值类型，拷贝即 saveGState
        var g = ctx
        let rotation = rotationAngle(face: face, tilted: tilted)
        if rotation != 0 {
            g.translateBy(x: 50, y: 50)
            g.rotate(by: .degrees(rotation))
            g.translateBy(x: -50, y: -50)
        }
        let lw: CGFloat = (face == .greenStraight && !tilted) ? 3.4 : 3.2
        switch face {
        case .yellow:
            fillDot(36.5, 40.5, 4.2, &g)
            fillDot(63.5, 40.5, 4.2, &g)
            strokeLine(50, 45, 50, 55, lw, &g)
            strokePath(smilePath(x0: 27, y: 56.5, r: 23.5), lw, &g)
        case .purple:
            strokeLine(29, 36, 42, 33, lw, &g)
            strokeLine(58, 33, 71, 36, lw, &g)
            fillDot(36.5, 43, 3.8, &g)
            fillDot(63.5, 43, 3.8, &g)
            strokeLine(50, 45, 50, 56, lw, &g)
            strokeLine(36, 68, 64, 68, lw, &g)
        case .greenStraight:
            if tilted {
                // 选择面板的斜向平静脸（rotate 24°）
                fillDot(36.5, 41, 4, &g)
                fillDot(63.5, 41, 4, &g)
                strokeLine(50, 43, 50, 55, lw, &g)
                strokeLine(37, 66, 63, 66, lw, &g)
            } else {
                // 列表/大表情的端正平静脸
                fillDot(37, 41, 4.2, &g)
                fillDot(63, 41, 4.2, &g)
                strokeLine(50, 44, 50, 55, lw, &g)
                strokeLine(36, 66, 64, 66, lw, &g)
            }
        case .blue:
            fillDot(36.5, 42, 4, &g)
            fillDot(63.5, 42, 4, &g)
            strokeLine(50, 45, 50, 56, lw, &g)
            strokePath(frownPath(x0: 35, x1: 65, y: 72, rx: 18, ry: 16), lw, &g)
        case .red:
            strokeLine(27, 31, 41, 40, lw, &g)
            strokeLine(73, 31, 59, 40, lw, &g)
            fillDot(36, 46, 3.8, &g)
            fillDot(64, 46, 3.8, &g)
            strokeLine(50, 48, 50, 59, lw, &g)
            strokePath(frownPath(x0: 31, x1: 69, y: 76, rx: 22, ry: 20), lw, &g)
        }
    }

    private static func rotationAngle(face: MoodFace, tilted: Bool) -> Double {
        switch face {
        case .purple: return 14
        case .greenStraight: return tilted ? 24 : 0
        case .blue: return -14
        case .red: return -14
        default: return 0
        }
    }

    private static func fillDot(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ ctx: inout GraphicsContext) {
        ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), with: .color(ink))
    }

    private static func strokeLine(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ lw: CGFloat, _ ctx: inout GraphicsContext) {
        var p = Path()
        p.move(to: CGPoint(x: x1, y: y1))
        p.addLine(to: CGPoint(x: x2, y: y2))
        strokePath(p, lw, &ctx)
    }

    private static func strokePath(_ p: Path, _ lw: CGFloat, _ ctx: inout GraphicsContext) {
        ctx.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
    }

    private static func drawBlush(cx: CGFloat, cy: CGFloat, r: CGFloat, in ctx: inout GraphicsContext) {
        let gradient = Gradient(colors: [
            Color(red: 232/255, green: 122/255, blue: 100/255).opacity(0.58),
            Color(red: 251/255, green: 217/255, blue: 117/255).opacity(0),
        ])
        let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
            gradient,
            center: CGPoint(x: cx, y: cy),
            startRadius: 0,
            endRadius: r
        ))
    }

    // 微笑弧 ∪：从 (x0, y) 经底部 (x0+r, y+r) 到 (x0+2r, y)，两段 90° 圆弧的 cubic 近似
    private static func smilePath(x0: CGFloat, y: CGFloat, r: CGFloat) -> Path {
        let k = 0.5523 * r
        var p = Path()
        p.move(to: CGPoint(x: x0, y: y))
        p.addCurve(to: CGPoint(x: x0 + r, y: y + r),
                    control1: CGPoint(x: x0, y: y + k),
                    control2: CGPoint(x: x0 + r - k, y: y + r))
        p.addCurve(to: CGPoint(x: x0 + 2 * r, y: y),
                    control1: CGPoint(x: x0 + r + k, y: y + r),
                    control2: CGPoint(x: x0 + 2 * r, y: y + k))
        return p
    }

    // 难过/皱嘴弧 ∩：端点 (x0,y)-(x1,y) 等高，椭圆半轴 rx/ry，弧顶上凸。
    // 椭圆弧等价于圆弧(半径 rx, 圆心在端点下方 d=√(rx²-h²)) 绕 (cx,y) 做 y 缩放 s=ry/rx，
    // 先在圆弧空间取两段 cubic 近似，再对控制点做 y 仿射。
    private static func frownPath(x0: CGFloat, x1: CGFloat, y: CGFloat, rx: CGFloat, ry: CGFloat) -> Path {
        let h = (x1 - x0) / 2
        let cx = (x0 + x1) / 2
        let d = (rx * rx - h * h).squareRoot()
        let s = ry / rx
        let alpha = asin(min(1, max(-1, d / rx)))
        let seg = CGFloat.pi / 2 - alpha          // 每段弧角，两端对称
        let k = CGFloat(4.0 / 3.0) * tan(seg / 4) * rx

        let topY = y + d - rx                      // 圆弧空间顶点
        // 端点处切线（朝顶点走向）：⊥ OA，即 (d, -h)/rx；顶点处切线水平
        let sy: (CGFloat) -> CGFloat = { yy in y + s * (yy - y) }
        let c1 = CGPoint(x: x0 + k * d / rx, y: y - k * h / rx)
        let c2 = CGPoint(x: cx - k, y: topY)
        let c3 = CGPoint(x: cx + k, y: topY)
        let c4 = CGPoint(x: x1 - k * d / rx, y: y - k * h / rx)

        var p = Path()
        p.move(to: CGPoint(x: x0, y: y))
        p.addCurve(to: CGPoint(x: cx, y: sy(topY)),
                    control1: CGPoint(x: c1.x, y: sy(c1.y)),
                    control2: CGPoint(x: c2.x, y: sy(c2.y)))
        p.addCurve(to: CGPoint(x: x1, y: y),
                    control1: CGPoint(x: c3.x, y: sy(c3.y)),
                    control2: CGPoint(x: c4.x, y: sy(c4.y)))
        return p
    }
}

struct MoodFaceView: View {
    let face: MoodFace
    var tilted = false
    var size: CGFloat = 100

    var body: some View {
        Canvas { ctx, _ in
            MoodFaceRenderer.draw(face: face, tilted: tilted, in: &ctx)
        }
        .frame(width: 100, height: 100)
        .scaleEffect(size / 100, anchor: .center)
        .frame(width: size, height: size)
    }
}

// MARK: - 数据与状态

@MainActor
final class MoodTestViewModel: ObservableObject {
    struct MoodDay: Identifiable {
        var num: String
        let day: String
        var mood: MoodFace
        var title: String
        var id: String { num }
    }

    struct MoodWeek {
        let label: String
        var items: [MoodDay]
    }

    // 气泡循环顺序（对应 Update 按钮的循环切换）
    static let bubbleOrder: [MoodFace] = [.purple, .blue, .greenStraight, .yellow, .red]

    @Published var weeks: [MoodWeek]
    @Published var weekIndex: Int = 2
    @Published var selectedBubble: MoodFace = .yellow
    @Published var displayFace: MoodFace = .yellow
    @Published var displayTitle: String = "Happy Day!"
    @Published var activeCardID: String = "22"

    init() {
        weeks = [
            MoodWeek(label: "Mar 2 - 8", items: [
                MoodDay(num: "08", day: "SUN", mood: .greenStraight, title: "Calm Day"),
                MoodDay(num: "07", day: "SAT", mood: .yellow, title: "Happy Day!"),
                MoodDay(num: "06", day: "FRI", mood: .purple, title: "Tired Day!"),
                MoodDay(num: "05", day: "THU", mood: .yellow, title: "Happy Day!"),
                MoodDay(num: "04", day: "WED", mood: .blue, title: "Sad Day"),
            ]),
            MoodWeek(label: "Mar 9 - 15", items: [
                MoodDay(num: "15", day: "SUN", mood: .purple, title: "Tired Day!"),
                MoodDay(num: "14", day: "SAT", mood: .yellow, title: "Happy Day!"),
                MoodDay(num: "12", day: "THU", mood: .greenStraight, title: "Calm Day"),
                MoodDay(num: "11", day: "WED", mood: .blue, title: "Sad Day"),
                MoodDay(num: "10", day: "TUE", mood: .red, title: "Angry Day"),
            ]),
            MoodWeek(label: "Mar 16 - 22", items: [
                MoodDay(num: "22", day: "SUN", mood: .yellow, title: "Happy Day!"),
                MoodDay(num: "21", day: "SAT", mood: .greenStraight, title: "Calm Day"),
                MoodDay(num: "19", day: "THU", mood: .yellow, title: "Happy Day!"),
                MoodDay(num: "18", day: "WED", mood: .red, title: "Angry Day"),
                MoodDay(num: "17", day: "TUE", mood: .purple, title: "Tired Day!"),
                MoodDay(num: "16", day: "MON", mood: .blue, title: "Sad Day"),
            ]),
        ]
    }

    var currentWeek: MoodWeek { weeks[weekIndex] }

    // 点击心情气泡：更新今日显示 + 历史列表第一项
    func selectBubble(_ face: MoodFace) {
        selectedBubble = face
        displayFace = face
        displayTitle = face.title
        if !weeks[weekIndex].items.isEmpty {
            weeks[weekIndex].items[0].mood = face
            weeks[weekIndex].items[0].title = face.title
        }
    }

    // 点击历史卡片：高亮并在今日屏显示该日心情
    func selectCard(_ day: MoodDay) {
        activeCardID = day.num
        displayFace = day.mood
        displayTitle = day.title
    }

    func changeWeek(_ delta: Int) {
        weekIndex = (weekIndex + delta + weeks.count) % weeks.count
        activeCardID = currentWeek.items.first?.num ?? ""
    }

    // Update My Mood：循环切换到下一个心情
    func cycleUpdate() {
        let idx = Self.bubbleOrder.firstIndex(of: selectedBubble) ?? 0
        selectBubble(Self.bubbleOrder[(idx + 1) % Self.bubbleOrder.count])
    }
}

// MARK: - 主视图（4 屏左右滑动）

struct MoodTestView: View {
    @StateObject private var vm = MoodTestViewModel()

    private typealias MoodDay = MoodTestViewModel.MoodDay

    private let dialSize = CGSize(width: 230, height: 280)

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / dialSize.width, geo.size.height / dialSize.height)
            TabView {
                scaledPage(geo: geo, scale: scale) { feelingDial }.tag(0)
                scaledPage(geo: geo, scale: scale) { todayDial }.tag(1)
                scaledPage(geo: geo, scale: scale) { historyDial }.tag(2)
                scaledPage(geo: geo, scale: scale) { updateDial }.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    private func scaledPage(geo: GeometryProxy, scale: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        content()
            .scaleEffect(scale)
            .frame(width: geo.size.width, height: geo.size.height)
    }

    // MARK: 屏1：How Are You Feeling?

    private var feelingDial: some View {
        DialFrame {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    DialStatusBar(leftText: "Mood")
                    Text("How Are You\nFeeling?")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(red: 18/255, green: 18/255, blue: 18/255))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .padding(.top, 16)
                    Spacer(minLength: 0)
                }
                ZStack {
                    bubble(.purple, center: CGPoint(x: 27, y: 47), size: 78)
                    bubble(.blue, center: CGPoint(x: 203, y: 49), size: 78)
                    bubble(.greenStraight, center: CGPoint(x: 30, y: 142), size: 78)
                    bubble(.yellow, center: CGPoint(x: 115, y: 141), size: 82)
                    bubble(.red, center: CGPoint(x: 200, y: 142), size: 78)
                }
                .frame(width: 230, height: 176)
            }
        }
    }

    private func bubble(_ face: MoodFace, center: CGPoint, size: CGFloat) -> some View {
        let selected = vm.selectedBubble == face
        return Button {
            vm.selectBubble(face)
        } label: {
            ZStack {
                if selected {
                    Circle()
                        .stroke(Color.black.opacity(0.12), lineWidth: 2)
                        .padding(-3)
                }
                MoodFaceView(face: face, tilted: face == .greenStraight, size: size)
            }
        }
        .buttonStyle(MoodPressableStyle())
        .position(center)
    }

    // MARK: 屏2：今日心情

    @State private var floating = false
    @State private var popScale: CGFloat = 1

    private var todayDial: some View {
        DialFrame {
            todayBody(floating: true)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
    }

    private func todayBody(floating: Bool) -> some View {
        VStack(spacing: 0) {
            DialStatusBar(leftText: "Mood")
            Text(vm.displayTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color(red: 18/255, green: 18/255, blue: 18/255))
                .padding(.top, 22)
                .padding(.bottom, 18)
            MoodFaceView(face: vm.displayFace, size: 134)
                .scaleEffect(popScale)
                .offset(y: floating ? -4 : 0)
                .onTapGesture { triggerPop() }
            Spacer(minLength: 0)
        }
        .onChange(of: vm.displayFace) { _, _ in
            triggerPop()
        }
    }

    private func triggerPop() {
        popScale = 0.75
        DispatchQueue.main.async {
            withAnimation(.interpolatingSpring(stiffness: 320, damping: 16)) {
                popScale = 1
            }
        }
    }

    // MARK: 屏3：周历史列表

    @State private var listHidden = false

    private var historyDial: some View {
        DialFrame {
            VStack(spacing: 0) {
                DialStatusBar(leftText: "Back", leftAction: {
                    if let first = vm.currentWeek.items.first {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            historyScrollProxy?.scrollTo(first.num, anchor: .top)
                        }
                    }
                })
                weekSelector
                historyList
            }
        }
    }

    @State private var historyScrollProxy: ScrollViewProxy?

    private var weekSelector: some View {
        HStack(spacing: 15) {
            Button {
                switchWeek(-1)
            } label: {
                weekArrow("chevron.left")
            }
            .buttonStyle(MoodPressableStyle())

            Text(vm.currentWeek.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 38/255, green: 38/255, blue: 38/255))
                .frame(minWidth: 66)

            Button {
                switchWeek(1)
            } label: {
                weekArrow("chevron.right")
            }
            .buttonStyle(MoodPressableStyle())
        }
        .padding(.top, 7)
        .padding(.bottom, 11)
    }

    private func weekArrow(_ icon: String) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 166/255, green: 166/255, blue: 170/255))
                .frame(width: 16, height: 16)
            Image(systemName: icon)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var historyList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(vm.currentWeek.items) { day in
                        historyCard(day)
                            .id(day.num)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .frame(height: 205)
            .onAppear { historyScrollProxy = proxy }
        }
        .opacity(listHidden ? 0 : 1)
        .offset(y: listHidden ? 6 : 0)
    }

    private func historyCard(_ day: MoodDay) -> some View {
        let active = vm.activeCardID == day.num
        return Button {
            vm.selectCard(day)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1.5) {
                    Text(day.num)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(red: 20/255, green: 20/255, blue: 20/255))
                    Text(day.day)
                        .font(.system(size: 9.5, weight: .bold))
                        .kerning(0.2)
                        .foregroundStyle(Color(red: 38/255, green: 38/255, blue: 38/255))
                }
                Spacer(minLength: 8)
                MoodFaceView(face: day.mood, size: 36)
            }
            .padding(.leading, 17)
            .padding(.trailing, 14)
            .frame(height: 55)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(active ? Color(red: 239/255, green: 239/255, blue: 239/255)
                                 : Color(red: 245/255, green: 245/255, blue: 245/255))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1.5)
                    .opacity(active ? 1 : 0)
            )
        }
        .buttonStyle(MoodPressableStyle())
    }

    private func switchWeek(_ delta: Int) {
        guard !listHidden else { return }
        withAnimation(.easeOut(duration: 0.18)) { listHidden = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            vm.changeWeek(delta)
            withAnimation(.easeOut(duration: 0.22)) { listHidden = false }
        }
    }

    // MARK: 屏4：Update My Mood 毛玻璃层

    @State private var spinAngle: Double = 0

    private var updateDial: some View {
        DialFrame {
            ZStack {
                todayBody(floating: false)
                    .blur(radius: 7)
                    .scaleEffect(1.04)
                    .opacity(0.85)
                    .allowsHitTesting(false)

                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(Color(red: 68/255, green: 68/255, blue: 70/255).opacity(0.74))

                VStack(spacing: 13) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.55)) { spinAngle += 360 }
                        vm.cycleUpdate()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 82, height: 82)
                                .shadow(color: .black.opacity(0.25), radius: 12, y: 10)
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(Color(red: 20/255, green: 20/255, blue: 20/255))
                                .rotationEffect(.degrees(spinAngle))
                        }
                    }
                    .buttonStyle(MoodPressableStyle())

                    Text("Update My Mood")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - 共享组件

// 表盘外框：230x280 白底圆角 32
struct DialFrame<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(width: 230, height: 280)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

// 表盘顶部状态栏（左：Mood/Back，右：时间）
struct DialStatusBar: View {
    let leftText: String
    var leftAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            if let action = leftAction {
                Button(leftText, action: action)
                    .buttonStyle(.plain)
            } else {
                Text(leftText)
            }
            Spacer()
            Text("3:24")
        }
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(Color(red: 24/255, green: 24/255, blue: 24/255))
        .padding(EdgeInsets(top: 15, leading: 19, bottom: 4, trailing: 19))
    }
}

// 按压缩放反馈（模拟 HTML 的 active scale 0.92 + Q 弹回弹）
struct MoodPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: configuration.isPressed)
    }
}
