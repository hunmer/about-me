# Windows TTS 完全指南

## 📋 目录
- [系统要求](#系统要求)
- [安装语音包](#安装语音包)
- [验证安装](#验证安装)
- [应用配置](#应用配置)
- [常见问题](#常见问题)
- [可用语音列表](#可用语音列表)

---

## 🎯 系统要求

- **操作系统**: Windows 10 (1803+) 或 Windows 11
- **Flutter**: 3.7.0+
- **flutter_tts**: 3.8.0+

---

## 📦 安装语音包

### 方法一：通过 Windows 设置（推荐）

#### Windows 10

1. **打开设置**
   ```
   Win + I → 时间和语言 → 语音
   ```

2. **管理语音**
   - 点击"管理语音"
   - 点击"添加语音"
   - 选择需要的语言

3. **下载语音组件**
   - 选择语言后点击"选项"
   - 勾选并下载"语音"组件
   - 等待下载完成

#### Windows 11

1. **打开设置**
   ```
   Win + I → 时间和语言 → 语言和区域
   ```

2. **添加语言**
   - 点击"添加语言"
   - 搜索语言（如"中文（简体，中国）"）
   - 勾选"语音"选项
   - 点击安装

3. **等待安装**
   - 系统自动下载并安装语音包

### 方法二：通过讲述人

1. **快捷键启动**
   ```
   Win + Ctrl + N
   ```

2. **添加语音**
   - 在讲述人设置中
   - 点击"添加传统语音"
   - 跳转到语音设置页面
   - 按照方法一继续

---

## ✅ 验证安装

### 方法一：通过系统设置

1. **打开控制面板**
   ```
   控制面板 → 语音识别 → 文本到语音转换
   ```

2. **查看语音选择**
   - 下拉菜单显示已安装的语音
   - 选择语音后点击"预览语音"测试

### 方法二：通过 PowerShell

```powershell
# 列出所有已安装的语音
Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.GetInstalledVoices() | ForEach-Object {
    $_.VoiceInfo | Select-Object Name, Culture, Gender
}
```

### 方法三：通过 Aboutme 应用

1. **运行应用**
   ```bash
   flutter run -d windows
   ```

2. **查看日志**
   - 应用启动时会输出：
   ```
   [INFO] Windows 可用语音数量: X
   [INFO] 语音 0: name=Microsoft Huihui, locale=zh-CN, gender=Female
   [INFO] 语音 1: name=Microsoft Zira, locale=en-US, gender=Female
   ```

3. **在应用中测试**
   - 打开 TTS 插件
   - 创建/编辑服务
   - 查看语音下拉列表

---

## ⚙️ 应用配置

### 创建 Windows TTS 服务

1. **打开 TTS 插件**
   - 在 Aboutme 主界面点击"语音朗读"插件

2. **添加新服务**
   - 点击右下角 ➕ 按钮
   - 或点击"添加服务"

3. **配置参数**
   ```
   服务名称: Windows 中文语音
   服务类型: 系统TTS ✓
   启用: ✓
   默认服务: ✓

   朗读参数:
   - 音调: 1.0
   - 语速: 1.0
   - 音量: 1.0
   - 语音: Microsoft Huihui (从列表选择)
   ```

4. **测试语音**
   - 保存后点击菜单中的"测试"
   - 应该能听到"你好，这是语音测试"

### 配置多个语音

你可以创建多个服务配置不同的语音：

```
服务 1: Windows 中文女声 (Huihui)
服务 2: Windows 英文女声 (Zira)
服务 3: Windows 中文男声 (Kangkang)
```

---

## 🐛 常见问题

### Q1: 没有检测到可用语音

**症状:**
```
[WARNING] Windows 未检测到可用语音，请安装 Windows 语音包
```

**解决方案:**
1. 按照[安装语音包](#安装语音包)重新安装
2. 重启应用
3. 如果仍然不行，重启系统

### Q2: 语音列表为空

**可能原因:**
- 语音包未完全下载
- Windows 服务未启动

**解决方案:**
1. 检查语音包安装状态
   ```
   设置 → 时间和语言 → 语言 → 检查更新
   ```

2. 重启 Windows Speech Runtime 服务
   ```powershell
   # 以管理员身份运行 PowerShell
   Restart-Service -Name "WSearch"
   ```

### Q3: 朗读没有声音

**排查步骤:**

1. **检查系统音量**
   - 确保系统音量未静音
   - 调整音量到 50% 以上

2. **检查应用配置**
   - 音量参数是否为 0
   - 服务是否启用

3. **测试系统 TTS**
   ```
   控制面板 → 语音识别 → 文本到语音转换 → 预览语音
   ```

4. **查看应用日志**
   ```
   [INFO] 朗读请求已发送
   [INFO] 开始朗读
   [INFO] 朗读完成
   ```

### Q4: 语音听起来很奇怪

**可能原因:**
- 音调或语速设置不当
- 使用了不匹配的语音（如中文文本用英文语音）

**解决方案:**
1. 重置参数为默认值
   - 音调: 1.0
   - 语速: 1.0
   - 音量: 1.0

2. 选择匹配的语音
   - 中文文本 → 中文语音
   - 英文文本 → 英文语音

### Q5: 切换语音无效

**原因:**
- Windows 平台需要使用 `setVoice` 而非 `setLanguage`

**已在代码中修复:**
```dart
if (Platform.isWindows) {
  await _flutterTts.setVoice({'name': voiceName, 'locale': locale});
}
```

---

## 📋 可用语音列表

### Windows 10/11 内置语音

#### 中文（简体）
| 语音名称 | ID | 性别 | 备注 |
|---------|-----|------|------|
| Microsoft Huihui | Microsoft Huihui Desktop | 女 | 默认中文语音 |
| Microsoft Kangkang | Microsoft Kangkang | 男 | 隐藏语音 |
| Microsoft Yaoyao | Microsoft Yaoyao | 女 | 隐藏语音 |

#### 英语（美国）
| 语音名称 | ID | 性别 | 备注 |
|---------|-----|------|------|
| Microsoft Zira | Microsoft Zira Desktop | 女 | 默认英文语音 |
| Microsoft David | Microsoft David Desktop | 男 | 需额外安装 |
| Microsoft Mark | Microsoft Mark | 男 | 需额外安装 |

#### 其他语言
- 日语：Microsoft Haruka
- 韩语：Microsoft Heami
- 法语：Microsoft Hortense
- 德语：Microsoft Hedda
- 西班牙语：Microsoft Helena

> 注意：部分语音需要安装对应的语言包

### 获取完整列表

在应用启动时查看日志：
```
[INFO] Windows 可用语音数量: 5
[INFO] 语音 0: name=Microsoft Huihui Desktop, locale=zh-CN, gender=Female
[INFO] 语音 1: name=Microsoft Zira Desktop, locale=en-US, gender=Female
...
```

---

## 🔬 高级配置

### 启用隐藏语音（康康、瑶瑶）

这些语音已安装但默认不显示，需要修改注册表：

1. **打开注册表编辑器**
   ```
   Win + R → regedit
   ```

2. **导航到语音路径**
   ```
   HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Speech\Voices\Tokens
   ```

3. **查找语音项**
   - 找到 `MS-CHS-Kangkang-11.0`
   - 找到 `MS-CHS-Yaoyao-11.0`

4. **创建属性**
   - 右键 → 新建 → 字符串值
   - 名称：`CLSID`
   - 值：`{D5A60F70-3E00-11D2-96CB-0060B0576642}`

5. **重启系统**

> ⚠️ 警告：修改注册表有风险，建议先备份

### 调整语音质量

某些语音支持质量设置：

```dart
// 在代码中添加（需要修改 flutter_tts 插件）
await flutterTts.setVoice({
  'name': 'Microsoft Huihui Desktop',
  'locale': 'zh-CN',
  'quality': 'high'  // low, medium, high
});
```

---

## 📚 参考资源

- [Microsoft Speech Platform](https://www.microsoft.com/en-us/download/details.aspx?id=27225)
- [Windows TTS API 文档](https://learn.microsoft.com/en-us/windows/apps/develop/speech)
- [flutter_tts 文档](https://pub.dev/packages/flutter_tts)
- [Aboutme 项目](https://github.com/hunmer/Aboutme)

---

## 🆘 需要帮助？

如果以上方法都无法解决问题：

1. **查看应用日志**
   - 运行应用时查看控制台输出
   - 查找 `[ERROR]` 或 `[WARNING]` 标记

2. **提交 Issue**
   - 前往 [GitHub Issues](https://github.com/hunmer/Aboutme/issues)
   - 提供详细的错误信息和日志

3. **社区讨论**
   - 在项目 Discussions 中发帖
   - 其他用户可能遇到相同问题

---

**最后更新**: 2025-01-19
**适用版本**: Aboutme 1.1.7+
