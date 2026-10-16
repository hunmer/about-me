import 'package:flutter/widgets.dart';

/// 主题色板：可切换的整体色调（主色 + 页面背景 + 文字）
///
/// 仅承载浅色模式的核心观感色；深色模式与成功/警告/危险等
/// 语义色保持全局一致，不随色板变化。
class DsThemePalette {
  const DsThemePalette({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.background,
    required this.backgroundAlt,
    required this.text,
    required this.textSub,
    this.ink,
  });

  /// 稳定标识（持久化用）
  final String id;

  /// 展示名称
  final String name;

  /// 主色
  final Color primary;

  /// 辅助色
  final Color secondary;

  /// 页面背景
  final Color background;

  /// 背景（渐变另一端 / 次级表面）
  final Color backgroundAlt;

  /// 主文字
  final Color text;

  /// 次要文字
  final Color textSub;

  /// 墨线色：手绘描边与手绘图标的主色
  /// （null = 跟随 [text] 的同色相深墨，即描边默认随主题色相）
  final Color? ink;
}

/// 内置色板集合
///
/// [pink] 为默认色板，色值与 [DsColors] 原始调色板一致，
/// 保证未切换色板时观感与历史版本完全相同。
abstract final class DsThemePalettes {
  /// 樱花粉（默认）
  static const DsThemePalette pink = DsThemePalette(
    id: 'pink',
    name: '樱花粉',
    primary: Color(0xFF885CF6),
    secondary: Color(0xFFF5A8D4),
    background: Color(0xFFFDF7FF),
    backgroundAlt: Color(0xFFF3E8FF),
    text: Color(0xFF4C1D95),
    textSub: Color(0xFFA78BFA),
  );

  /// 莓果紫
  static const DsThemePalette berry = DsThemePalette(
    id: 'berry',
    name: '莓果紫',
    primary: Color(0xFFEC4899),
    secondary: Color(0xFFF9A8D4),
    background: Color(0xFFFDF5F9),
    backgroundAlt: Color(0xFFFBE8F1),
    text: Color(0xFF831843),
    textSub: Color(0xFFF9A8D4),
  );

  /// 海空蓝
  static const DsThemePalette ocean = DsThemePalette(
    id: 'ocean',
    name: '海空蓝',
    primary: Color(0xFF3B82F6),
    secondary: Color(0xFF7DD3FC),
    background: Color(0xFFF5FAFF),
    backgroundAlt: Color(0xFFE3F0FF),
    text: Color(0xFF1E3A8A),
    textSub: Color(0xFF93C5FD),
  );

  /// 抹茶绿
  static const DsThemePalette matcha = DsThemePalette(
    id: 'matcha',
    name: '抹茶绿',
    primary: Color(0xFF10B981),
    secondary: Color(0xFFA7F3D0),
    background: Color(0xFFF4FCF8),
    backgroundAlt: Color(0xFFE2F8EF),
    text: Color(0xFF065F46),
    textSub: Color(0xFF6EE7B7),
  );

  /// 蜜桃橙
  static const DsThemePalette peach = DsThemePalette(
    id: 'peach',
    name: '蜜桃橙',
    primary: Color(0xFFFB923C),
    secondary: Color(0xFFFDE68A),
    background: Color(0xFFFFFAF5),
    backgroundAlt: Color(0xFFFFF0E3),
    text: Color(0xFF9A3412),
    textSub: Color(0xFFFDBA74),
  );

  /// 暖纸梅紫（cuddly：暖纸底 + 梅紫墨，配 Gentle 墨线的软萌系主题）
  static const DsThemePalette cuddly = DsThemePalette(
    id: 'cuddly',
    name: '暖纸梅紫',
    primary: Color(0xFF9B6FB0),
    secondary: Color(0xFFE8C8DC),
    background: Color(0xFFFAF3EA),
    backgroundAlt: Color(0xFFF3E7D8),
    text: Color(0xFF57365E),
    textSub: Color(0xFFB892BE),
  );

  /// 奶油蜂蜜（暖黄纸 + 蜂蜜墨，配 Expressive 墨线的涂鸦系主题）
  static const DsThemePalette butter = DsThemePalette(
    id: 'butter',
    name: '奶油蜂蜜',
    primary: Color(0xFFE0A93E),
    secondary: Color(0xFFF9E2A8),
    background: Color(0xFFFFFAEB),
    backgroundAlt: Color(0xFFFDF3D3),
    text: Color(0xFF6B4E12),
    textSub: Color(0xFFD9B45C),
  );

  static const List<DsThemePalette> all = [
    pink,
    berry,
    ocean,
    matcha,
    peach,
    cuddly,
    butter,
  ];

  /// 按 id 查找，未知 id 回落默认色板
  static DsThemePalette byId(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return pink;
  }
}
