# grok_icon_study

Grok 登录页角色动效（弹簧驱动角色引擎）的 Flutter 移植包。

移植自 [blessonism/grok-icon-study](https://github.com/blessonism/grok-icon-study)（对 Grok Bot.app v0.18.0 登录页角色动效的学习性复刻）。

> ⚠️ 素材与几何数据版权归 xAI，仅供个人学习，禁止商用或再分发。

## 引擎结构（对应源码 `replica/src/`）

| 文件 | 对应源码 | 职责 |
| --- | --- | --- |
| `lib/src/grok_math.dart` | `math.js` | 弹簧、缓动、path 展平、水平跨度、3D 旋转、旋转体轮廓 |
| `lib/src/grok_geometry.dart` | `geometry-data.js` | 25 组眼睛多边形、18 种身形、11 色调色板、旋转体数据 |
| `lib/src/grok_tables.dart` | `tables.js` | 状态播放列表、眨眼节奏、弹簧参数、登录墨色 |
| `lib/src/grok_pose.dart` | `pose.js` | 39 态姿态驱动（applyPose）+ 注视目标 |
| `lib/src/grok_tricks.dart` | `tricks.js` | hop / 旋转 / spinBounce / spinDizzy / spinWild |
| `lib/src/grok_eyes.dart` | `eyes.js` | 眼睛变形、眨眼队列、眼眶定位（含 3D 旋转投影） |
| `lib/src/grok_fx.dart` | `fx.js` | 14 种 overlay 图形 + 粒子（爆裂 / 旋转条带） |
| `lib/src/grok_character.dart` | `character.js` | 角色编排器（状态机 + 弹簧 tick） |
| `lib/src/grok_painter.dart` | — | CustomPainter / `GrokCharacterView` 视图 |

驱动方式由 `requestAnimationFrame` 改为外部 `Ticker`，DOM 更新改为输出 `GrokFrame`
绘制指令由 `CustomPainter` 渲染。

## 使用

```dart
final bot = GrokCharacter(mode: 'hold', state: 'curious');

// 自带 Ticker 的视图
GrokCharacterView(character: bot, pointerFollow: true);

bot.setStateName('thinking'); // 单动画：锁定状态持续播放
bot.setShape('squircle');
bot.setColor('blue', 'light');
bot.spinOnce(1);   // 转一圈
bot.bounceOnce();  // 跳一下
bot.burstOnce();   // 粒子
```

`GrokStudyScreen` 为单动画播放调试页（状态 / 身形 / 墨色选择 + 特技触发 + 实时读数）。
