import 'package:flutter/material.dart';

/// 手账便签内容类型
enum CuteNotepadNoteType {
  /// 自由文本（可选追加待办）
  freeform,

  /// 待办清单（带复选框）
  checklist,

  /// 横线笔记（默认无复选框）
  lined,
}

/// 复选框样式
enum CuteNotepadCheckStyle { box, heart, star, circle }

/// 贴纸在便签画布中的锚定方位
enum CuteNotepadStickerAnchor {
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomRight,
  center,
}

/// 便签底图风格
enum CuteNotepadBackground {
  gridPaper, // 方格纸
  wavyInner, // 波浪内衬纸
  plain, // 纯色纸面
  innerRoundFrame, // 内嵌圆角框
  waveTopHeader, // 波浪顶栏
  leftBinderHoles, // 左侧活页孔
  plaidInnerRound, // 格纹 + 内圆角纸区
  gridBanner, // 方格 + 标题横幅
  tornEdge, // 撕边纸
  doubleWavyFrame, // 双波浪手绘框
  rightWaveEdge, // 右侧波浪边
  plaidCloudFrame, // 格纹 + 云朵框
  wavyFrame, // 单波浪手绘框
  topBinderHoles, // 顶部打孔
}

/// 标题位置（viewBox 300×H 坐标系）
class CuteNotepadTitlePos {
  final double top;
  final double left;
  final double width;
  final double fontSize;
  final double rotate;
  final bool center;

  const CuteNotepadTitlePos({
    required this.top,
    required this.left,
    required this.width,
    required this.fontSize,
    this.rotate = 0,
    this.center = false,
  });
}

/// 待办/横线行数据
class CuteNotepadTodoItem {
  final bool checked;
  final String text;

  const CuteNotepadTodoItem({this.checked = false, this.text = ''});
}

/// 贴纸摆放配置（asset 为 cute_notepad_stickers.dart 中的贴纸 id）
///
/// 提供两种定位方式：锚点 + 偏移（预设方式），或绝对布局 [x]/[y]/
/// [rotation]/[scale]（贴图编辑器受控方式，非 null 时优先）。
class CuteNotepadSticker {
  final String asset;
  final CuteNotepadStickerAnchor anchor;
  final double w;
  final double h;
  final double dx;
  final double dy;

  /// 绝对布局（viewBox 坐标），非 null 时优先于 anchor/dx/dy
  final double? x;
  final double? y;
  final double? rotation; // 角度
  final double? scale;

  /// 水平翻转
  final bool flipX;

  const CuteNotepadSticker({
    required this.asset,
    this.anchor = CuteNotepadStickerAnchor.center,
    required this.w,
    required this.h,
    this.dx = 0,
    this.dy = 0,
    this.x,
    this.y,
    this.rotation,
    this.scale,
    this.flipX = false,
  });
}

/// 一种手账便签风格预设（坐标均为 viewBox 300×H 单位）
class CuteNotepadVariant {
  final String id;
  final String name;

  final CuteNotepadNoteType type;
  final CuteNotepadCheckStyle checkStyle;

  /// lined 类型初始是否显示复选框
  final bool showChecksOnLined;

  final CuteNotepadBackground background;

  // ---- 底图颜色 ----
  final Color shadowColor;
  final Color paperColor;
  final Color? paperStroke;

  /// 纸面 y 偏移（6 默认 / 10 活页孔纸 / 12 顶部打孔纸）
  final double paperTop;

  /// 方格线颜色（gridPaper / gridBanner）
  final Color? gridColor;
  final double gridStep;

  /// 格纹色带颜色（plaidInnerRound / plaidCloudFrame）
  final Color? plaidBandColor;
  final double plaidStep;

  /// 内衬/内框填充与描边
  final Color? innerFillColor;
  final Color? innerStrokeColor;
  final Color? innerStroke2Color;

  /// 波浪顶栏（waveTopHeader）
  final Color? waveHeaderColor;
  final Color? waveHeaderStroke;

  /// 标题横幅（gridBanner）
  final Color? bannerFillColor;
  final Color? bannerStrokeColor;

  /// 活页孔（leftBinderHoles / topBinderHoles）
  final Color? holeBgColor;
  final Color? holeStrokeColor;

  // ---- 文字与布局 ----
  final String? title;
  final CuteNotepadTitlePos? titlePos;
  final Color textColor;
  final Color lineColor;
  final String? placeholder;

  final double contentStartY;
  final double lineSpacing;
  final int minFreeformLines;

  /// 横线笔记（lined 无复选框）时的底线起止 x
  final double? lineX1;
  final double? lineX2;

  /// 自由文本区位置（7/13/15 号便签偏内）
  final double freeformLeft;
  final double freeformWidth;

  final List<CuteNotepadTodoItem> items;
  final List<CuteNotepadSticker> stickers;

  const CuteNotepadVariant({
    required this.id,
    required this.name,
    required this.type,
    required this.checkStyle,
    required this.background,
    required this.shadowColor,
    required this.paperColor,
    this.showChecksOnLined = false,
    this.paperStroke,
    this.paperTop = 6,
    this.gridColor,
    this.gridStep = 24,
    this.plaidBandColor,
    this.plaidStep = 28,
    this.innerFillColor,
    this.innerStrokeColor,
    this.innerStroke2Color,
    this.waveHeaderColor,
    this.waveHeaderStroke,
    this.bannerFillColor,
    this.bannerStrokeColor,
    this.holeBgColor,
    this.holeStrokeColor,
    this.title,
    this.titlePos,
    required this.textColor,
    required this.lineColor,
    this.placeholder,
    required this.contentStartY,
    this.lineSpacing = 34,
    this.minFreeformLines = 4,
    this.lineX1,
    this.lineX2,
    this.freeformLeft = 30,
    this.freeformWidth = 236,
    this.items = const [],
    this.stickers = const [],
  });
}

/// 16 种风格预设（与网页版 INITIAL_NOTES_CONFIG 一一对应）
const List<CuteNotepadVariant> cuteNotepadPresets = [
  // 01 粉色方格小兔便签
  CuteNotepadVariant(
    id: 'pinkGridBunny',
    name: '01 · 粉色方格小兔便签',
    type: CuteNotepadNoteType.freeform,
    checkStyle: CuteNotepadCheckStyle.heart,
    background: CuteNotepadBackground.gridPaper,
    shadowColor: Color(0x8CD9B8BE),
    paperColor: Color(0xFFFFDCE2),
    paperStroke: Color(0xFFF5B8C3),
    gridColor: Color(0xFFF7BDC8),
    gridStep: 24,
    lineColor: Color(0xFFF2A7B8),
    textColor: Color(0xFF6B4438),
    placeholder: '在这里写下今天的小确幸...',
    contentStartY: 66,
    minFreeformLines: 4,
    stickers: [
      CuteNotepadSticker(asset: 'redBow', anchor: CuteNotepadStickerAnchor.topLeft, w: 68, h: 68, dx: -2, dy: -2),
      CuteNotepadSticker(asset: 'pinkDoubleHearts', anchor: CuteNotepadStickerAnchor.topRight, w: 64, h: 58, dx: -8),
      CuteNotepadSticker(asset: 'peekingBunny', anchor: CuteNotepadStickerAnchor.bottomRight, w: 105, h: 94, dx: -2, dy: 8),
    ],
  ),

  // 02 黄色 To Do 花朵清单
  CuteNotepadVariant(
    id: 'yellowTodoFlower',
    name: '02 · 黄色 To Do 花朵清单',
    type: CuteNotepadNoteType.checklist,
    checkStyle: CuteNotepadCheckStyle.box,
    background: CuteNotepadBackground.wavyInner,
    shadowColor: Color(0x80D6CBA3),
    paperColor: Color(0xFFFFF0B5),
    paperStroke: Color(0xFFEDD582),
    innerFillColor: Color(0xFFFFFBE8),
    lineColor: Color(0xFF7A5C43),
    title: 'To Do:',
    titlePos: CuteNotepadTitlePos(top: 24, left: 32, width: 165, fontSize: 21),
    textColor: Color(0xFF6E4F35),
    contentStartY: 60,
    lineSpacing: 34,
    items: [
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
    ],
    stickers: [
      CuteNotepadSticker(asset: 'topYellowFlower', anchor: CuteNotepadStickerAnchor.topRight, w: 66, h: 60, dx: -6, dy: 2),
      CuteNotepadSticker(asset: 'bottomWhiteDaisies', anchor: CuteNotepadStickerAnchor.bottomRight, w: 86, h: 86, dx: -6, dy: -2),
    ],
  ),

  // 03 紫色云朵便签
  CuteNotepadVariant(
    id: 'purpleCloud',
    name: '03 · 紫色云朵便签',
    type: CuteNotepadNoteType.freeform,
    checkStyle: CuteNotepadCheckStyle.heart,
    background: CuteNotepadBackground.plain,
    shadowColor: Color(0x8CBFB5D6),
    paperColor: Color(0xFFE4DAF7),
    paperStroke: Color(0xFFCBBBE8),
    lineColor: Color(0xFFB59EE0),
    title: 'Small steps\nbig progress ♡',
    titlePos: CuteNotepadTitlePos(top: 22, left: 26, width: 165, fontSize: 16.5, rotate: -5),
    textColor: Color(0xFF4C3575),
    placeholder: '记录每天的小进步...',
    contentStartY: 88,
    minFreeformLines: 4,
    stickers: [
      CuteNotepadSticker(asset: 'purpleCloudRain', anchor: CuteNotepadStickerAnchor.topRight, w: 92, h: 78, dx: -4),
    ],
  ),

  // 04 绿色爱心清单青蛙便签
  CuteNotepadVariant(
    id: 'greenHeartFrog',
    name: '04 · 绿色爱心清单青蛙便签',
    type: CuteNotepadNoteType.checklist,
    checkStyle: CuteNotepadCheckStyle.heart,
    background: CuteNotepadBackground.innerRoundFrame,
    shadowColor: Color(0x80B9C9A5),
    paperColor: Color(0xFFDCEDC2),
    innerFillColor: Color(0xFFF2F8E4),
    innerStrokeColor: Color(0xFF62873C),
    lineColor: Color(0xFF7FA15A),
    textColor: Color(0xFF446326),
    contentStartY: 42,
    lineSpacing: 37,
    items: [
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
    ],
    stickers: [
      CuteNotepadSticker(asset: 'greenHeart', anchor: CuteNotepadStickerAnchor.topRight, w: 44, h: 44, dx: -14, dy: 10),
      CuteNotepadSticker(asset: 'cuteFrog', anchor: CuteNotepadStickerAnchor.bottomRight, w: 96, h: 80, dx: -10, dy: -6),
    ],
  ),

  // 05 蓝色波浪顶 Notes 便签
  CuteNotepadVariant(
    id: 'blueWaveNotes',
    name: '05 · 蓝色波浪顶 Notes 便签',
    type: CuteNotepadNoteType.freeform,
    checkStyle: CuteNotepadCheckStyle.circle,
    background: CuteNotepadBackground.waveTopHeader,
    shadowColor: Color(0x8CB3C7DB),
    paperColor: Color(0xFFE6F3FF),
    paperStroke: Color(0xFF9EC5EB),
    waveHeaderColor: Color(0xFFBDE0FE),
    waveHeaderStroke: Color(0xFF85B6E5),
    lineColor: Color(0xFF8EBCE6),
    title: 'Notes:',
    titlePos: CuteNotepadTitlePos(top: 36, left: 28, width: 120, fontSize: 21, rotate: -6),
    textColor: Color(0xFF365F8A),
    placeholder: '记录灵感与随笔...',
    contentStartY: 82,
    minFreeformLines: 4,
    stickers: [
      CuteNotepadSticker(asset: 'blueCloud', anchor: CuteNotepadStickerAnchor.bottomLeft, w: 84, h: 68, dx: 6, dy: -2),
      CuteNotepadSticker(asset: 'blueDoubleHearts', anchor: CuteNotepadStickerAnchor.bottomRight, w: 68, h: 60, dx: -10, dy: -6),
    ],
  ),

  // 06 粉色活页孔郁金香横线便签
  CuteNotepadVariant(
    id: 'pinkTulipLined',
    name: '06 · 粉色活页孔郁金香便签',
    type: CuteNotepadNoteType.lined,
    checkStyle: CuteNotepadCheckStyle.heart,
    background: CuteNotepadBackground.leftBinderHoles,
    shadowColor: Color(0x80D9B4BA),
    paperColor: Color(0xFFFFD9DF),
    paperStroke: Color(0xFFF2B6C0),
    paperTop: 10,
    holeBgColor: Color(0xFFFBF9F5),
    holeStrokeColor: Color(0xFFE3B6BE),
    lineColor: Color(0xFFF2ABB7),
    textColor: Color(0xFF75434C),
    contentStartY: 50,
    lineSpacing: 32,
    lineX1: 48,
    lineX2: 266,
    items: [
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
    ],
    stickers: [
      CuteNotepadSticker(asset: 'pinkHeartTape', anchor: CuteNotepadStickerAnchor.topCenter, w: 126, h: 50, dx: 6, dy: -8),
      CuteNotepadSticker(asset: 'pinkTulips', anchor: CuteNotepadStickerAnchor.bottomRight, w: 78, h: 82, dx: -8, dy: -2),
    ],
  ),

  // 07 黄色格纹太阳花朵便签
  CuteNotepadVariant(
    id: 'yellowPlaidSun',
    name: '07 · 黄色格纹太阳花朵便签',
    type: CuteNotepadNoteType.freeform,
    checkStyle: CuteNotepadCheckStyle.circle,
    background: CuteNotepadBackground.plaidInnerRound,
    shadowColor: Color(0x80D9CCA3),
    paperColor: Color(0xFFFFF3BD),
    paperStroke: Color(0xFFEBD075),
    plaidBandColor: Color(0xFFFFDF70),
    plaidStep: 28,
    innerFillColor: Color(0xFFFFFDF2),
    lineColor: Color(0xFFEBD075),
    textColor: Color(0xFF735329),
    placeholder: '写下阳光般温暖的计划...',
    contentStartY: 74,
    minFreeformLines: 4,
    freeformLeft: 40,
    freeformWidth: 220,
    stickers: [
      CuteNotepadSticker(asset: 'smilingSun', anchor: CuteNotepadStickerAnchor.topRight, w: 84, h: 84, dx: -6, dy: 2),
      CuteNotepadSticker(asset: 'yellowFlowersBottomLeft', anchor: CuteNotepadStickerAnchor.bottomLeft, w: 82, h: 82, dx: 6, dy: -2),
    ],
  ),

  // 08 紫色方格三花猫便签
  CuteNotepadVariant(
    id: 'purpleGridCat',
    name: '08 · 紫色方格三花猫便签',
    type: CuteNotepadNoteType.freeform,
    checkStyle: CuteNotepadCheckStyle.heart,
    background: CuteNotepadBackground.gridBanner,
    shadowColor: Color(0x80BFB5D4),
    paperColor: Color(0xFFE6DCF8),
    paperStroke: Color(0xFFCBBBE8),
    gridColor: Color(0xFFD4C4ED),
    gridStep: 22,
    bannerFillColor: Color(0xFFEFE7FC),
    bannerStrokeColor: Color(0xFF8568B0),
    lineColor: Color(0xFFB99EE0),
    title: 'You got this! ♡',
    titlePos: CuteNotepadTitlePos(top: 22, left: 58, width: 180, fontSize: 16, center: true),
    textColor: Color(0xFF523961),
    placeholder: '给自己打气加油...',
    contentStartY: 64,
    minFreeformLines: 4,
    stickers: [
      CuteNotepadSticker(asset: 'peekingCat', anchor: CuteNotepadStickerAnchor.bottomRight, w: 112, h: 88, dx: -4, dy: 4),
    ],
  ),

  // 09 绿色撕边星星清单便签
  CuteNotepadVariant(
    id: 'greenTornStar',
    name: '09 · 绿色撕边星星清单便签',
    type: CuteNotepadNoteType.checklist,
    checkStyle: CuteNotepadCheckStyle.star,
    background: CuteNotepadBackground.tornEdge,
    shadowColor: Color(0x80B8C9AB),
    paperColor: Color(0xFFE2F0D5),
    paperStroke: Color(0xFFBED4AB),
    lineColor: Color(0xFF8EB07C),
    textColor: Color(0xFF43612D),
    contentStartY: 44,
    lineSpacing: 37,
    items: [
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
    ],
    stickers: [
      CuteNotepadSticker(asset: 'greenPlaidTape', anchor: CuteNotepadStickerAnchor.topCenter, w: 118, h: 46, dx: -4, dy: -4),
      CuteNotepadSticker(asset: 'greenSprout', anchor: CuteNotepadStickerAnchor.bottomRight, w: 66, h: 66, dx: -8, dy: -4),
    ],
  ),

  // 10 紫色手绘框紫花便签
  CuteNotepadVariant(
    id: 'purpleFrameFlower',
    name: '10 · 紫色手绘框紫花便签',
    type: CuteNotepadNoteType.freeform,
    checkStyle: CuteNotepadCheckStyle.heart,
    background: CuteNotepadBackground.doubleWavyFrame,
    shadowColor: Color(0x80BFB3D4),
    paperColor: Color(0xFFE6DBF7),
    paperStroke: Color(0xFFCBBBE8),
    innerStrokeColor: Color(0xFF8E72B8),
    innerStroke2Color: Color(0xFFA68CCF),
    lineColor: Color(0xFFB399DE),
    textColor: Color(0xFF523970),
    placeholder: '写下温柔的诗句或心情...',
    contentStartY: 58,
    minFreeformLines: 4,
    stickers: [
      CuteNotepadSticker(asset: 'purpleTinyHeart', anchor: CuteNotepadStickerAnchor.topLeft, w: 40, h: 40, dx: 10, dy: 10),
      CuteNotepadSticker(asset: 'purpleFlowersBottomLeft', anchor: CuteNotepadStickerAnchor.bottomLeft, w: 86, h: 84, dx: 8, dy: -8),
      CuteNotepadSticker(asset: 'purpleTinyHeart', anchor: CuteNotepadStickerAnchor.bottomRight, w: 40, h: 40, dx: -14, dy: -12),
    ],
  ),

  // 11 蓝色 Keep going 企鹅便签
  CuteNotepadVariant(
    id: 'bluePenguin',
    name: '11 · 蓝色 Keep going 企鹅便签',
    type: CuteNotepadNoteType.freeform,
    checkStyle: CuteNotepadCheckStyle.circle,
    background: CuteNotepadBackground.plain,
    shadowColor: Color(0x8CADC2D9),
    paperColor: Color(0xFFCCE4FB),
    paperStroke: Color(0xFFA5C9ED),
    lineColor: Color(0xFF8CBBE8),
    title: 'Keep\ngoing ♡',
    titlePos: CuteNotepadTitlePos(top: 24, left: 28, width: 135, fontSize: 17.5, rotate: -6),
    textColor: Color(0xFF2B547E),
    placeholder: '坚持下去，美好正在发生...',
    contentStartY: 84,
    minFreeformLines: 4,
    stickers: [
      CuteNotepadSticker(asset: 'blueOutlineHeart', anchor: CuteNotepadStickerAnchor.topRight, w: 48, h: 48, dx: -10, dy: 6),
      CuteNotepadSticker(asset: 'cutePenguin', anchor: CuteNotepadStickerAnchor.bottomRight, w: 98, h: 90, dx: -4, dy: 6),
    ],
  ),

  // 12 粉色回形针樱桃横线便签
  CuteNotepadVariant(
    id: 'pinkWaveCherry',
    name: '12 · 粉色回形针樱桃便签',
    type: CuteNotepadNoteType.lined,
    checkStyle: CuteNotepadCheckStyle.heart,
    background: CuteNotepadBackground.rightWaveEdge,
    shadowColor: Color(0x80D9B6BC),
    paperColor: Color(0xFFFFDBE0),
    paperStroke: Color(0xFFF2B6C0),
    lineColor: Color(0xFFF09CA8),
    textColor: Color(0xFF753B43),
    contentStartY: 54,
    lineSpacing: 36,
    lineX1: 30,
    lineX2: 256,
    items: [
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
    ],
    stickers: [
      CuteNotepadSticker(asset: 'redPaperclip', anchor: CuteNotepadStickerAnchor.topRight, w: 68, h: 72, dx: -8, dy: -12),
      CuteNotepadSticker(asset: 'coralDoubleHearts', anchor: CuteNotepadStickerAnchor.bottomLeft, w: 66, h: 62, dx: 8, dy: -6),
      CuteNotepadSticker(asset: 'cuteCherries', anchor: CuteNotepadStickerAnchor.bottomRight, w: 72, h: 72, dx: -12, dy: -6),
    ],
  ),

  // 13 紫色格纹云朵框便签
  CuteNotepadVariant(
    id: 'purplePlaidCloud',
    name: '13 · 紫色格纹云朵框便签',
    type: CuteNotepadNoteType.freeform,
    checkStyle: CuteNotepadCheckStyle.heart,
    background: CuteNotepadBackground.plaidCloudFrame,
    shadowColor: Color(0x80C2B4D6),
    paperColor: Color(0xFFF0E4FF),
    paperStroke: Color(0xFFC7ADEB),
    plaidBandColor: Color(0xFFD3B8F7),
    plaidStep: 26,
    innerFillColor: Color(0xFFF5EDFF),
    innerStrokeColor: Color(0xFFB79BD9),
    lineColor: Color(0xFFC3A8E8),
    textColor: Color(0xFF563C78),
    placeholder: '记录今天闪闪发光的灵感...',
    contentStartY: 70,
    minFreeformLines: 4,
    freeformLeft: 40,
    freeformWidth: 220,
    stickers: [
      CuteNotepadSticker(asset: 'purpleBow', anchor: CuteNotepadStickerAnchor.topLeft, w: 78, h: 78, dy: 2),
      CuteNotepadSticker(asset: 'purpleDoubleHearts', anchor: CuteNotepadStickerAnchor.bottomRight, w: 64, h: 64, dx: -14, dy: -10),
    ],
  ),

  // 14 黄色波点胶带小熊清单
  CuteNotepadVariant(
    id: 'yellowPolkaBear',
    name: '14 · 黄色波点胶带小熊清单',
    type: CuteNotepadNoteType.checklist,
    checkStyle: CuteNotepadCheckStyle.circle,
    background: CuteNotepadBackground.innerRoundFrame,
    shadowColor: Color(0x80D9CCA3),
    paperColor: Color(0xFFFFF4C2),
    paperTop: 10,
    innerFillColor: Color(0xFFFFFBE8),
    innerStrokeColor: Color(0xFFE6BE5A),
    lineColor: Color(0xFFEBD07A),
    textColor: Color(0xFF6B4922),
    contentStartY: 44,
    lineSpacing: 37,
    items: [
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
      CuteNotepadTodoItem(),
    ],
    stickers: [
      CuteNotepadSticker(asset: 'yellowPolkaTape', anchor: CuteNotepadStickerAnchor.topCenter, w: 118, h: 45, dy: -2),
      CuteNotepadSticker(asset: 'cuteBear', anchor: CuteNotepadStickerAnchor.bottomRight, w: 92, h: 86, dx: -10, dy: -6),
    ],
  ),

  // 15 蜜桃色 Good Things 便签
  CuteNotepadVariant(
    id: 'peachGoodThings',
    name: '15 · 蜜桃色 Good Things 便签',
    type: CuteNotepadNoteType.freeform,
    checkStyle: CuteNotepadCheckStyle.heart,
    background: CuteNotepadBackground.wavyFrame,
    shadowColor: Color(0x80D9BEB6),
    paperColor: Color(0xFFFFDFD6),
    paperStroke: Color(0xFFF5BFB0),
    innerStrokeColor: Color(0xFFF0A399),
    lineColor: Color(0xFFF0A399),
    title: 'Good\nThings\nAhead ♡',
    titlePos: CuteNotepadTitlePos(top: 24, left: 32, width: 125, fontSize: 16, rotate: -6),
    textColor: Color(0xFF6E473B),
    placeholder: '写下期待发生的美好事物...',
    contentStartY: 92,
    minFreeformLines: 4,
    freeformLeft: 40,
    freeformWidth: 220,
    stickers: [
      CuteNotepadSticker(asset: 'coralSparkleLines', anchor: CuteNotepadStickerAnchor.topRight, w: 50, h: 54, dx: -14, dy: 10),
      CuteNotepadSticker(asset: 'pinkTulips', anchor: CuteNotepadStickerAnchor.bottomLeft, w: 78, h: 82, dx: 12, dy: -6),
    ],
  ),

  // 16 雾霾蓝顶部打孔便签
  CuteNotepadVariant(
    id: 'blueBinderHoles',
    name: '16 · 雾霾蓝顶部打孔便签',
    type: CuteNotepadNoteType.freeform,
    checkStyle: CuteNotepadCheckStyle.box,
    background: CuteNotepadBackground.topBinderHoles,
    shadowColor: Color(0x8CB4BFD4),
    paperColor: Color(0xFFD2DFF7),
    paperStroke: Color(0xFFB8CAEC),
    paperTop: 12,
    holeBgColor: Color(0xFFFBF9F5),
    holeStrokeColor: Color(0xFFB3C4E3),
    lineColor: Color(0xFF9EB6DE),
    textColor: Color(0xFF364D73),
    placeholder: '随手记录备忘与灵感...',
    contentStartY: 58,
    minFreeformLines: 4,
    stickers: [
      CuteNotepadSticker(asset: 'blueTopTape', anchor: CuteNotepadStickerAnchor.topCenter, w: 92, h: 36, dy: -2),
      CuteNotepadSticker(asset: 'shiningBlueHeart', anchor: CuteNotepadStickerAnchor.bottomRight, w: 78, h: 76, dx: -8, dy: -4),
    ],
  ),
];

/// 按风格 id / 序号查找预设
CuteNotepadVariant resolveCuteNotepadVariant(dynamic style) {
  if (style is int && style >= 0 && style < cuteNotepadPresets.length) {
    return cuteNotepadPresets[style];
  }
  if (style is String) {
    for (final v in cuteNotepadPresets) {
      if (v.id == style) return v;
    }
  }
  return cuteNotepadPresets.first;
}
