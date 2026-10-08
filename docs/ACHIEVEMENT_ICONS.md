# 成就图标资产说明

> 位置：`assets/achievements/`（A01.webp ~ A74.webp，透明 WebP，已在 `pubspec.yaml` 声明）
> 成就定义（名称/条件/等级）：[ACHIEVEMENT_SYSTEM_PLAN.md](./ACHIEVEMENT_SYSTEM_PLAN.md)
> 源文件与管线脚本：`docs/achievement_icons/`（本目录不参与打包）

## 1. 现状

- 74 个成就系列 ↔ 74 枚图标，文件名即编号：`A01.webp = 千言万语`、`A74.webp = 深度玩家`，编号 ↔ 名称对照见总计划文档的一~五节表格。
- 同一成就的 Lv1~Lv5 共用一张主体图，等级用边框色区分（灰铁/青铜/白银/黄金/彩虹流光），未来可在展示层加边框贴图，不必重绘主体。
- 生成参数（已验证）：`gpt-image-2.5-flare`、2048x2048、`background=transparent`、PNG、quality=medium。
  - 注意：本代理没有 `gpt-image-2`；`gpt-image-2.5-sunburst` 后端不稳定（经常忽略透明参数），优先用 flare。
  - `images/edits` 端点会忽略透明参数，必须用 `images/generations`。

## 2. 如何新增图标（新成就系列）

1. 在 `docs/ACHIEVEMENT_SYSTEM_PLAN.md` 中确定新编号（下一个可用 AnN）与图标描述。
2. 打开 `docs/achievement_icons/gen_transparent.py`：
   - `NAMES` 加 `"A75": "名称"`（切分后文件命名用）；
   - `SUBJECTS` 加新 sheet 条目（布局 + 每枚主体的英文描述），提示词模板直接复用文件顶部的 `STYLE`。
3. 生成九宫格图（脚本 `python gen_transparent.py --sheet sheet_10`，或用上面的参数手动生图后存为 `docs/achievement_icons/sheet_10.png`）。
4. 运行 `python docs/achievement_icons/split_icons.py`：自动切分到 `docs/achievement_icons/icons/` 并导出 WebP 到 `assets/achievements/`。只重导出可加 `--export-only`。
5. Flutter 侧新资产目录/文件生效需冷重启（热重载不含 asset 变更）。

### 单枚替换 / 切换图标（换图不改代码）

- 用新图（透明 PNG）直接覆盖 `assets/achievements/Axx.webp`（保持文件名不变即可，无需改 pubspec；webp/PNG 同名互换也可，Flutter 按路径解析，但建议统一 webp）。
- 源 PNG 需要转格式时：`python docs/achievement_icons/split_icons.py --export-only` 会把 `docs/achievement_icons/icons/Axx_中文名.png` 重新导出为 `Axx.webp`。
- 若某枚生成效果不满意，只重生成该枚所在 sheet 后重跑切分脚本即可；切分是幂等的。

## 3. 切分管线原理（排障用）

`split_icons.py` 对每格：从格中心在 alpha>128 区域泛洪取徽章主体（自动剔除悬浮的白色斑点毛边）→ 按主体包围盒裁切 → 原生 alpha 原样保留（无几何蒙版，不切角）。搜索窗口为单元格四周外扩 25%，因此徽章略越过九宫格分割线也不会被削边。

已知边界情况：若同一张 sheet 内徽章互相接触/重叠（泛洪会连通），切分会带入相邻徽章碎片；生成时提示词需含 "badges must never touch or overlap"。

## 4. 待办：成就系统接入

- [ ] 新建 `achievement/` 插件（按 `lib/plugins/claude/conventions.md`）：成就定义 JSON（编号、名称、条件、等级数组、`icon: 'assets/achievements/Axx.webp'`）+ 进度存储 + `achievement_level_up` 事件 + 主页小组件。
- [ ] 信号接入：复用 `EventManager` 既有事件（见 `lib/plugins/store/events/point_award_event.dart:18` 的 9 类订阅）+ 各插件 JS API 结算计数。
- [ ] 积分发放：升级时调 `store.controller.addPoints(points, '成就:XXX LvN')`，数值进 `pointAwardSettings`。
- [ ] 等级边框：准备 5 张等级框贴图（灰铁/青铜/白银/黄金/彩虹流光），展示层与主体图叠加。
- [ ] 补埋点（8 处，清单见总计划文档【】标注项）：字数统计、Quill 编辑计数、倒计时触发、提醒处理状态、TTS 通道、webview 页数/标签数、插件使用覆盖面。
