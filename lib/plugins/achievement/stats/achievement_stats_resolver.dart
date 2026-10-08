import 'dart:async';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/services/timer/events/timer_events.dart';
import 'package:aboutme/plugins/achievement/controllers/achievement_controller.dart';
import 'package:aboutme/plugins/achievement/stats/achievement_stats_providers.dart';

/// 成就快照结算器（回填 + 手动刷新模式）
///
/// 稳态运行时实时计数全部由 [AchievementController] 的事件通道完成（O(1)，
/// 删除源数据不回退），本结算器只负责两件事：
///
/// 1. **一次性回填**：启动后延迟对「尚未回填」的成就跑一次各插件数据快照，
///    把历史存量补进自计数（持久化 backfilled 标志，此后启动零快照开销）；
/// 2. **手动刷新**：打开成就页时全量快照一遍（用户主动行为，异步不阻塞渲染），
///    用于校正无事件通道的存量型成就（频道数、模型数等）。
///
/// 另负责 A59 开始计时的完成事件计数（需按来源插件过滤，无法走通用映射）。
class AchievementStatsResolver {
  AchievementStatsResolver(this._controller);

  final AchievementController _controller;

  /// 跨插件记录天数结算涉及的成就
  static const Set<String> _dayCompositeIds = {'A72', 'A73'};

  Map<String, (String, StatProvider)> _providers = {};

  bool _resolving = false;
  bool _disposed = false;

  Future<void> initialize() async {
    _providers = buildStatProviders();

    // A59 开始计时：统一计时器完成事件（仅 timer 插件来源计数）
    EventManager.instance.subscribe(TimerEventNames.timerCompleted, _onUnifiedTimerCompleted);

    // 启动后延迟回填：等所有插件就绪并完成首屏加载，且仅补尚未回填的成就
    Timer(const Duration(seconds: 8), () {
      if (!_disposed) backfillMissing();
    });
  }

  void _onUnifiedTimerCompleted(EventArgs args) {
    // UnifiedTimerEventArgs.timerState 为动态类型，按动态解包避免硬依赖具体 TimerState 类型
    try {
      final dynamic state = (args as dynamic).timerState;
      if (state == null || state.pluginId != 'timer') return;
      _controller.recordProgress('A59', 1);
    } catch (_) {
      // 事件参数结构不符时忽略
    }
  }

  /// 首次回填：只结算尚未回填过的成就，成功后统一标记持久化
  Future<void> backfillMissing() async {
    final pending = _providers.keys
        .where((id) => !_controller.isBackfilled(id))
        .toSet();
    if (pending.isEmpty) return;
    final settled = await _resolve(pending);
    await _controller.markBackfilled(settled);
  }

  /// 全量快照刷新（打开成就页触发；顺手补齐未完成的回填标记）
  Future<void> resolveAll() async {
    final settled = await _resolve({..._providers.keys, 'A71', 'A72', 'A73'});
    await _controller.markBackfilled(
        settled.where((id) => _providers.containsKey(id)));
  }

  /// 逐个执行快照取数并结算（幂等：max 语义，只增不减），返回成功取数的成就集
  Future<Set<String>> _resolve(Set<String> achievementIds) async {
    if (_disposed) return const {};
    // 进行中时直接跳过（打开页面高频触发场景下避免排队堆积；
    // 刷新是幂等校正，晚一轮执行无影响）
    if (_resolving) return const {};
    _resolving = true;
    try {
      final settled = <String>{};
      final dayComposite = _dayCompositeIds.intersection(achievementIds).isNotEmpty;

      for (final id in achievementIds) {
        final entry = _providers[id];
        if (entry == null) continue;
        final value = await entry.$2();
        if (value != null) {
          settled.add(id);
          await _controller.setProgressValue(id, value);
        }
      }

      // 跨插件记录天数（A72 全方位记录 / A73 百日筑基）
      if (dayComposite) {
        final stats = await collectRecordDayStats();
        if (stats != null) {
          await _controller.setProgressValue('A72', stats.allFourDays);
          await _controller.setProgressValue('A73', stats.anyRecordStreak);
        }
      }

      // A71 全能启动：本轮成功取到数据的来源插件个数
      // （只统计取数成功的 provider，部分插件未就绪时偏小；计数只增不减，后续轮次会补齐）
      if (achievementIds.contains('A71')) {
        final usedPlugins = <String>{};
        for (final id in settled) {
          final provider = _providers[id];
          if (provider != null) {
            usedPlugins.add(provider.$1);
          }
        }
        await _controller.setProgressValue('A71', usedPlugins.length);
      }

      return settled;
    } finally {
      _resolving = false;
    }
  }

  void dispose() {
    _disposed = true;
    EventManager.instance.unsubscribe(
        TimerEventNames.timerCompleted, _onUnifiedTimerCompleted);
  }
}
