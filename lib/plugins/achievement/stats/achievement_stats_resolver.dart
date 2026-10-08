import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/services/timer/events/timer_events.dart';
import 'package:aboutme/plugins/achievement/controllers/achievement_controller.dart';
import 'package:aboutme/plugins/achievement/stats/achievement_stats_providers.dart';

/// 成就快照结算器（仅手动刷新模式）
///
/// 稳态运行时实时计数全部由 [AchievementController] 的事件通道完成（O(1)，
/// 删除源数据不回退），启动时不做任何快照扫描；本结算器只在
/// **打开成就界面**时全量快照一遍（用户主动行为，异步不阻塞渲染），
/// 用于校正无事件通道的成就（频道数、模型数等）与历史存量。
///
/// 另负责 A59 开始计时的完成事件计数（需按来源插件过滤，无法走通用映射）。
class AchievementStatsResolver {
  AchievementStatsResolver(this._controller);

  final AchievementController _controller;

  Map<String, (String, StatProvider)> _providers = {};

  bool _resolving = false;
  bool _disposed = false;

  Future<void> initialize() async {
    _providers = buildStatProviders();

    // A59 开始计时：统一计时器完成事件（仅 timer 插件来源计数）
    EventManager.instance.subscribe(TimerEventNames.timerCompleted, _onUnifiedTimerCompleted);
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

  /// 全量快照刷新（打开成就页触发）：幂等（max 语义，只增不减），不重复发分
  Future<void> resolveAll() async {
    if (_disposed || _resolving) return;
    _resolving = true;
    try {
      final settled = <String>{};

      for (final entry in _providers.entries) {
        final value = await entry.value.$2();
        if (value != null) {
          settled.add(entry.key);
          await _controller.setProgressValue(entry.key, value);
        }
      }

      // 跨插件记录天数（A72 全方位记录 / A73 百日筑基）
      final stats = await collectRecordDayStats();
      if (stats != null) {
        await _controller.setProgressValue('A72', stats.allFourDays);
        await _controller.setProgressValue('A73', stats.anyRecordStreak);
      }

      // A71 全能启动：本轮成功取到数据的来源插件个数
      // （部分插件未就绪时偏小；计数只增不减，下次打开页面会补齐）
      final usedPlugins = <String>{};
      for (final id in settled) {
        usedPlugins.add(_providers[id]!.$1);
      }
      await _controller.setProgressValue('A71', usedPlugins.length);
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
