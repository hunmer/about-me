# Live2D 插件 WebP 精灵图模式交接文档

> 日期：2026-10-28 ｜ 状态：功能和资源已完成，157 项定向测试通过，未完成五平台真机验收，未 commit/push。
> 工作区：`D:/about-me` ｜ 分支：`main` ｜ 当前 HEAD：`944e84eb`。

## 一、最新需求与最终状态

用户最初要求在 Live2D 插件中增加视频模式：用 JSON 加载整套资源，编辑全局和多个自定义区域的悬浮、点击动画，支持多动作随机或顺序播放，目标平台为 Windows、Android、Web、iOS、macOS。

随后用户认为 WebView 和不同平台两套视频资源成本过高，明确要求改为精灵图：

1. 每个视频动作独立一张精灵图，不能将全部动作放在一张图里。
2. 取消视频播放及视频回退，所有入口统一使用精灵图。
3. 本地仅保留 WebM 转换源，加入 Git 忽略；MOV 删除，视频不进入 Flutter assets。
4. 192×108 过于模糊，改为保留源尺寸 640×360。
5. 改用有损 WebP，每张精灵图严格小于 1 MB。
6. 最后要求恢复原来的帧数：已恢复 12 fps，常规动作 120 帧，短动作 59 帧。

**最终运行资源是 106 张静态、有损、透明 WebP 精灵图，每个动作一张；不是动画 WebP，也不是视频回退。** 临时采用过的 PNG、6 fps 方案已被最终规格取代。

## 二、默认资源规格及实测数据

资源目录：`assets/live2d/video/dsh_pet/`。

| 项目 | 最终值 |
| --- | --- |
| 动作数 | 106 |
| 单帧尺寸 | 640×360，全部源视频均为该尺寸 |
| 帧率 | 12 fps |
| 常规动作 | 105 个，每个实际 120 帧，8 列×15 行 |
| 短动作 | `工作状态-垂头叹气冒汗`，实际 59 帧，8 列×8 行 |
| 常规纹理 | 5120×5400 |
| 短动作纹理 | 5120×2880，末尾空格透明且不播放 |
| WebP 总字节数 | 105,230,520 字节，100.356 MiB |
| 单张最小／最大 | 980,176／999,578 字节 |
| 大小限制 | 严格 `< 1,000,000` 字节，不是 1 MiB |
| RGB 编码质量范围 | 11–87，按动作分别搜索 |
| Alpha 质量分布 | 50：47 张；25：28 张；10：17 张；1：14 张 |
| 最大 RGBA 像素数据 | 110,592,000 字节，105.469 MiB／张 |
| 本地 WebM | 106 个，54,351,332 字节，Git 忽略且不打包 |
| 旧 PNG／MOV | 默认包中均已清理 |
| 校验清单 | 318 项：106 WebM＋106 WebP＋106 动作 JSON，全部核验通过 |

用户曾表示 WebP 在 100 KB 以下；实际本轮生成结果约 0.98–1.00 MB／张，不应在后续沿用“100 KB 以下”的说法。

示例 manifest 动作：

```json
{
  "id": "东张西望",
  "name": "东张西望",
  "sources": {"webp": "spritesheet/东张西望.webp"},
  "spritesheet": {
    "frameWidth": 640,
    "frameHeight": 360,
    "columns": 8,
    "rows": 15,
    "frameCount": 120,
    "fps": 12
  }
}
```

动作同名 JSON 保留 PascalCase 元数据，包含来源、实际帧数、源时长、帧率、网格和纹理尺寸，以及 `ImageFormat`、`Lossless`、`EncodingQuality`、`AlphaQuality`、`Encoder`、`EncodedBytes`、`MaxImageBytes`、许可说明。

## 三、代码入口与职责

### 模型、导入、播放器

- `lib/plugins/live2d/video/video_pet_manifest.dart`
  - `VideoPetManifest` 保持 schemaVersion=1、逻辑画布和原有交互配置。
  - `VideoPetAnimation.imageFormat`、`imageSource` 统一访问 WebP／PNG。
  - 精灵图动作必须恰好一种图片 source，且同时有 spritesheet；检查扩展名或 data URI MIME。
  - 仍允许解析旧 WebM／MOV manifest，以便迁移；运行时不会播放视频。
  - `VideoPetSpritesheet` 包含帧尺寸、行列、有效帧数、fps，具备校验和值相等。
- `lib/plugins/live2d/video/video_pet_import.dart`
  - `loadDefault()` 读取默认 manifest。
  - `prepareForPlayback()`：默认内置 dsh-pet 档案按动作 ID 刷新最新图片来源及完整网格参数，保留自定义动作名称、分类、区域和绑定。
  - **只对默认 assets 引用刷新；独立导入、文件目录或带持久化图片映射的 PNG 副本继续用自己的参数。** 旧内置视频档案则迁移到默认 WebP。
  - JSON／ZIP 支持 WebP 和 PNG，正确保留扩展名与 MIME；原生复制到应用支持目录，Web 通过 data URI 映射持久化。
  - ZIP 路径安全、Unicode Path／GBK 中文文件名恢复仍保留。
  - `VideoPetPackage.resolveSource()` 的映射 key 为 `Uri.resolve(...).toString()` 后的完整 URI，中文 key 需 URI 编码，不能直接手写未编码路径。
- `video_pet_import_io.dart`／`video_pet_import_stub.dart`：平台文件读取和持久化。
- `lib/plugins/live2d/video/video_pet_player.dart`
  - 所有入口共用 `VideoPetPlayer`，使用 `MemoryImage` 和 `SpriteAnimation.grid`。
  - 图片来源支持 assets、file、HTTP(S)、data 等现有路径。
  - `precacheImage` 确认解码，epoch 防止异步旧加载覆盖新动作；切换／后台释放旧图片缓存。
  - Flutter `MouseRegion`／`Listener`／`GestureDetector` 承担悬浮、点击、编辑拖动、右键。
  - 缺图只提示错误，不启动视频、WebView 或本地 HTTP 服务。
  - 外部动画控制器用 `autoPlay:false`，首帧后启动；销毁前先 pause；Surface key 包含图片和 generation。
- `lib/plugins/live2d/video/video_pet_player_state.dart`
  - 播放优先级：manual／click > hover > idle。
  - 单次动作结束恢复当前悬浮或待机；generation 防旧结束回调串播。
  - 暂停恢复保留帧和 generation。
  - `videoPetContainPoint` 将编辑／交互坐标映射到实际画面，排除 contain 留白。

### 编辑器、档案和展示入口

- `lib/plugins/live2d/screens/video_pet_editor_screen.dart`：唯一精灵图预览，区域框选／拖动／缩放、优先级、随机／顺序、多动作绑定、测试模式。
- `lib/plugins/live2d/screens/live2d_archive_form_screen.dart`：模式选择、导入、编辑前准备资源，保存 manifest／baseUri／resolvedSources；取消编辑不写回草稿。
- `lib/plugins/live2d/models/live2d_archive.dart`：档案完整持久化 manifest、baseUri、resolvedSources。
- `lib/screens/jelly_home/widgets/jelly_live2d.dart` 及 loader／models／online_models：主页展示共用 `VideoPetPlayer`；设置页经同一组件展示。
- 界面名为“精灵图”，内部 `displayMode='video'`、`videoManifest`、`videoBaseUri`、`videoResolvedSources` 等旧字段名保留，以兼容已有数据。

### 依赖和打包

- `pubspec.yaml`／`pubspec.lock` 已加入 `flutter_spritesheet_animation: ^1.2.0`，lock 为 1.2.0。
- Flutter assets 显式声明默认 manifest、NOTICE／SOURCE／LICENSE 和 `spritesheet/`；不声明 WebM／MOV 目录。
- `.gitignore`：`/assets/live2d/video/dsh_pet/webm/`。
- 不删除项目其他功能仍需的 WebView／video 依赖。
- 旧功能专用 `video_pet_surface*`、`video_pet_resource_server*`、`video_pet_spritesheet_preview.dart` 已删除，无视频回退。

## 四、转换脚本及重生成

脚本：`scripts/convert_video_pet_spritesheet.ps1`，要求 **PowerShell 7**。

当前可用工具：

```text
PowerShell 7: D:/tmp/pwsh-7.4.13/pwsh.exe
FFmpeg:       E:/ffmpeg/ffmpeg.exe
ffprobe:      E:/ffmpeg/ffprobe.exe
cwebp:        D:/tmp/webp-1.6.0/libwebp-1.6.0-windows-x64/bin/cwebp.exe
Flutter:      D:/flutter/bin/flutter.bat
Dart:         D:/flutter/bin/dart.bat
```

`cwebp` 来自官方 libwebp 1.6.0 Windows x64 下载包，存放在项目外临时目录；该路径和工具不会随仓库分发。新环境需准备 libwebp 并传 `-Cwebp`。PATH 没有 pwsh 时必须用上述完整路径。

```powershell
# 全部动作；默认 640×360、12 fps、8 列、每张 <1,000,000 字节
& "D:/tmp/pwsh-7.4.13/pwsh.exe" -NoProfile -File `
  "D:/about-me/scripts/convert_video_pet_spritesheet.ps1" -All

# 中断后复用参数和字节数一致的已生成动作
& "D:/tmp/pwsh-7.4.13/pwsh.exe" -NoProfile -File `
  "D:/about-me/scripts/convert_video_pet_spritesheet.ps1" -All -Resume

# 单动作或换工具路径
& "D:/tmp/pwsh-7.4.13/pwsh.exe" -NoProfile -File `
  "D:/about-me/scripts/convert_video_pet_spritesheet.ps1" `
  -Action "东张西望" -Cwebp "你的路径/cwebp.exe"
```

脚本流程：

1. 预检全部待处理 WebM 是否存在，ffprobe 获取源描述信息。
2. `libvpx-vp9` 显式解码保留 Alpha，通过 fps filter 输出到 null，从最终 progress 读取**实际帧数**；不用 duration×fps 估算。
3. 临时生成 RGBA PNG 网格，空格透明；临时 PNG 不作为最终资源打包。
4. 使用 `cwebp -m 4 -mt` 有损编码，逐张搜索整数 RGB 质量。先尝试 Alpha=50，必要时降至 25／10／1，为 RGB 细节腾出体积；所有接受的输出都核对实际字节数 `< MaxBytes`。
5. 保持帧尺寸、帧数及帧率，验证最终 WebP 尺寸和透明格式，写动作元数据。
6. 全量成功后更新 manifest 引用，清理被替代的生成 PNG，重算 WebM／WebP／JSON 校验和。

**不要恢复错误历史值**：早期“东张西望”按时长估算为 121 帧／13 行是旧错误；当前真实帧数为 120。测试中的人工 `_sheet` fixture 可仍为 192×108／121 帧，它不代表默认资源。

注意：最终这一轮转换开始后，脚本又做过不影响默认参数输出的整理（质量上限处理、metadata 中的 encoder／qualitySearch 描述）。当前资源 manifest 的 `metadata.conversion.qualitySearch` 仍是较早的 RGB 二分描述，未包含后补的 Alpha 说明；每动作 JSON 已记录实际 AlphaQuality／Encoder，资源本身正确。下次按当前脚本重跑会刷新包级描述，无需因此重新编码全部资源。

## 五、验证结果与复现

最终联合测试 **157 项全部通过**；定向 `flutter analyze` 显示 **No issues found**。

```powershell
& "D:/flutter/bin/flutter.bat" test --no-pub --reporter expanded `
  "test/video_pet_spritesheet_test.dart" `
  "test/video_pet_player_widget_test.dart" `
  "test/video_pet_manifest_test.dart" `
  "test/video_pet_archive_test.dart" `
  "test/video_pet_playback_test.dart" `
  "test/jelly_live2d_zip_import_test.dart" `
  "test/jelly_live2d_interaction_test.dart" `
  "test/jelly_live2d_crop_region_test.dart" `
  "test/jelly_live2d_layout_test.dart"

& "D:/flutter/bin/flutter.bat" analyze --no-pub `
  "lib/plugins/live2d/video" `
  "lib/plugins/live2d/screens/video_pet_editor_screen.dart" `
  "lib/plugins/live2d/screens/live2d_archive_form_screen.dart" `
  "test/video_pet_spritesheet_test.dart" `
  "test/video_pet_player_widget_test.dart" `
  "test/video_pet_manifest_test.dart" `
  "test/video_pet_archive_test.dart" `
  "test/video_pet_playback_test.dart"
```

覆盖：

- 106 个独立 WebP 的存在、实际解码、尺寸、4 通道、有效帧透明及可见像素、实际体积与动作 JSON 一致、12 fps／120或59帧、采样时长误差不超过一帧。
- Flutter 实际解码一张 5120×5400 全尺寸 WebP 成功；小图 Widget 测试覆盖 WebP 与 PNG 映射播放。
- JSON／ZIP WebP 和 PNG 导入、MIME、扩展名、原生持久化与再导入、Web data URI、中文文件名和路径安全。
- 旧默认档案升级保留交互，自定义／独立 PNG 副本不被覆盖。
- 动作优先级、完成恢复、暂停、contain 坐标及既有 Live2D 导入／交互／裁切／布局回归。
- 318 项 SHA-256 与字节数人工脚本校验全部通过；WebM `git check-ignore` 命中，PNG=0，MOV 已清理。

未使用真实浏览器，未进行五平台真机展示或性能验收。此前测试命令误用了 Flutter 不支持的 `--exclude-name`，没有执行测试；已修正并最终完整运行，上述 157 项结果为有效最终结果。

## 六、已知限制与后续接手重点

1. **压缩质量**：为同时满足 640×360、120 帧和单图 <1 MB，RGB 和半透明边缘均可能有损。多数动作 RGB 约 35–40；`放烟花` 为 11，复杂特效比普通动作损失明显。不要宣称像素无损或所有动作清晰度相同。
2. **纹理和内存**：常规单图 5120×5400，超过 4096。Flutter 测试解码成功不能代表所有 GPU／Web／移动设备可完整显示。单张 RGBA 约105.469 MiB，切换新旧动作可能短时双份，实际总内存更高；WebP 只减少压缩存储体积。
3. **兼容范围**：目标五平台共用 Flutter 精灵图路径，但 Android／iOS／macOS／Web／Windows 的实机性能仍未验收。若后续用户反馈错帧、白屏或卡顿，先检查真实纹理上限、图片尺寸、实际网格和内存，避免直接恢复视频回退。
4. **转换输入不随 Git 分发**：WebM 已被忽略；干净 checkout 能运行和测试已生成 WebP，但不能直接全量重生成，需恢复固定来源 WebM 和外部工具。`SourceVideoBytes` 在测试中仅作为元数据验证，不读取源视频。
5. **转换中断**：脚本逐动作输出图片和元数据，但最后才统一写 manifest；中断时可能暂时混合新旧资源。可用 `-All -Resume` 完成，再跑全量检查，不能将中途目录视为可发布状态。
6. **许可**：素材禁止商用，公开二创须署名 https://github.com/PC2005-cloud/dsh-pet 。保留并打包 NOTICE、SOURCE-upstream 和 LICENSE；上游代码 MIT 不覆盖素材限制。

## 七、最短手动验收

1. 完全停止并重新运行应用，让资源清单和 Dart 代码一同更新。
2. 打开已有精灵图档案及编辑器，点播“东张西望”，检查 12 fps 流畅度、透明边缘及是否正确裁帧。
3. 点播“工作状态-垂头叹气冒汗”检查短动作不播放空格；点播“放烟花”检查可接受的压缩观感。
4. 点击／悬浮不同区域，确认触发绑定动作并恢复待机；暂停恢复，快速切换动作，检查旧帧不返回。
5. 保存区域后重新打开确认保留；取消编辑确认不写回。测试已有独立 PNG 包与新 WebP ZIP 导入。
6. 在目标移动设备和 Web 上重点观察纹理兼容、切换时峰值内存及掉帧。

## 八、工作区和协作约束

- 当前未 commit/push；不要把交接文档理解成提交或推送授权。
- 工作区含用户并行的 day_card、date_view_grid、widgets_gallery 等多处无关修改；不能批量回退、格式化或提交所有改动。本功能相关文件也有大量未跟踪文件，后续提交需按范围逐项核对。
- 使用 PowerShell 7、UTF-8；在 Git Bash 包裹 PowerShell 命令时用单引号包住 `-Command` 内容，避免 `$变量` 被 Bash 提前展开。所有路径加双引号，优先 `/`。
- 用户没有要求真实浏览器测试时不使用；此轮全量资源和相关测试已经完成，不必为纯文档修改重复跑测试。
- 未改 `mira-app-core`，不涉及该包 build／server reinstall。

相关使用说明：`docs/video-pet-mode.md`；资源说明：`assets/live2d/video/dsh_pet/README.md`。
