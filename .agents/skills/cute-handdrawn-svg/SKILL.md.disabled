---
name: cute-handdrawn-svg
description: 生成韩系 INS 治愈手绘风的 SVG 图标集与画板 HTML（饮料/食物/服饰/家具等主题），沉淀自多版生成对照后的最优规范：暖棕勾线、马卡龙粉彩、签名爱心、无滤镜纯贝塞尔手绘感。Use when user asks to create/draw cute hand-drawn SVG icons, an icon board HTML, or store item cover assets in aboutme.
---

# 手绘治愈系 SVG 图标画板

对照两版生成结果（滤镜派 vs 干净线稿派）后沉淀的最优规范。核心结论：
**不要依赖 SVG 滤镜做手绘感**（feTurbulence 在 flutter_svg 等渲染器中不可用、栅格化效果不可控），
手绘感必须来自手工编写的微不对称贝塞尔；**每套图标要有一个统一的签名元素**（如中心小爱心 + sparkle），
用「物件 + 签名元素」替代遍地萌系表情，风格一致性远高于随机加脸。

## 1. 单枚图标规范

| 项 | 规则 |
| --- | --- |
| 结构 | 完整独立 `<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">`，主体居中、四周留白 ≥15 |
| 墨线 | 暖深棕 `#4A342E`，主体 `stroke-width="2.6"`，细节层 2.0–2.4；一律 `stroke-linecap="round" stroke-linejoin="round"` |
| 滤镜 | **禁止**任何 filter/feTurbulence；手绘感只靠路径本身 |
| 填色 | 马卡龙低饱和粉彩，单图标 = 1 主色 + 1–2 辅色 + 奶白高光；禁纯黑、禁高饱和 |
| 层次 | ≥6 层：主体轮廓 → 内部填充层 → 配件（盖/柄/吸管）→ 细节小件 → 签名元素 → 点缀 |
| 液面 | 液体表面用平滑波浪 `Q.. T..`（例：`M36 52 Q48 49 60 52 T83 52`），再补一条同形描边线 |
| 小件 | 冰块/棉花糖/标签等小矩形带 `transform="rotate(-8~10 x y)"` 微歪斜 |
| 管状件 | 吸管/壶柄/杯柄双层描边：墨线 7–8px 打底，同路径彩色 2.5–3.2px 芯 |
| 签名元素 | 每枚必有：中心小爱心（8 段贝塞尔，非对称）+ 1–2 颗四角 sparkle（`Q` 星形）；**不加表情**，除非用户明确要求（每套 ≤1/3 枚） |
| 数据字段 | `{ id, category, zh, en, desc, svg }` —— 中英双名 + 分类，画板筛选用 |

爱心模板（中心平移缩放复用）：
```html
<path d="M60 73 C57 68, 50 70, 52 76 C53.5 80, 58.5 83, 60 85 C61.5 83, 66.5 80, 68 76 C70 70, 63 68, 60 73 Z"
      fill="#F4A7B9" stroke="#4A342E" stroke-width="2.3" stroke-linejoin="round"/>
```
sparkle 模板：
```html
<path d="M92 30 Q96 30 96 26 Q96 30 100 30 Q96 30 96 34 Q96 30 92 30 Z" fill="#F4A7B9"/>
```

## 2. 色板

基础盘：墨 `#4A342E`｜粉 `#F4A7B9`｜淡粉 `#FAD2DC`｜奶油黄 `#FFF3D6`｜抹茶 `#C2D8A3`｜奶白纸 `#FFFDF9`。
按主题最多追加 4 个低饱和固有色（如橙 `#FFB884`、蜜 `#FCE3A6`、雾蓝 `#DFF2F6`、可可 `#8C5843`）。
换主题（服饰/数码/家具）时保留基础盘，只换追加色，保证系列间可混排。

## 3. 画板 HTML 结构

- Tailwind CDN + Google Fonts（`Fredoka`/`Quicksand`/`ZCOOL KuaiLe`）；body 米白 `#FAF4F0` + 24px 圆点纹理
- `poster-sheet` 主画板：白纸底、2px 暖边框、柔和投影（阴影允许，这是网页画板不是 app UI）
- 装饰页眉：SVG 手写标题 + 双侧爱心/sparkle（`floatSlow` 浮动动画）+ 蝴蝶结分隔线
- 顶栏：**分类筛选按钮**（全部/饮品/食物…带计数、选中态粉底白字）+（可选）描边预览切换
- 图标卡墙：响应式 `grid-cols-2 sm:3 md:4`，卡片 hover `translateY(-6px) scale(1.02)` 回弹曲线
- 检视弹窗：160px 大图 + category 徽章 + 中文名 + 英文小字 + 源码 `textarea readonly` + 复制/下载按钮
- 复制：`navigator.clipboard.writeText`，失败 fallback 全选 textarea；下载：Blob + `URL.createObjectURL`
- toast 右下角反馈；ICONS_DATA 集中在顶部 `<script>`，渲染/筛选/弹窗全是纯函数遍历

## 4. 优化后的生成 Prompt（可直接复用）

> 为「{主题}」生成一个单文件 HTML 图标画板，含 20 枚原创手绘风 SVG 图标（{类别A} 10 + {类别B} 10）。
> 图标规范：viewBox 0 0 120 120 的完整独立 svg；暖深棕 #4A342E 描边、主体 2.6px、细节 2.0–2.4px，
> 全部圆角 cap/join；禁用任何 SVG 滤镜，手绘感来自微不对称贝塞尔（Q/T 波浪液面、非正圆轮廓、
> 小件 rotate(-8~10°) 歪斜）；填色用马卡龙低饱和粉彩（粉 #F4A7B9 / 淡粉 #FAD2DC / 奶油黄 #FFF3D6 /
> 抹茶 #C2D8A3 / 奶白 #FFFDF9 + ≤4 个主题固有色）；每枚 ≥6 层结构（主体/填充层/配件/细节/签名/点缀）；
> 吸管壶柄用「墨线 7-8px + 彩芯 2.5-3.2px」双层描边；每枚必带中心小爱心与 sparkle 作为整套签名元素，
> 不加拟人表情。数据结构 {id, category, zh, en, svg}。
> 画板：Tailwind CDN + Fredoka/Quicksand 字体；米白圆点纹理背景 + poster 主画板；
> SVG 手写标题页眉（浮动爱心装饰 + 蝴蝶结分隔线）；顶栏分类筛选（带计数）；
> 响应式 4 列卡墙（hover 回弹抬起）；点击弹检视窗（大图 + 中英文名 + 源码 + 复制 + 下载 .svg）；
> 右下角 toast。所有代码内联单文件，无外部 JS 依赖。

## 5. 质检清单（生成后必做）

1. 每枚 svg：标签配平（开 = 闭 + 自闭合）、`d` 属性仅含合法命令字符、无 `filter=` 引用、无裸 `&`
2. viewBox 统一 120；签名爱心存在；无表情（除非要求）；层次数 ≥6
3. 抽 3 枚目测：液面是波浪、小件带微旋转、留白充足、主体没出界
4. `<script>` 语法编译通过（`new Function(src)` 不抛错）
5. 分类计数与实际数量一致

校验脚本（node，直接跑）：
```js
const re = /\{\s*id:\s*'([^']+)',[\s\S]*?svg:\s*`([\s\S]*?)`\s*\}/g;
// 逐枚：标签配平 / d 合法 / 无 filter / 爱心存在；最后 new Function 校验整页脚本
```

## 6. 接入 aboutme 商店（后处理）

用户确认画板后，把图标抽成资产：
1. 提取：按 `id`/`svg` 正则抽片段 → 剥 HTML 注释与 filter 属性 → 包
   `<svg xmlns viewBox="0 0 120 120" width height>` → 存 `assets/svg/items/<前缀>_<id>.svg`
   （前缀如 drink_/food_；目录已在 pubspec 注册）
2. 复用：`sample_data.dart` 给示例商品配 `image: 'assets/svg/items/xxx.svg'`；封面渲染走
   `AdaptiveImage`（已支持 .svg 分流 flutter_svg）
3. 校验：标签配平脚本过一遍再落盘
