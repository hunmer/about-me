import 'package:flutter/material.dart';
import 'package:aboutme/core/event/event_manager.dart';

/// 成就等级视觉与奖励配置
///
/// 设计文档：Lv1 灰铁 / Lv2 青铜 / Lv3 白银 / Lv4 黄金 / Lv5 彩虹流光
class AchievementLevels {
  AchievementLevels._();

  /// 各等级积分奖励（Lv1~Lv5），不足 5 级的成就取前 N 档
  static const List<int> rewardPoints = [50, 100, 300, 800, 2000];

  /// 等级边框颜色（level 从 1 开始，0 表示未解锁）
  static Color borderColor(int level) {
    switch (level) {
      case 1:
        return const Color(0xFF8D99AE); // 灰铁
      case 2:
        return const Color(0xFFCD7F32); // 青铜
      case 3:
        return const Color(0xFFB8C0C8); // 白银
      case 4:
        return const Color(0xFFF5C518); // 黄金
      case 5:
        return const Color(0xFFFF6B9D); // 彩虹（实际渲染为流光动画）
      default:
        return const Color(0xFF64748B); // 未解锁
    }
  }

  /// 彩虹流光渐变色（Lv5 专用）
  static const List<Color> rainbowColors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFF6BCB77),
    Color(0xFF4D96FF),
    Color(0xFFB15EFF),
    Color(0xFFFF6B6B),
  ];

  static String levelLabel(int level) => 'Lv$level';
}

/// 成就分类
class AchievementCategory {
  final String id;
  final String nameKey;
  final IconData icon;

  const AchievementCategory({
    required this.id,
    required this.nameKey,
    required this.icon,
  });
}

/// 成就系列静态定义（与 docs/ACHIEVEMENT_SYSTEM_PLAN.md 一一对应）
class AchievementDefinition {
  /// 编号，如 A01
  final String id;

  /// 成就名称，如 千言万语
  final String name;

  /// 所属分类 id
  final String category;

  /// 达成条件描述
  final String condition;

  /// 计数单位，如 条 / 个 / 次 / 天
  final String unit;

  /// 各等级阈值（升序），长度即最高等级数
  final List<int> thresholds;

  /// 隐藏成就（未解锁时展览界面显示 ???）
  final bool hidden;

  /// 事件总线信号名（null 表示该成就尚未接入数据源）
  final String? event;

  const AchievementDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.condition,
    required this.unit,
    required this.thresholds,
    this.hidden = false,
    this.event,
  });

  int get maxLevel => thresholds.length;

  String get iconAsset => 'assets/achievements/$id.webp';

  /// 第 level 级（1 起）的积分奖励
  int rewardFor(int level) => AchievementLevels.rewardPoints[level - 1];

  /// 当前累计值对应的最高已解锁等级
  int levelForValue(int value) {
    int level = 0;
    for (final threshold in thresholds) {
      if (value >= threshold) {
        level++;
      } else {
        break;
      }
    }
    return level;
  }
}

/// 成就升级事件参数
class AchievementLevelUpEventArgs extends EventArgs {
  final String achievementId;
  final String name;

  /// 本等级具体完成的事项（如「累计发送频道消息 100 条」）
  final String condition;

  final String iconAsset;
  final int level;
  final DateTime unlockedAt;
  final int points;

  AchievementLevelUpEventArgs({
    required this.achievementId,
    required this.name,
    required this.condition,
    required this.iconAsset,
    required this.level,
    required this.unlockedAt,
    required this.points,
  }) : super('achievement_level_up');
}
