# Handoff: Live2D 快速迭代（右键/缩放/点击/气泡 + 陪伴数值）

- 日期: 2026-09-05（单日多轮：数值设计→实现→交互打磨）
- 仓库: `/Users/Zhuanz/Documents/Aboutme`（Flutter, branch `main`）。**Live2D 包是路径依赖 `../flutter_live2d-main`**（pubspec.yaml 第 136 行），本次大半改动在那个包里，两边都未提交。
- 验证基线: 包 `flutter analyze` 0 issues、`flutter test` 3/3 通过；app `flutter analyze` 改动文件 0 新问题（全库存量 warning 不变）；`flutter build macos --debug` 成功；无头冒烟（直接执行 app 二进制，日志 grep `runtime ready|loadModel completed`，10s 后 kill）通过。
- 用户在 macOS 上自己跑调试实例（bundle id `github.hunmer.aboutme`，pid 21700 之类，**不要动它**）；我方测试一律直接执行 `build/macos/Build/Products/Debug/Aboutme.app/Contents/MacOS/Aboutme` 起新实例，测完 kill。

## 一、本次会话完成了什么

按时间顺序 6 轮，全部围绕 `lib/screens/jelly_home/`（果冻小屋首页）：

| 轮次 | 内容 | 主要文件 |
|---|---|---|
| 1 | 陪伴数值设计讨论（情绪/精力/好感/货币/陪伴/记忆六选四） | — |
| 2 | 实现 1/2/3/5 号数值：`CompanionController` + `JellyCompanionCard`，替换 `_buildTaskRow` | `lib/screens/jelly_home/companion_controller.dart`（新）、`widgets/jelly_companion_card.dart`（新）、`jelly_home_screen.dart` |
| 3 | Live2D 右键修复（WKWebView Reload 菜单）+ 默认放大 + 尺寸持久化（放大/缩小/重置进面板） | 包 macOS Swift + Dart；app `widgets/jelly_live2d.dart` |
| 4 | 移除 `_buildQuickActions`（写日记/打卡/记账圆钮行） | `jelly_home_screen.dart` |
| 5 | 可点击区域（HitAreas）红色叠加层可视化 + 点击命中区域→随机动作 + 好感联动 | 包 TS/Swift/Dart 全链路 + app |
| 6 | 台词气泡：点击随机台词浮在角色上方，打字机逐字浮现，接缝横线修复 | `widgets/jelly_speech_bubble.dart`（重写）、`jelly_live2d.dart` |

已无引用但保留的文件：`widgets/jelly_daily_tasks_card.dart`、`widgets/jelly_growth_card.dart`、`widgets/jelly_quick_action.dart`（下一轮可删）。

## 二、Live2D 包架构（理解后续修改的前提）

```
Flutter AppKitView (view.dart)
  └ macOS 原生 Live2DWebView: NSView 内嵌 WKWebView（FlutterLive2dPlugin.swift）
      └ 本地 HTTP 服务 (NWListener) 提供 runtime/shader/模型文件
          └ WKWebView 跑 Cubism Web SDK（JS bundle）
```

- **JS runtime 源码是 TS**：`web_runtime/src/runtime.ts`（视图/命令分发/渲染循环/叠加层/点击）、`lappmodel.ts`（模型封装/hitTest/区域矩形）。`vendor/framework` 是官方 Cubism 框架，**未改**。
- **改 TS 后必须重新打包**：`cd web_runtime && npm install && npm run build`（esbuild → `assets/web/flutter_live2d_web.js`，无 tsconfig，不做类型检查）。
- 命令链路（Dart→原生→JS）：`Live2DViewController.xxx` → `MethodChannelFlutterLive2d`（channel `'flutter_live2d'`）→ Swift `handle()` `case "xxx"` → `view.command("xxx", args)` → JS `api.xxx(viewId, ...)`。
- **反向事件（原生→Dart）只有一条通道**：`view_controller.dart` 的 `_ensureContextMenuBridge()` 在首个 controller 创建时懒挂 `setMethodCallHandler`（不能在 MethodChannelFlutterLive2d 构造函数里挂——static final 初始化早于 binding，测试会炸）。现支持 `onContextMenu`、`onTap`，按 `viewId` 查 `_attachedControllers` 注册表分发到 `Live2DViewController.onContextMenu / onTap` 回调。
- **新增平台接口方法时**：`flutter_live2d_platform_interface.dart`（throwing 默认体）+ `flutter_live2d_method_channel.dart` 实现 + **`test/flutter_live2d_test.dart` 的 `_MockFlutterLive2dPlatform` 必须同步补 override**（否则 non_abstract_class_inherits_abstract_member）。

## 三、关键机制细节（踩过的坑）

1. **macOS 平台视图吃掉所有鼠标事件**：点击/右键到不了 Flutter 手势层。右键：Swift `Live2DWKWebView`（WKWebView 子类）重写 `rightMouseDown` → 闭包 → channel `invokeMethod("onContextMenu")`；`willOpenMenu` 里 `menu.removeAllItems()` 兜底清掉 WebKit 菜单。点击：JS `pointerup` 判定（主键 + 位移 ≤6px，拖拽视线跟随不触发）→ `hitTestAny` → postMessage `{type:'tap', hitAreaId, hitAreaName, x, y}` → Swift → channel `onTap` → Dart 回调 `onTap(hitAreaId, hitAreaName, x, y)`（坐标为 -1..1 视图系）。
2. **HitAreas 数据事实**（`assets/models/*/`）：
   - mao：`HitAreaHead`/`HitAreaBody`，**Name 全为空串** → 标签与动作映射都要用 Id 去掉 `HitArea` 前缀兜底；动作 Idle×1 + 默认分组×6 + 8 表情。
   - ren：Body/Head 正常命名；Idle×1 + 默认分组×2 + 5 表情。
   - icegirl：**无 HitAreas、无注册动作** → 点击只有台词气泡响应（走 miss 池）。
3. **可点击区域叠加层**：`setHitAreasVisible(viewId, visible)` 命令；开启后每帧 `getHitAreaRects(projection)` 把 hit area 网格顶点经 `projection×modelMatrix`（与渲染同矩阵）变换到 NDC，画在 `pointer-events:none` 的 2D canvas 上（红框 + 标签，跟随动画）。模型卸载/关闭时清屏。
4. **点击→动作选择**（app `_playTapMotion`）：优先 Cubism 惯例分组 `Tap<区域>`（如 TapHead，当前模型都没有），否则默认分组 `''` 随机，priority 3（force）。**不要用 try/catch 试探不存在的分组**——`_wrap` 会把异常写进 `Live2DViewState.lastError`，底部胶囊会显示"加载失败"。
5. **尺寸持久化**：`SharedPreferences` key `jelly_live2d.size`，默认 360（本从 280 放大），clamp 200–560、步进 40；`AnimatedContainer` 200ms 过渡。
6. **陪伴数值**（`CompanionController`，prefs 前缀 `companion.`）：
   - 情绪 0–100（≥80 开心/≥50 平静/≥30 一般/低落），**跨天回落到基线 70**；
   - 精力 0–100（≥80 充沛/≥50 良好/≥25 疲惫/更低没电），离线每小时 -1、**底线 20 不惩罚**；
   - 好感度累计只涨，阶段 陌生<200≤熟悉<600≤伙伴<1200≤挚友，**每日获取上限 20**；
   - 陪伴天数：连续（昨天有互动才 +1，断档重置 1）+ 累计；
   - 全部**离线结算**（load 时按 `lastActiveAt`/日键一次性算），无 Timer 滴答；首启有演示初值（mood 85/energy 90/affection 240）。
   - 交互入口：点击命中角色（hitAreaId != null）→ `recordInteraction()`（情绪+2、好感+2 受上限、记陪伴日）；`JellyCompanionCard` 点卡片也算。
7. **气泡**：`JellySpeechBubble` 重写为**单一 CustomPaint**——胶囊 RRect 与尾巴 `Path.combine(union)` 后一次画阴影(MaskFilter)/填充/描边，消除旧版「胶囊底边描边横穿尾巴」的接缝线。文字用 `TypewriterText`（110ms/字），**3 秒隐藏计时从打完字才开始**（`onTypingComplete` 回调启动）。台词池分 head/body/miss 三档（`jelly_live2d.dart` 顶部常量），不与上一条重复；任何点击（含点空）都出气泡。

## 四、已知边界与下一步建议

- **事件转发仅 macOS**：iOS（`ios/Classes/Live2DView.swift` 是另一套原生实现）、Windows、Web 都还没有 onContextMenu/onTap；Dart 回调在这些平台静默不触发（app 侧已兼容）。
- 表情（`setExpression(index)`）没用起来：Dart 不知道表情数量，随机 index 会踩 error pill；要做得先加 `getExpressions` 之类的查询命令。
- 台词池目前静态；可按 `moodTier`/`affectionTier` 联动（controller 已有 getter），头部点击顺手随机表情也是官方 sample 行为。
- 数值第 4 号（果冻糖货币→商店）和第 6 号（记忆碎片→年度报告）未实现。
- `CompanionController` 的跨天/衰减结算逻辑值得补单测（构造注入时钟）。
- iOS Live2D 实现与 macOS 完全不同（原生 Cubism 而非 WebView），若要移动端同体验需单独移植 hitTest/事件转发。

## 五、验证清单（改包后必跑）

```bash
cd /Users/Zhuanz/Documents/flutter_live2d-main
  cd web_runtime && npm run build && cd ..   # 改了 TS 才需要
  flutter analyze && flutter test
cd /Users/Zhuanz/Documents/Aboutme
  flutter analyze        # grep 本次改动文件
  flutter build macos --debug
  # 无头冒烟：直接执行 Debug/Aboutme.app/Contents/MacOS/Aboutme，
  # 10s 后 kill，日志确认 "JavaScript runtime ready" + "loadModel completed"
```

交互验证（用户自测）：右键人物→面板（放大/缩小/重置持久化、可点击区域开关）；点击命中→随机动作+台词气泡（控制台 grep `tap hitAreaId` 可看判定结果）。

## 六、建议技能（suggested skills）

- 继续数值/剧情玩法设计讨论：`mattpocock-skills:grilling`、`mattpocock-skills:to-spec`
- 多轮大改（如 iOS 事件移植）：`mattpocock-skills:implement`、`mattpocock-skills:tdd`（给 CompanionController 补结算单测）
- 又一轮交接：`handoff`
