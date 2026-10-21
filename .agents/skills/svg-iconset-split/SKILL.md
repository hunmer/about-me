---
name: svg-iconset-split
description: 将设计工具导出的图标集 SVG（多个图标叠放/网格分布在同一画布、常带 SMIL 动画，常配套 Lottie/bodymovin JSON）拆分为多个独立可用的 SVG 文件。Use whenever the user asks to 拆分/提取/导出 SVG 图标集、split an icon set SVG、把 xxx.svg 拆成多个 svg、从 icon set 提取单个图标，或提供了图标集 SVG + Lottie JSON 要求按图标分开保存（如做 Flutter/网页 loading 图标资源）。
---

# SVG 图标集拆分

把一个"多个图标挤在同一画布"的集合 SVG 拆成每个图标一个独立 SVG，保留动画。

## 先探测结构（勿跳过）

集合 SVG 通常 >256KB 无法直接 Read，用 python + ElementTree 分析：

1. 顶层 `<defs>` 内应有 `clipPath`（其 rect 尺寸 = 单个图标的设计尺寸，如 120x120）和若干图形定义 `<g id=..>`。
2. `<defs>` 之后是若干顶层 `<g transform="matrix(scale,..)">` 实例，每个实例内部第一层 `<g transform="translate(dx,dy)">` 是**网格残留偏移**（导出时把图标摆到画布各处留下的），其下才是带 `clip-path` 的实际图形。
3. 存在干扰项：全画布背景矩形组（rect 尺寸 ≥ viewBox 的 95%）和空 `<g>`，都要排除。

结构不匹配（如真正九宫格独立坐标、或每个图标本来就是独立 `<svg>`）时，改为按实际情况手动分析，勿硬套。

## 若有配套 Lottie JSON（权威源）

设计工具常同时导出 bodymovin JSON，它是校验与命名的依据：

- `assets[]` 每项 = 一个图标子合成，`nm` 为图标名（如 Icon_01）。
- 图标在主合成 `layers[].ks.p` 是网格位置；SVG 实例内的残留偏移 ≈ 网格位置 − 基准点。
- 用图层填充色（`shapes[].it[].c`，0-1 浮点转 hex）与 SVG 实例的 `fill` 匹配，确认一一对应。

## 拆分（用沉淀脚本）

优先运行本 skill 的脚本，不要每次重写：

```bash
python "<skill目录>/scripts/split_iconset.py" "源.svg" "<输出目录>" [--json "配套.json"] [--prefix loading_]
```

脚本自动完成：探测结构 → 排除背景/空组 → 删除网格残留偏移 → 以 clipPath 尺寸为 viewBox 重组独立 SVG → 按 Lottie 名/主题色命名。结构不匹配时会报错退出，此时回退手动分析。

手动拆分时的要点：

- 删除实例内层第一个 `<g>` 的 `transform`（网格残留），其余 transform 是图形自身设计偏移（如 `translate(50,50)`、`matrix(0.16,...)`），**必须保留**。
- 新文件 = `<svg viewBox=内容包围盒>` + 实例内部内容（含 `<animate>`）。**默认移除 `clip-path` 引用并按内容实际包围盒（椭圆并集 ∪ clip 框）扩大 viewBox**——背景大圆常超出设计框几像素，保留裁剪会让图标四周被吞掉一圈（用户的常见反馈）；`--clip` 可保留原始裁剪，`--pad N` 可加留白。
- 解析前必须 `ET.register_namespace('', 'http://www.w3.org/2000/svg')`，否则输出带 ns0: 前缀。

## 验证

1. 每个输出文件 XML 可解析、`<animate>` 数量与源中该图标一致（动画未丢）。
2. 抽查 transform：圆心类元素应位于设计中心（如 60,60）；仅允许存在与 Lottie 源一致的小幅设计偏移。若出现 ±60/±100 量级的平移，说明网格残留没删干净。
3. 让用户在浏览器打开抽查：图形居中、无偏移裁切、动画播放。

## 输出位置约定

用户说"保存到 aboutme/loading"之类时，aboutme 指 D:\about-me 项目本身，默认放 `assets/loading/`（Flutter 资源目录）。pubspec.yaml 是逐文件声明，若用户要在 Flutter 中使用需提示添加 `- assets/loading/`。
