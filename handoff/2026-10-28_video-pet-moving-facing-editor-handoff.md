# 视频宠物 moving / facing 编辑器交接

> 日期：2026-10-28
> 工作区：`D:/about-me`
> 核对时 HEAD：`1399366b`；以接手时实际 Git 状态为准。
> 本次交付仅为文档，没有实现新的编辑器 UI，没有重新运行测试。
> 基础精灵图资源背景见 `handoff/2026-10-28_live2d-webp-spritesheet-handoff.md`；本文是后续移动配置与编辑器的增量交接。

## 1. 下一步目标

用户准备在 `lib/plugins/live2d/screens/video_pet_editor_screen.dart` 中增加 **逐动画的 moving 和原始朝向 facing 编辑器**。

运行时和模型已经支持这些字段；下一步主要是为它们提供可视化编辑、校验和保存入口，不需要重写播放器或精灵图转换流程。

用户明确要求：

- 每个动作可配置多段移动区间：`"moving": [[起始帧, 结束帧, 速度], ...]`。
- 速度是每动画帧的水平位移，不是动画播放速度，也不是像素/秒。
- 区间之间、开头和结尾可以只播放动画而不移动。
- 每个移动精灵图定义原始朝向，随机走路时按实际位移方向决定是否水平翻转。
- 具体区间和速度由用户填写，不要自动扫描、猜测或覆盖用户资源配置。

## 2. 当前数据结构：必须保持的语义

实现文件：`lib/plugins/live2d/video/video_pet_manifest.dart`。

### 2.1 每个动画的字段

`VideoPetAnimation`（约 255 行）已有：

```dart
final String facing;
final List<VideoPetLocomotion>? moving;
```

示例，仅展示新增字段，实际条目仍需合法的 sources / spritesheet：

```json
{
  "id": "自定义动作",
  "name": "自定义动作",
  "facing": "left",
  "moving": [[10, 30, 2.5], [50, 90, 4.0]]
}
```

`facing`：

- `"left"`：原图主要运动朝左；向右移动时翻转。
- `"right"`：原图主要运动朝右；向左移动时翻转。
- `""` 或字段缺省：未设置，保留旧镜像兼容规则。清除朝向应写 `copyWith(facing: '')`，`null` 表示保留原值。
- 不支持 `front` / `none` 等额外字符串；除非明确扩展模型，否则 UI 不要输出这些值。

`moving` 每段的 Dart 类型仍叫 `VideoPetLocomotion`，不是一个新的嵌套 JSON 对象：

```dart
const VideoPetLocomotion({
  required int startFrame,
  required int endFrame,
  required double speed,
});
```

帧区间与速度：

- 帧号从 **0** 开始，包含起止帧。
- `0 <= startFrame <= endFrame < animation.spritesheet!.frameCount`。
- 区间必须按起始帧升序排列，且下一段 `startFrame > 前一段 endFrame`，不能重叠。
- `speed` 为有限正数，单位：**逻辑像素 / 动画帧**。
- `speed == 0` 不合法；停步使用区间间隙或空数组表达。
- 必须具有 spritesheet 才能配置 moving。
- 不修改 `spritesheet.fps`。例如 12 fps、每帧 2.5 像素，连续有效区间的位移约为 30 逻辑像素/秒，但存储值仍为每帧 2.5。

### 2.2 三种配置状态不能混淆

| 配置 | 运行时行为 | 编辑器应如何表达 |
| --- | --- | --- |
| `moving == null`，JSON 缺省 | 兼容原连续移动，使用全局 `manifest.movement.speed`，单位像素/秒 | 使用默认连续移动 |
| `moving == []` | 动画全程不产生位移 | 启用分段但没有移动区间 / 全程不位移 |
| `moving` 含区间 | 仅命中区间时按该段 speed 移动 | 分段移动 |

不要将“删除所有区间”自动当成清除字段；应给用户明确的“恢复默认连续移动”操作。

### 2.3 解析、序列化、兼容

- `VideoPetAnimation.fromJson`（约 285 行）：解析 `moving` 为三元数组，每项长度必须恰好 3；起止帧必须是整数，速度是数字。
- 旧 `locomotion: {startFrame, endFrame, speed}` 仍有 **JSON 读取兼容**，转换为单段 moving。
- 输出仅写 `moving`，不要重新生成旧 `locomotion`。
- `moving` 数组显式存在时优先于旧对象，包括空数组。
- 当前解析在 `moving == null` 时仍会尝试旧 `locomotion`；若两字段同时存在，想完全清除移动配置应移除旧字段，而不是只写 JSON null。
- `copyWith(moving: null)` 清除配置；省略参数保留；`copyWith(moving: [])` 表示明确不位移。
- `toJson()` 在 moving 非 null 时输出数组。
- `VideoPetAnimation.validate()` 负责帧上限、排序、重叠、速度、facing 等完整校验；`fromJson` 单动画不等同于完整 validate。

## 3. 编辑器现状与接入位置

文件：`lib/plugins/live2d/screens/video_pet_editor_screen.dart`。

关键位置（行号会随修改变化）：

| 入口 | 当前职责 |
| --- | --- |
| `_VideoPetEditorScreenState`，约 34 行 | `_draft`、选中动作、预览、表单状态 |
| `initState`，约 56 行 | `toJson/fromJson` 深拷贝传入 manifest，取消编辑不影响原值 |
| `_selectedAnimationId`，约 41 行 | 当前点播选中的动画 ID，初始可能为 null |
| `_setDraft`，约 81 行 | setState 替换整份 manifest 草稿 |
| `_save`，约 85 行 | `_draft.validate()` 后 `Navigator.pop(_draft)` |
| `_requestAnimation`，约 100 行 | 选择动作并通过 ValueNotifier 点播，重复选择会重新播放 |
| `_importJson` / JSON 对话框，约 357 行起 | 导入导出整个 manifest，保持当前资源基址 |
| `_buildPreview` 内的 `VideoPetPlayer`，约 552 行 | 精灵图预览，暂停、点播、区域编辑；目前未接 onAnimationFrame |
| 动画横向列表，约 730～833 行 | 搜索 / 分类 / 选择动作，onTap 调 `_requestAnimation` |
| `_buildMovementEditor`，约 835 行 | 全局左右行走、左右转向、拖拽动画绑定和等待时间 / 全局速度 |
| `_buildBindingPanel`，约 941 行 | 桌面右侧与窄屏面板共用；无选中区域时也必须显示动画配置 |

**重要区分**：

- `_draft.movement` 是整套宠物的行为配置。
- `_draft.animations[index].moving / facing` 是单个动作的资源配置。
- 不要把多段编辑结果存到 `_draft.movement`，也不要让选中的交互区域决定是否能编辑动画。

### 推荐最小实现

1. 为 `_selectedAnimationId` 对应的动画增加独立编辑区；初始无选择时提示选择动作，或明确选择当前 idle，不要隐式修改别的动作。
2. 朝向下拉：未设置 / 向左 / 向右，分别对应 `'' / 'left' / 'right'`。
3. 分段配置支持默认连续、明确不位移、分段三个语义。
4. 每段一行：起始帧（整数）、结束帧（整数）、移动速度（像素/动画帧）、删除；支持新增段。
5. 显示所选动作的 `frameCount`、合法范围 `0..frameCount-1` 和 fps，降低帧号误填概率。
6. 对完整有效值执行单动画 `copyWith`，再替换 `_draft.animations` 对应项：

```dart
_setDraft(_draft.copyWith(
  animations: [
    for (final item in _draft.animations)
      item.id == selected.id
          ? item.copyWith(facing: facing, moving: segments)
          : item,
  ],
));
```

7. 最终保存继续走已有 `_save`，不要绕过 manifest 校验。

表单实现注意：

- 切换动作时不能复用上个动作的 TextEditingController 或 `initialValue` 状态；为动作和区间提供稳定 key，管理并释放 controller。
- 用户正在输入空字符串、负号、小数等中间状态时，不要立即让整份 `_draft` 变成非法 manifest；播放器会在草稿变化时重新 prepare。
- 建议局部保留输入草稿，校验通过后再提交动作对象；错误贴近对应输入框显示。
- 不要静默截断小数帧号、静默调小结束帧、覆盖重叠区间或随意改速度。可提供明确“按起始帧排序”操作，最终仍校验不重叠。
- 不要新增依赖，不做精灵图重新编码。
- 缺少 spritesheet 的动作可以编辑朝向，但分段 UI 应禁用并说明原因。

## 4. 预览与运行时链路

### 4.1 当前编辑器预览的能力边界

当前编辑器直接使用 `VideoPetPlayer`，不包含移动舞台，因此：

- 能完整播放精灵图和暂停。
- 手动点播不是随机行走，不会天然根据 facing 做左右行走镜像。
- 修改 moving 后，不会自动在预览中产生水平位移。
- 当前没有公开的 seek / 单帧跳转控制器。若希望增加帧滑块或逐帧按钮，需要额外设计播放器接口；这是后续可选能力，不要假设现成可用。

可先实现配置编辑和保存，之后通过主页随机行走验收。若增加即时预览，明确“向左 / 向右试走”的方向，复用现有行为，避免产生第二套不同的帧计数逻辑。

### 4.2 实际移动

`lib/screens/jelly_home/widgets/jelly_video_pet_movement.dart`：

- `JellyVideoPetStage.animations` 接收完整动画列表。
- `_moving`（约 107 行）按当前移动动画 ID 找到 `moving`。
- `_animationFrame`（约 116 行）只接受当前阶段、当前行走动画的帧事件；逐段查找，命中后 `_move(segment.speed)`。
- `moving == null` 时走原 ticker 连续位移，使用全局 movement.speed（像素/秒）。
- `moving == []` 时不启动连续 ticker，也没有命中区间，因此不位移。
- `_flipX`（约 140 行）对比当前动作 facing 与位移方向决定镜像；未知朝向兼容旧逻辑。忙碌或拖拽时不继承行走镜像。
- 全宽画布采用中心约束，允许部分画布超出边缘；不能恢复成 `parentWidth-petWidth==0` 的横向锁定。
- 默认空闲等待约 10 秒；点击 / 拖拽结束后重新计时。
- 鼠标 hover 已不再触发动画或阻塞走路，不要恢复此行为。

`lib/plugins/live2d/video/video_pet_player.dart`：

- `onAnimationFrame` 为 `ValueChanged<VideoPetAnimationFrame>?`。
- `VideoPetAnimationFrame` 定义在 `video_pet_player_state.dart`：animationId / currentFrame / generation。
- `_SpriteSurface` 使用 `SpriteAnimation.grid(onFrame: ...)`，捕获 controller 实际 currentFrame，post-frame 交付；跳帧、循环逐步事件仍计数。
- 初始显示 / 加载等待 / 暂停 / 切换时不凭墙钟时间虚增位移；过期 generation / phase 回调被过滤。
- 不要把帧回调放进 build 里同步 setState，也不要用新的 Timer 猜测帧号。

## 5. 导入、保存和默认资源保护

### 档案保存链路

`lib/plugins/live2d/screens/live2d_archive_form_screen.dart` 约 113 行：先 `prepareForPlayback`，再打开 `VideoPetEditorScreen`；用户保存编辑器后回传 manifest，再由档案表单最终保存。取消编辑器不写回原档案。

`VideoPetAnimation.toJson/fromJson/copyWith` 已支持新字段；导入 / ZIP / 档案使用整份 manifest 序列化，不需要新建旁路存储。

### 内置资源刷新

`lib/plugins/live2d/video/video_pet_import.dart` 约 85 行：

- 内置默认资源会刷新 sources / spritesheet。
- facing 仅在旧值为空时从默认值补齐，不覆盖用户显式朝向。
- moving 通过 animation.copyWith 保留，不应用默认配置把用户区间覆盖。
- 编辑器显式清空 facing 后，若再次经过内置 prepare，可能被默认 facing 补回；如果未来要支持“明确不设置且永不补齐”，需专门讨论数据语义，本次没有三态 facing。

### 当前工作区真实资源值

本次核对 `git status --short` 只有 `assets/live2d/video/dsh_pet/manifest.json` 为修改状态。用户近期手工调整过内容，必须以接手时文件为准。

核对时可见：

- `原地左转奔跑`：`facing: "left"`，`moving: [[18, 56, 2.5]]`。
- `螃蟹走路`：`facing: "left"`，`moving: [[14, 96, 1.5]]`。
- 其他动作是否设置 facing / moving，应读当前文件，不要按历史对话恢复。

**不能覆盖为历史示例 `[[12,100,2.5]]`，不能删除用户填写的区间，也不要擅自给“原地漂浮踏步”补回历史朝向。**

这两个用户值只是当前快照，不是要求其他资源照抄。所有区间和速度由用户自己决定。

## 6. 验证现状与建议

前序会话曾报告多段实现模型 / 舞台 42 项通过，之后主线程又跑过导入 / 朝向 / 档案 / 播放器 18 项通过。**这些是历史执行结果，不代表本次重新验收。**

本次只读核对发现：当前 `test/video_pet_manifest_test.dart` 和 stage 测试中没有检索到 moving / locomotion 专项字段断言，不能仅凭历史数量认为多段配置已得到当前仓库充分覆盖。下一轮应补充并实际运行。

现有可复用测试：

- `test/video_pet_editor_movement_test.dart`：无区域时仍能编辑全局动作绑定并保存；目前 fixture 使用旧视频源以避免真实图片加载，预览有转换提示，但这是配置保存测试，不是显示验收。
- `test/video_pet_manifest_test.dart`：manifest / JSON / ZIP / 资源导入基础。
- `test/video_pet_facing_test.dart`：朝向 roundtrip、非法值、内置补齐和自定义保留。
- `test/screens/jelly_home/jelly_video_pet_movement_test.dart`：方向镜像、10 秒调度、busy / 拖拽恢复、全宽边界等。
- `test/video_pet_player_widget_test.dart`：真实帧事件、跳帧 / loop / 暂停，以及播放器交互。
- `test/video_pet_import_movement_test.dart`、`test/video_pet_archive_test.dart`：迁移与保存回归。

编辑器应补的测试：

1. 无交互区域也能选择动画并编辑 facing / moving。
2. 从一个动画切到另一个，表单值独立，回切保留草稿。
3. 新增两段不同速度；保存后逐段值和顺序正确，JSON 导出仍为三元数组。
4. 段间暂停语义、空数组与 null 三态不混淆。
5. 帧号越界、非整数、重叠、逆序、零 / 负 / 非有限速度阻止保存并反馈。
6. 清除配置、取消编辑不修改原 manifest；已有资源与交互区域 / 点击 / 拖拽绑定不丢失。
7. 旧 locomotion 导入转换为 moving，最终导出不再写旧字段。
8. 如增加运行预览，测试区间内按每帧位移、区间外停、loop 再进入有效段、方向翻转和暂停恢复。

建议命令（只运行与本轮改动相关范围，不必重跑全部 106 个大纹理解码测试）：

```powershell
& "D:/flutter/bin/flutter.bat" test --no-pub --reporter expanded `
  "test/video_pet_editor_movement_test.dart" `
  "test/video_pet_manifest_test.dart" `
  "test/video_pet_facing_test.dart" `
  "test/screens/jelly_home/jelly_video_pet_movement_test.dart"

& "D:/flutter/bin/flutter.bat" analyze --no-pub `
  "lib/plugins/live2d/screens/video_pet_editor_screen.dart" `
  "lib/plugins/live2d/video/video_pet_manifest.dart" `
  "test/video_pet_editor_movement_test.dart"
```

按实际新增测试路径调整；测试中不要对循环精灵图盲目 `pumpAndSettle`，避免无限等待。小图 / data URI fixture 可参考 player widget test。

## 7. 协作约束

- 简体中文输出；最小改动，不增加无关架构。
- Windows 使用 PowerShell 7：`D:/tmp/pwsh-7.4.13/pwsh.exe`；Flutter：`D:/flutter/bin/flutter.bat`；Dart：`D:/flutter/bin/dart.bat`。
- 路径使用双引号，优先 `/`。Git Bash 包裹 PowerShell 时用单引号保护 `-Command` 内容。
- 用户未要求真实浏览器，不默认使用；本功能可先用 Flutter widget tests。
- 不恢复 WebM 视频回退，不重新编码 WebP，不动帧率和网格资源。
- 不因历史测试或历史资源值覆盖用户现在的 manifest。
- 不提交或推送，除非用户另行授权。
