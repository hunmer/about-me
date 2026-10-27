# AI 聊天后台服务测试指南

## 当前实现与验收（2026-10）

以下说明以当前代码为准，后文的旧日志和逐阶段通知示例仅供历史参考。

- Android 使用前台服务提高存活能力；每轮请求有独立 taskId，多会话共享服务，最后一个任务结束才停止聊天服务。活人感保活会在聊天结束后按最新开关恢复，未知服务不被抢占。
- iOS 使用原生 `beginBackgroundTask` 申请有限执行时间；系统决定时长，无法保证长 SSE 在后台完成。到期后尽力保存部分正文并取消当前请求；回前台查看结果，必要时手动重新生成。
- AI 请求仍在应用主 isolate 中执行。系统终止进程后不会自动恢复网络连接或重放工具操作；重新打开会话时，遗留生成状态会标记为中断并保留部分正文。
- 完成通知在整轮结果保存后由主 isolate 发送；前台完成不弹独立通知，后台成功/失败弹一次，用户取消不弹成功通知。通知发送失败保留内存待重试，回前台重试；进程终止后不保证补发。
- 运行时通知权限仍需由用户允许。仅修改 Dart 代码的热重载不足以验证 iOS 原生插件变更，需要重新安装构建。

### 自动回归

```bash
flutter test --no-pub "test/agent_chat_execution_result_test.dart" "test/chat_background_coordinator_test.dart" "test/agent_chat_publication_test.dart" "test/deepseek_thinking_transport_test.dart"
flutter test --no-pub "packages/aboutme_foreground_service/test/foreground_service_test.dart" "packages/aboutme_foreground_service/test/finite_background_task_test.dart"
```

### 真机验收

使用 Release/Profile，并脱离调试器运行，避免调试连接改变 iOS 挂起行为。

1. 允许通知，发送长回复后切后台/锁屏。Android 应持续显示运行通知，结束后出现独立完成通知，聊天运行通知退出。
2. 重新生成、工具调用、多 Agent 链分别重复步骤 1；每轮只出现一次终态通知。前台等待完成应无独立通知。
3. 同时处理两个会话，完成一个时另一个继续；启用活人感保活后重复，结束后守护通知恢复；关闭保活后不恢复。
4. 在 Android 运行通知点击取消，回应用查看：已有正文保留，生成状态结束，后续可以重新发送。
5. iOS 分别测试短请求和超过系统后台窗口的长请求：短请求尽力完成并通知；长请求回前台应保留已有正文，不能永久卡在“生成中”。
6. 关闭通知权限完成一轮，恢复权限并返回应用，检查失败通知只重试一次；强制关闭应用后重开，不应自动重放请求或工具操作。

---

## 📋 功能概述

已实现 AI 聊天后台服务，支持在切换到其他应用后继续接收 AI 回复并显示通知。

### 实现的功能
- ✅ Android 前台服务（显示持续通知）
- ✅ 切换APP后继续生成AI回复
- ✅ 生成完成后显示系统通知
- ✅ 通知按钮支持取消生成
- ✅ 点击通知返回聊天界面
- ✅ 生成进度实时更新
- ✅ 错误处理和通知

### 平台支持
- ✅ **Android**: 完整支持（前台服务 + 后台运行）
- ⚠️ **iOS**: 仅前台支持（约30秒后台时间）
- ❌ **Web/Desktop**: 不支持后台服务

---

## 🔧 实现文件清单

### 新增文件
1. **`lib/plugins/agent_chat/services/chat_task_handler.dart`**
   - AI 聊天后台任务处理器
   - 在独立 isolate 中运行
   - 处理通知更新和用户交互

### 修改文件
2. **`lib/plugins/agent_chat/controllers/chat_controller.dart`**
   - 集成前台服务管理器
   - 添加生成状态通知
   - 实现后台服务通信

### 依赖文件（已存在）
3. **`lib/core/services/foreground_task_manager.dart`**
   - 前台服务管理器封装
4. **`lib/core/notification_controller.dart`**
   - 系统通知管理器
5. **`android/app/src/main/AndroidManifest.xml`**
   - 已配置必要权限和服务

---

## 🧪 测试步骤

### 准备工作

1. **确保设备/模拟器运行 Android**
   ```bash
   flutter devices
   ```

2. **构建并安装应用**
   ```bash
   flutter run --release
   # 或
   flutter build apk && adb install build/app/outputs/flutter-apk/app-release.apk
   ```

3. **授予必要权限**
   - 首次运行会自动请求通知权限
   - 手动检查：设置 > 应用 > Aboutme > 权限 > 通知（允许）

---

### 测试场景 1: 基本后台生成

**目标**: 验证切换APP后AI继续生成

**步骤**:
1. 打开 Aboutme 应用
2. 进入聊天插件（agent_chat）
3. 输入一个需要较长时间回复的问题（例如："请用500字介绍Flutter框架"）
4. 点击发送
5. **立即按 Home 键**切换到桌面或其他应用
6. **观察通知栏**

**预期结果**:
- ✅ 通知栏显示 "AI助手运行中"
- ✅ 通知文本显示 "AI正在生成回复..."（带动画点）
- ✅ 通知中有 "取消" 按钮
- ✅ 生成完成后通知更新为 "AI回复完成"
- ✅ 显示独立的系统通知 "💬 AI回复完成"

---

### 测试场景 2: 通知交互

**目标**: 验证点击通知和按钮的功能

**步骤**:
1. 执行测试场景 1 的步骤 1-5
2. 在生成过程中，点击通知栏的 **"取消" 按钮**

**预期结果**:
- ✅ AI 生成立即停止
- ✅ 通知更新为 "AI生成已取消"
- ✅ 返回应用后消息显示 "用户已取消操作"

**步骤**:
3. 再次发送消息并切换到后台
4. 等待生成完成后，**点击通知本体**（不是按钮）

**预期结果**:
- ✅ 应用自动打开到聊天界面
- ✅ 显示完整的 AI 回复

---

### 测试场景 3: 错误处理

**目标**: 验证网络错误时的通知

**步骤**:
1. **关闭网络连接**（飞行模式或断开WiFi）
2. 发送消息
3. 切换到后台

**预期结果**:
- ✅ 通知显示 "AI回复失败"
- ✅ 显示错误原因（网络连接失败）
- ✅ 前台服务自动停止

---

### 测试场景 4: 工具调用流程

**目标**: 验证带工具调用的长流程

**步骤**:
1. 发送需要工具调用的请求
2. 切换到后台
3. 观察通知变化

**预期结果**:
- ✅ 第一阶段: "AI思考完成，准备执行..."
- ✅ 工具执行期间: 通知持续显示
- ✅ 最终完成: "AI回复完成" + 系统通知

---

### 测试场景 5: 多次切换

**目标**: 验证前后台多次切换的稳定性

**步骤**:
1. 发送消息
2. 切换到后台（Home 键）
3. 返回应用（点击图标或通知）
4. 再次切换到后台
5. 等待完成

**预期结果**:
- ✅ 切换过程中 AI 生成不中断
- ✅ 通知状态正确同步
- ✅ 返回应用后界面正常显示生成进度

---

## 🐛 常见问题排查

### 问题 1: 通知不显示

**可能原因**:
- 通知权限未授予
- 系统省电模式限制

**解决方法**:
```bash
# 检查通知权限
adb shell dumpsys notification

# 检查应用电池优化状态
adb shell dumpsys deviceidle whitelist
```

手动操作:
- 设置 > 应用 > Aboutme > 权限 > 通知（开启）
- 设置 > 电池 > 电池优化 > Aboutme（不优化）

---

### 问题 2: 切换后台后服务立即停止

**可能原因**:
- Android 12+ 后台服务限制
- 应用被系统强制停止

**解决方法**:
1. 确保前台通知正常显示
2. 检查 AndroidManifest.xml 权限配置
3. 在开发者选项中关闭 "不保留活动"

---

### 问题 3: 生成完成后没有系统通知

**可能原因**:
- `_isInChatScreen()` 判断为在前台

**调试方法**:
```dart
// 在 chat_controller.dart:2017 添加日志
bool _isInChatScreen() {
  final lifecycleState = WidgetsBinding.instance.lifecycleState;
  debugPrint('🔍 [lifecycleState] $lifecycleState');  // 添加这行
  if (lifecycleState != AppLifecycleState.resumed) {
    return false;
  }
  return true;
}
```

---

### 问题 4: 前台服务无法启动

**错误日志示例**:
```
❌ [ChatController] 启动前台服务失败: ForegroundServiceStartNotAllowedException
```

**原因**: Android 12+ 限制后台启动前台服务

**解决方法**:
- 确保在应用在前台时启动服务（sendMessage 时已满足）
- 检查是否有 `FOREGROUND_SERVICE` 权限

---

## 📊 日志监控

### 查看完整日志
```bash
# 实时查看所有日志
adb logcat | grep -E "ChatController|后台服务|ForegroundTask"

# 过滤关键事件
adb logcat | grep -E "🚀|✅|❌|📨|🤖"
```

### 关键日志标记
- `🚀` - 服务启动
- `✅` - 操作成功
- `❌` - 错误发生
- `📨` - 数据通信
- `🤖` - 后台服务事件

---

## 🔍 调试技巧

### 1. 强制触发后台场景
```bash
# 模拟应用进入后台
adb shell input keyevent KEYCODE_HOME

# 模拟通知点击
adb shell am start -n github.hunmer.aboutme/.MainActivity --es route "/chat"
```

### 2. 检查前台服务状态
```bash
# 查看正在运行的服务
adb shell dumpsys activity services | grep -A 10 "ForegroundService"
```

### 3. 监控通知
```bash
# 实时监控通知事件
adb logcat | grep NotificationManager
```

---

## 📈 性能指标

### 预期性能
- **服务启动时间**: < 500ms
- **通知更新延迟**: < 100ms
- **通知显示延迟**: < 200ms
- **内存占用增加**: < 10MB

### 监控命令
```bash
# 监控内存使用
adb shell dumpsys meminfo github.hunmer.aboutme

# 监控CPU使用
adb shell top | grep aboutme
```

---

## ✅ 验收标准

### 必须通过的测试
- [ ] 切换到其他应用后 AI 继续生成
- [ ] 生成完成后显示系统通知
- [ ] 点击通知能返回聊天界面
- [ ] 取消按钮能停止生成
- [ ] 网络错误时显示错误通知
- [ ] 多次切换应用不崩溃

### 可选优化（未来改进）
- [ ] 支持多个并发生成任务
- [ ] 自定义通知声音和振动
- [ ] 通知中显示生成进度百分比
- [ ] 支持快速回复功能

---

## 🔄 回滚方案

如果后台服务出现严重问题，可以临时禁用：

**方法 1**: 代码级禁用
```dart
// 在 chat_controller.dart:297 注释掉
// if (!kIsWeb && Platform.isAndroid) {
//   await _startAIChatService(conversation.id, aiMessage.id);
// }
```

**方法 2**: 用户设置（未实现，可扩展）
```dart
// 在设置中添加开关
final enableBackgroundService = settings['enableBackgroundService'] ?? false;
if (enableBackgroundService && !kIsWeb && Platform.isAndroid) {
  await _startAIChatService(conversation.id, aiMessage.id);
}
```

---

## 📞 联系支持

如有问题，请提供以下信息：
- Android 版本
- 应用版本
- 完整日志（`adb logcat > log.txt`）
- 复现步骤

---

**测试完成后记得标记**: `[x] AI 后台服务测试通过`

**最后更新**: 2025-11-20
**版本**: v1.0.0
