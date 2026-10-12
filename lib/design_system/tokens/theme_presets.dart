import 'package:skribble/skribble.dart';

import 'palettes.dart';

/// 完整主题预设：色板 × 墨线档位成套切换
///
/// 对应 skribble 主题系统的完整主题概念——一次选择同时确定
/// 配色（浅色观感 + 深色自动派生）与手绘墨线粗糙度，
/// 替代原先"主题颜色"与"Ink style"两个独立开关。
class DsThemePreset {
  const DsThemePreset({
    required this.id,
    required this.name,
    required this.palette,
    required this.inkLevel,
    this.strokeWidth = 2.2,
  });

  /// 稳定标识
  final String id;

  /// 展示名称
  final String name;

  /// 配色（深浅两模式由 AppThemeData.fromPalette 从色板派生）
  final DsThemePalette palette;

  /// 墨线粗糙度档位
  final WiredRoughness inkLevel;

  /// 墨线笔宽（Wired* 组件描边粗细；默认 2.2 与历史版本一致）
  final double strokeWidth;

  /// 墨线档位下标（与 DsInkStyle.labels 对应）
  int get inkIndex => inkLevel.index;
}

/// 内置主题预设集合
///
/// 前 5 项墨线均为 Playful 且配色沿用历史色板，保证老用户
/// 已保存的配色选择仍能命中一个预设、观感不变。
abstract final class DsThemePresets {
  /// 手绘本铺（默认）
  static const DsThemePreset sketchbook = DsThemePreset(
    id: 'sketchbook',
    name: '手绘本铺',
    palette: DsThemePalettes.pink,
    inkLevel: WiredRoughness.playful,
  );

  /// 莓果紫
  static const DsThemePreset berry = DsThemePreset(
    id: 'berry',
    name: '莓果紫',
    palette: DsThemePalettes.berry,
    inkLevel: WiredRoughness.playful,
  );

  /// 海空蓝
  static const DsThemePreset ocean = DsThemePreset(
    id: 'ocean',
    name: '海空蓝',
    palette: DsThemePalettes.ocean,
    inkLevel: WiredRoughness.playful,
  );

  /// 抹茶绿
  static const DsThemePreset matcha = DsThemePreset(
    id: 'matcha',
    name: '抹茶绿',
    palette: DsThemePalettes.matcha,
    inkLevel: WiredRoughness.playful,
  );

  /// 蜜桃橙
  static const DsThemePreset peach = DsThemePreset(
    id: 'peach',
    name: '蜜桃橙',
    palette: DsThemePalettes.peach,
    inkLevel: WiredRoughness.playful,
  );

  /// 软萌手帐（暖纸梅紫 × Gentle 细笔，参考 skribble cuddly 预设）
  static const DsThemePreset cuddly = DsThemePreset(
    id: 'cuddly',
    name: '软萌手帐',
    palette: DsThemePalettes.cuddly,
    inkLevel: WiredRoughness.gentle,
    strokeWidth: 1.8,
  );

  /// 黄油涂鸦（奶油蜂蜜 × Expressive 粗笔狂放墨线）
  static const DsThemePreset butter = DsThemePreset(
    id: 'butter',
    name: '黄油涂鸦',
    palette: DsThemePalettes.butter,
    inkLevel: WiredRoughness.expressive,
    strokeWidth: 2.6,
  );

  /// 莓果夜话（莓果紫 × Expressive 浓墨重笔）
  static const DsThemePreset berryNight = DsThemePreset(
    id: 'berry_night',
    name: '莓果夜话',
    palette: DsThemePalettes.berry,
    inkLevel: WiredRoughness.expressive,
    strokeWidth: 2.6,
  );

  static const List<DsThemePreset> all = [
    sketchbook,
    berry,
    ocean,
    matcha,
    peach,
    cuddly,
    butter,
    berryNight,
  ];
}
