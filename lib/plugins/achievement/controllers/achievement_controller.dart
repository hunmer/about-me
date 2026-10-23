import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/event_args.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/achievement/data/achievement_definitions.dart';
import 'package:aboutme/plugins/achievement/models/achievement_definition.dart';
import 'package:aboutme/plugins/base_plugin.dart';
import 'package:aboutme/plugins/store/store_plugin.dart';

/// 单个成就系列的运行时进度
class AchievementProgress {
  /// 当前累计值（自维护计数：事件增量累加，删除源数据不回退）
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

/// 成就控制器：进度存储 + 事件/快照双通道结算 + 升级发放积分
///
/// 结算通道：
/// - 事件增量（recordProgress）：流水型行为（发消息、打卡…）
/// - 数据快照（setProgressValue）：存量统计（频道数、节点数…），只增不减
class AchievementController extends ChangeNotifier {
  AchievementController(this.plugin);

  final BasePlugin plugin;

  static const String _storageKey = 'achievement/progress.json';

  /// 事件总线信号 → 成就编号（自计数增量，O(1)，删除源数据不影响计数）。
  ///
  /// 「xx_added/created」类事件对应文档「累计创建」口径，天然只增；
  /// 携带 `Value<int>` 载荷的事件按数值增量累加（如时长分钟数、照片张数）。
  static const Map<String, String> _eventToAchievement = {
    // 流水型
    'chat_message_sent': 'A01',
    'diary_entry_created': 'A14',
    'activity_added': 'A17',
    'checkin_completed': 'A23',
    'task_completed': 'A26',
    'note_added': 'A29',
    'bill_added': 'A42',
    'goods_item_added': 'A45',
    'onRecordAdded': 'A55',
    // 创建型（累计创建口径）
    'chat_channel_added': 'A02',
    'openai_agent_added': 'A08',
    'prompt_preset_added': 'A09',
    'moment_posted': 'A10',
    'live2d_model_added': 'A12',
    'task_added': 'A28',
    'nodes_node_added': 'A31',
    'memorial_day_added': 'A34',
    'calendar_event_added': 'A36',
    'account_added': 'A44',
    'contact_created': 'A51',
    'contact_interaction_added': 'A52',
    'database_added': 'A56',
    'database_record_added': 'A57',
    'checkin_item_added': 'A25',
    'note_folder_added': 'A30',
    'reminder_added': 'A40',
    'goods_warehouse_added': 'A46',
    // 行为型埋点
    'tts_spoken': 'A61',
    'live2d_tts_spoken': 'A13',
    'agent_chat_user_message': 'A05',
    'agent_chat_tool_called': 'A07',
    'tracker_goal_completed': 'A54',
    'node_status_done': 'A32',
    'webview_card_opened': 'A65',
    'script_executed': 'A68',
    // 带数值增量（Value<int>）
    'goods_usage_recorded': 'A47',
    'activity_duration_added': 'A18',
    'album_photo_added': 'A38',
  };

  /// 事件 → 成就（max 语义）：载荷为「当前值」，按快照峰值结算（只增不减）
  static const Map<String, String> _eventToAchievementMax = {
    'webview_tab_created': 'A67', // 同时打开标签页数
  };

  final Map<String, AchievementProgress> _progress = {};

  /// 事件 → 计数处理器（订阅时闭包捕获事件名：EventManager.broadcast
  /// 不会回填 args.eventName，不能依赖事件参数还原事件名）
  final Map<String, Function(EventArgs)> _countingHandlers = {};

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

  /// A74 深度玩家的数值 = 除自身外已解锁的成就级数
  int get deepPlayerValue =>
      unlockedLevels - progressOf('A74').unlockedLevel;

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

    final eventManager = EventManager.instance;

    void registerCounting(String eventName) {
      // 闭包捕获事件名，处理时不再依赖 args.eventName
      void handler(EventArgs args) => _onCountingEvent(eventName, args);
      _countingHandlers[eventName] = handler;
      eventManager.subscribe(eventName, handler);
    }

    for (final eventName in _eventToAchievement.keys) {
      registerCounting(eventName);
    }
    for (final eventName in _eventToAchievementMax.keys) {
      registerCounting(eventName);
    }

    // A48 第一桶金：积分变动后按累计获得积分结算
    eventManager.subscribe('store_cache_updated', _onStoreCacheUpdated);

    _isInitialized = true;
    _recomputeDeepPlayer();
  }

  Future<void> _loadFromStorage() async {
    try {
      final data = await AboutmeDataService.instance.readPath(_storageKey);
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
      await AboutmeDataService.instance.writePath(
        _storageKey,
        _progress.map((id, p) => MapEntry(id, p.toJson())),
      );
    } catch (e) {
      debugPrint('[Achievement] 保存进度失败: $e');
    }
  }

  void _onCountingEvent(String eventName, EventArgs args) {
    // max 语义通道：载荷为当前值，按峰值快照结算
    final maxId = _eventToAchievementMax[eventName];
    if (maxId != null) {
      if (args is Value && args.value is int) {
        setProgressValue(maxId, args.value as int);
      }
      return;
    }

    final achievementId = _eventToAchievement[eventName];
    if (achievementId == null) return;

    // 携带正整数载荷时按数值增量，否则 +1
    if (args is Value && args.value is int && (args.value as int) > 0) {
      recordProgress(achievementId, args.value as int);
    } else {
      recordProgress(achievementId, 1);
    }
  }

  Future<void> _onStoreCacheUpdated(EventArgs args) async {
    try {
      final storePlugin = PluginManager.instance.getPlugin('store_plugin');
      if (storePlugin is! StorePlugin) return;
      final earned = storePlugin.controller.pointsLogs
          .where((log) => log.type == '获得')
          .fold<int>(0, (sum, log) => sum + log.value);
      await setProgressValue('A48', earned);
    } catch (_) {
      // store 未就绪时忽略
    }
  }

  // ========== 结算 ==========

  /// 事件增量结算：value += delta，返回本次新解锁等级的事件列表
  Future<List<AchievementLevelUpEventArgs>> recordProgress(String achievementId, int delta) async {
    final def = kAchievementById[achievementId];
    if (def == null || delta <= 0) return [];
    final progress = progressOf(achievementId);
    return _settle(def, progress, progress.value + delta);
  }

  /// 快照结算：value = max(当前值, 快照值)，返回本次新解锁等级的事件列表
  ///
  /// 用于从各插件数据统计出的存量数值（频道数、节点数…），数据被删除时成就不回退。
  Future<List<AchievementLevelUpEventArgs>> setProgressValue(String achievementId, int value) async {
    final def = kAchievementById[achievementId];
    if (def == null) return [];
    final progress = progressOf(achievementId);
    if (value <= progress.value) return [];
    return _settle(def, progress, value);
  }

  Future<List<AchievementLevelUpEventArgs>> _settle(
    AchievementDefinition def,
    AchievementProgress progress,
    int newValue,
  ) async {
    while (progress.unlockedDates.length < def.maxLevel) {
      progress.unlockedDates.add(null);
    }

    progress.value = newValue;
    final newLevel = def.levelForValue(newValue);

    final unlocked = <AchievementLevelUpEventArgs>[];
    for (int level = progress.unlockedLevel + 1; level <= newLevel; level++) {
      final now = DateTime.now();
      progress.unlockedDates[level - 1] = now;
      final points = pointsForLevel(level);
      progress.earnedPoints += points;

      final args = AchievementLevelUpEventArgs(
        achievementId: def.id,
        name: def.name,
        condition: '${def.condition} ${def.thresholds[level - 1]}${def.unit}',
        iconAsset: def.iconAsset,
        level: level,
        unlockedAt: now,
        points: points,
      );
      unlocked.add(args);

      // 广播升级事件（弹窗、小组件等订阅方自行消费）
      EventManager.instance.broadcast('achievement_level_up', args);
      debugPrint('[Achievement] ${def.name} 升级 Lv$level (+$points 分)');

      // 发放积分奖励（store 未就绪时跳过，不阻塞成就记录）；
      // 按成就+等级生成幂等键，重试/重复触发只入账一次
      await _awardPoints(
        points,
        '成就:${def.name} Lv$level',
        mutationKey: 'store:award:achievement:${def.id}:Lv$level',
      );
    }

    progress.unlockedLevel = newLevel;
    if (unlocked.isNotEmpty) {
      await _save();
      // 任何升级都可能推进 A74 深度玩家
      await _recomputeDeepPlayer();
      notifyListeners();
    }
    return unlocked;
  }

  /// A74 深度玩家：累计解锁的成就级数（不含自身）
  Future<void> _recomputeDeepPlayer() async {
    await setProgressValue('A74', deepPlayerValue);
  }

  /// 某等级的积分奖励：优先取 store 积分设置（可在商店设置中调整），缺省用默认表
  int pointsForLevel(int level) {
    try {
      final storePlugin = PluginManager.instance.getPlugin('store_plugin');
      if (storePlugin is StorePlugin) {
        final configured = storePlugin.pointAwardSettings['achievement_Lv$level'];
        if (configured != null && configured > 0) return configured;
      }
    } catch (_) {
      // store 未初始化时用默认值
    }
    return AchievementLevels.rewardPoints[level - 1];
  }

  Future<void> _awardPoints(int points, String reason,
      {String? mutationKey}) async {
    if (points <= 0) return;
    try {
      final storePlugin = PluginManager.instance.getPlugin('store_plugin');
      if (storePlugin is StorePlugin) {
        await storePlugin.controller.addPoints(
          points,
          reason,
          clientMutationId: mutationKey,
        );
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
    _countingHandlers.forEach((eventName, handler) {
      eventManager.unsubscribe(eventName, handler);
    });
    _countingHandlers.clear();
    eventManager.unsubscribe('store_cache_updated', _onStoreCacheUpdated);
    super.dispose();
  }
}
