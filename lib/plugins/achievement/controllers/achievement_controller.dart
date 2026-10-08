import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/achievement/data/achievement_definitions.dart';
import 'package:aboutme/plugins/achievement/models/achievement_definition.dart';
import 'package:aboutme/plugins/base_plugin.dart';
import 'package:aboutme/plugins/store/store_plugin.dart';

/// 单个成就系列的运行时进度
class AchievementProgress {
  /// 当前累计值
  int value;

  /// 已解锁的最高等级（0 = 未解锁）
  int unlockedLevel;

  /// 各等级获得时间（长度 = maxLevel，未解锁为 null）
  List<DateTime?> unlockedDates;

  /// 通过成就累计获得的积分
  int earnedPoints;

  AchievementProgress({
    this.value = 0,
    this.unlockedLevel = 0,
    List<DateTime?>? unlockedDates,
    this.earnedPoints = 0,
  }) : unlockedDates = unlockedDates ?? [];

  Map<String, dynamic> toJson() => {
        'value': value,
        'unlockedLevel': unlockedLevel,
        'unlockedDates': unlockedDates.map((d) => d?.toIso8601String()).toList(),
        'earnedPoints': earnedPoints,
      };

  factory AchievementProgress.fromJson(Map<String, dynamic> json) {
    return AchievementProgress(
      value: (json['value'] as num?)?.toInt() ?? 0,
      unlockedLevel: (json['unlockedLevel'] as num?)?.toInt() ?? 0,
      unlockedDates: (json['unlockedDates'] as List<dynamic>?)
              ?.map((d) => d == null ? null : DateTime.tryParse(d.toString()))
              .toList() ??
          [],
      earnedPoints: (json['earnedPoints'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 成就控制器：进度存储 + 事件结算 + 升级发放积分
class AchievementController extends ChangeNotifier {
  AchievementController(this.plugin);

  final BasePlugin plugin;

  static const String _storageKey = 'achievement/progress.json';

  /// 事件总线信号 → 成就编号（其余成就等待后续数据源接入）
  static const Map<String, String> _eventToAchievement = {
    'chat_message_sent': 'A01',
    'diary_entry_created': 'A14',
    'activity_added': 'A17',
    'checkin_completed': 'A23',
    'task_completed': 'A26',
    'note_added': 'A29',
    'bill_added': 'A42',
    'goods_item_added': 'A45',
    'onRecordAdded': 'A55',
  };

  final Map<String, AchievementProgress> _progress = {};

  /// 已订阅的事件名（dispose 时反订阅）
  final List<String> _subscribedEvents = [];

  bool _isInitialized = false;

  // ========== 统计 ==========

  /// 全部成就总级数
  int get totalLevels => kAchievementDefinitions.fold(0, (sum, d) => sum + d.maxLevel);

  /// 已解锁总级数
  int get unlockedLevels => _progress.values.fold(0, (sum, p) => sum + p.unlockedLevel);

  /// 已解锁级数占比（0~1）
  double get overallProgress => totalLevels == 0 ? 0 : unlockedLevels / totalLevels;

  /// 通过成就累计获得的积分
  int get totalEarnedPoints => _progress.values.fold(0, (sum, p) => sum + p.earnedPoints);

  /// 最近一次达成时间（无则 null）
  DateTime? get lastUnlockedAt {
    DateTime? latest;
    for (final p in _progress.values) {
      for (final d in p.unlockedDates) {
        if (d != null && (latest == null || d.isAfter(latest))) {
          latest = d;
        }
      }
    }
    return latest;
  }

  // ========== 存取 ==========

  AchievementProgress progressOf(String id) => _progress.putIfAbsent(id, () => AchievementProgress());

  /// 第 level 级（1 起）的获得时间
  DateTime? unlockedDateOf(String id, int level) {
    final p = progressOf(id);
    return level >= 1 && level <= p.unlockedDates.length ? p.unlockedDates[level - 1] : null;
  }

  // ========== 初始化 ==========

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadFromStorage();
    _subscribeEvents();
    _isInitialized = true;
  }

  Future<void> _loadFromStorage() async {
    try {
      final data = await plugin.storage.read(_storageKey);
      if (data is Map<String, dynamic>) {
        data.forEach((id, value) {
          if (value is Map && kAchievementById.containsKey(id)) {
            _progress[id] = AchievementProgress.fromJson(Map<String, dynamic>.from(value));
          }
        });
      }
    } catch (e) {
      debugPrint('[Achievement] 读取进度失败: $e');
    }
  }

  Future<void> _save() async {
    try {
      await plugin.storage.write(
        _storageKey,
        _progress.map((id, p) => MapEntry(id, p.toJson())),
      );
    } catch (e) {
      debugPrint('[Achievement] 保存进度失败: $e');
    }
  }

  void _subscribeEvents() {
    final eventManager = EventManager.instance;
    for (final eventName in _eventToAchievement.keys) {
      eventManager.subscribe(eventName, _onEvent);
      _subscribedEvents.add(eventName);
    }
  }

  void _onEvent(EventArgs args) {
    final achievementId = _eventToAchievement[args.eventName];
    if (achievementId != null) {
      recordProgress(achievementId, 1);
    }
  }

  // ========== 结算 ==========

  /// 记录进度增量并结算升级，返回本次新解锁的等级列表（供弹窗）
  Future<List<AchievementLevelUpEventArgs>> recordProgress(String achievementId, int delta) async {
    final def = kAchievementById[achievementId];
    if (def == null || delta <= 0) return [];

    final progress = progressOf(achievementId);
    while (progress.unlockedDates.length < def.maxLevel) {
      progress.unlockedDates.add(null);
    }

    progress.value += delta;
    final newLevel = def.levelForValue(progress.value);

    final unlocked = <AchievementLevelUpEventArgs>[];
    for (int level = progress.unlockedLevel + 1; level <= newLevel; level++) {
      final now = DateTime.now();
      progress.unlockedDates[level - 1] = now;
      final points = def.rewardFor(level);
      progress.earnedPoints += points;

      final args = AchievementLevelUpEventArgs(
        achievementId: def.id,
        name: def.name,
        iconAsset: def.iconAsset,
        level: level,
        unlockedAt: now,
        points: points,
      );
      unlocked.add(args);

      // 广播升级事件（弹窗、小组件等订阅方自行消费）
      EventManager.instance.broadcast('achievement_level_up', args);
      debugPrint('[Achievement] ${def.name} 升级 Lv$level (+$points 分)');

      // 发放积分奖励（store 未就绪时跳过，不阻塞成就记录）
      await _awardPoints(points, '成就:${def.name} Lv$level');
    }

    if (newLevel > progress.unlockedLevel || delta > 0) {
      progress.unlockedLevel = newLevel;
      await _save();
      notifyListeners();
    }
    return unlocked;
  }

  Future<void> _awardPoints(int points, String reason) async {
    if (points <= 0) return;
    try {
      final storePlugin = PluginManager.instance.getPlugin('store_plugin');
      if (storePlugin is StorePlugin) {
        await storePlugin.controller.addPoints(points, reason);
      }
    } catch (e) {
      debugPrint('[Achievement] 积分发放失败: $e');
    }
  }

  // ========== 调试 ==========

  /// 手动把某成就推到指定等级（调试/演示用；从当前值对齐到该级阈值）
  Future<void> debugUnlockTo(String achievementId, int level) async {
    final def = kAchievementById[achievementId];
    if (def == null) return;
    final target = level <= 0 ? 0 : def.thresholds[level - 1];
    final progress = progressOf(achievementId);
    if (target > progress.value) {
      await recordProgress(achievementId, target - progress.value);
    }
  }

  @override
  void dispose() {
    final eventManager = EventManager.instance;
    for (final eventName in _subscribedEvents) {
      eventManager.unsubscribe(eventName, _onEvent);
    }
    _subscribedEvents.clear();
    super.dispose();
  }
}
