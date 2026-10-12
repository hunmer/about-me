import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart' show DrawConfig;

/// 扇环投影（画布经 MaskFilter.blur 绘制，sigma ≈ CSS blur / 2）
class RadialShadow {
  const RadialShadow({
    required this.dx,
    required this.dy,
    required this.sigma,
    required this.color,
  });

  final double dx;
  final double dy;
  final double sigma;
  final Color color;
}

/// 弧形圆盘导航栏配色
///
/// 默认值对应参考实现的浅色 / 深色两套外观。
class RadialDiscBarStyle {
  const RadialDiscBarStyle({
    this.fillColor = const Color(0xF2FFFFFF), // rgba(255,255,255,0.95)
    this.strokeColor = const Color(0xF2FFFFFF),
    this.shadows = lightShadows,
    this.activePillColor = const Color(0xFF7B818D),
    this.activePillShadow = const BoxShadow(
      offset: Offset(0, 2),
      blurRadius: 8,
      color: Color(0x2E000000), // rgba(0,0,0,0.18)
    ),
    this.activeIconColor = const Color(0xFFFFFFFF),
    this.inactiveIconColor = const Color(0xFF4B5563), // zinc-600
    this.subPillColor = const Color(0xFFD2D4D8),
    this.subActiveTextColor = const Color(0xFF1F242D),
    this.subInactiveTextColor = const Color(0xFF4B5563),
    this.roundButtonColor = const Color(0xFFFFFFFF),
    this.roundButtonBorderColor = const Color(0x0A000000), // black/4%
    this.roundButtonIconColor = const Color(0xFF27272A), // zinc-800
    this.roundButtonShadow = const BoxShadow(
      offset: Offset(0, 4),
      blurRadius: 12,
      color: Color(0x14000000),
    ),
    this.drawConfig,
  });

  const RadialDiscBarStyle.dark()
      : fillColor = const Color(0xF01E222A), // rgba(30,34,42,0.94)
        strokeColor = const Color(0x1FFFFFFF), // white/12%
        shadows = darkShadows,
        activePillColor = const Color(0xFF464D5C),
        activePillShadow = const BoxShadow(
          offset: Offset(0, 2),
          blurRadius: 8,
          color: Color(0x2E000000),
        ),
        activeIconColor = const Color(0xFFFFFFFF),
        inactiveIconColor = const Color(0xFF9CA3AF),
        subPillColor = const Color(0xFF4C5361),
        subActiveTextColor = const Color(0xFFFFFFFF),
        subInactiveTextColor = const Color(0xFF9CA3AF),
        roundButtonColor = const Color(0xFF1E222A),
        roundButtonBorderColor = const Color(0x1AFFFFFF), // white/10%
        roundButtonIconColor = const Color(0xFFFFFFFF),
        roundButtonShadow = const BoxShadow(
          offset: Offset(0, 4),
          blurRadius: 6,
          color: Color(0x1A000000),
        ),
        drawConfig = null;

  factory RadialDiscBarStyle.fromBrightness(bool dark) =>
      dark ? const RadialDiscBarStyle.dark() : const RadialDiscBarStyle();

  static const List<RadialShadow> lightShadows = [
    RadialShadow(dx: 0, dy: 8, sigma: 10, color: Color(0x14000000)),
    RadialShadow(dx: 0, dy: 2, sigma: 2.5, color: Color(0x0A000000)),
  ];
  static const List<RadialShadow> darkShadows = [
    RadialShadow(dx: 0, dy: 12, sigma: 12, color: Color(0x80000000)),
  ];

  /// 扇环填充色（0.95 白 / 0.94 深灰，透出下方内容一丝底色）
  final Color fillColor;

  /// 扇环描边（1.2px 发丝线）
  final Color strokeColor;

  /// 扇环投影（画布绘制，逐个 blur 平移绘制）
  final List<RadialShadow> shadows;

  /// 主 dock 滑动药丸
  final Color activePillColor;
  final BoxShadow activePillShadow;

  /// tab 图标选中 / 未选中色（经由 IconTheme 下发）
  final Color activeIconColor;
  final Color inactiveIconColor;

  /// 子栏分段滑动药丸与文字
  final Color subPillColor;
  final Color subActiveTextColor;
  final Color subInactiveTextColor;

  /// 子栏圆按钮
  final Color roundButtonColor;
  final Color roundButtonBorderColor;
  final Color roundButtonIconColor;
  final BoxShadow roundButtonShadow;

  /// 手绘笔触配置（skribble rough 引擎）：null 时用包内默认手绘档。
  /// 扇环 / 药丸 / 圆钮的墨线抖动幅度由此决定，可与宿主设计系统
  /// 共用同一份 DrawConfig 保持全局风格一致
  final DrawConfig? drawConfig;

  RadialDiscBarStyle copyWith({
    Color? fillColor,
    Color? strokeColor,
    List<RadialShadow>? shadows,
    Color? activePillColor,
    BoxShadow? activePillShadow,
    Color? activeIconColor,
    Color? inactiveIconColor,
    Color? subPillColor,
    Color? subActiveTextColor,
    Color? subInactiveTextColor,
    Color? roundButtonColor,
    Color? roundButtonBorderColor,
    Color? roundButtonIconColor,
    BoxShadow? roundButtonShadow,
    DrawConfig? drawConfig,
  }) {
    return RadialDiscBarStyle(
      fillColor: fillColor ?? this.fillColor,
      strokeColor: strokeColor ?? this.strokeColor,
      shadows: shadows ?? this.shadows,
      activePillColor: activePillColor ?? this.activePillColor,
      activePillShadow: activePillShadow ?? this.activePillShadow,
      activeIconColor: activeIconColor ?? this.activeIconColor,
      inactiveIconColor: inactiveIconColor ?? this.inactiveIconColor,
      subPillColor: subPillColor ?? this.subPillColor,
      subActiveTextColor: subActiveTextColor ?? this.subActiveTextColor,
      subInactiveTextColor: subInactiveTextColor ?? this.subInactiveTextColor,
      roundButtonColor: roundButtonColor ?? this.roundButtonColor,
      roundButtonBorderColor: roundButtonBorderColor ?? this.roundButtonBorderColor,
      roundButtonIconColor: roundButtonIconColor ?? this.roundButtonIconColor,
      roundButtonShadow: roundButtonShadow ?? this.roundButtonShadow,
      drawConfig: drawConfig ?? this.drawConfig,
    );
  }
}
