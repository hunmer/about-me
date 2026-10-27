# iOS / watchOS 构建要点

> 沉淀自 2026-10-27 排查：Watch App 构建报 `Module 'Flutter' not found`、真机安装闪退等问题。

## 工程结构

- iOS 主 App：Flutter（`ios/Runner.xcworkspace`，CocoaPods + SPM 插件混合）
- Watch App：SwiftUI 原生（`ios/aboutme Watch App/`，Xcode 文件夹自动同步进 target，新建 swift 文件无需改 pbxproj）
- 两个独立 scheme：`Runner`（iOS）和 `aboutme Watch App`（watchOS）

## 构建 iOS 主 App

```bash
# 模拟器开发调试（推荐，自动构建+安装+attach 日志）
flutter run -d <deviceId>

# 真机安装：必须用 release 或 profile
flutter build ios --release --no-tree-shake-icons
xcrun devicectl device install app --device <UDID> build/ios/iphoneos/Runner.app
```

要点：

- **真机更新务必用 `devicectl device install app`（覆盖安装，保留数据）**。
  勿用 `flutter install`——它会先 `Uninstalling old version` 再安装，iOS 卸载即清空
  沙盒（Documents / UserDefaults / 本地数据库 / Keychain 部分数据），已踩过坑。
  debug→release 覆盖安装本身不清数据。

- **真机只能装 release/profile**。debug 构建从桌面图标启动会立刻闪退（signal 11），日志特征：
  `Cannot create a FlutterEngine instance in debug mode without Flutter tooling or Xcode`。
  debug 包只能通过 `flutter run` / Xcode Run 附着启动。
- **`--no-tree-shake-icons`**：项目里存在非 const 的 `IconData` 调用，不加会报
  `Avoid non-constant invocations of IconData`。
- **勿把 `--no-codesign` 产物装真机**：会报 `No code signature found (0xe800801c)`。
  `--no-codesign` 只用于 CI/编译验证；真机安装必须带签名构建（项目已配置 Automatic + Team）。
- `flutter devices` 查看设备 UDID。

## 构建 Watch App

Xcode：scheme 选 `aboutme Watch App`，destination 选**具体的 Apple Watch 模拟器**，Cmd+R。

命令行：

```bash
xcodebuild -project ios/Runner.xcodeproj -scheme "aboutme Watch App" \
  -destination 'platform=watchOS Simulator,id=<watch UDID>' build

# 安装到已启动的 watch 模拟器并运行
xcrun simctl install <watch UDID> "<DerivedData>/Build/Products/Debug-watchsimulator/aboutme Watch.app"
xcrun simctl launch <watch UDID> github.hunmer.aboutme.watchkitapp
```

## 已修的坑（勿回退）

1. **`aboutme Watch App` scheme 的 BuildAction 已移除 `Runner.app`**（xcshareddata/xcschemes）。
   原因：watchOS destination 构建时 Runner 连带的全部 iOS 插件（flutter_native_splash、
   watch_connectivity 等）会被按 watchOS SDK 编译，而 Flutter 模块只有 iOS slice，
   必然报 `Module 'Flutter' not found` / `'Flutter/Flutter.h' file not found`。
   watch app 可独立构建；需要完整 iOS app 时用 Runner scheme（会自动带上 watch app）。

2. **表情测试页（MoodTestView）全屏铺满**：`ignoresSafeArea()` + 隐藏导航栏
   （`toolbar(.hidden, for: .navigationBar)`），x/y 独立缩放铺满，返回靠左缘右滑手势。

## 常见错误速查

| 报错 | 原因 | 解法 |
|---|---|---|
| `Module 'Flutter' not found`（大量插件） | iOS 插件被按 watchOS SDK 编译 | 用 watch scheme（已修）；勿用 generic destination 全量构建 |
| `No code signature found (0xe800801c)` | 安装了 `--no-codesign` 产物 | 重新 `flutter build ios`（不带该参数） |
| 真机点图标秒退 signal 11 | debug 包脱离工具链启动 | 装 release/profile 构建 |
| `Avoid non-constant invocations of IconData` | release 的 icon tree-shake 限制 | 加 `--no-tree-shake-icons` |
| 更新后 App 数据全没了 | 用了 `flutter install`（先卸载再装） | 改用 `devicectl device install app` 覆盖安装 |

## 产物路径

- iOS 真机包：`build/ios/iphoneos/Runner.app`
- Watch 模拟器包：`~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Products/Debug-watchsimulator/aboutme Watch App.app`
