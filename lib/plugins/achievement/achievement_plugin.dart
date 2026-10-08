import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:aboutme/core/config_manager.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/achievement/controllers/achievement_controller.dart';
import 'package:aboutme/plugins/achievement/models/achievement_definition.dart';
import 'package:aboutme/plugins/achievement/screens/achievement_gallery_screen.dart';
import 'package:aboutme/plugins/achievement/stats/achievement_stats_resolver.dart';
import 'package:aboutme/plugins/achievement/widgets/achievement_unlock_dialog.dart';
import 'package:aboutme/plugins/base_plugin.dart';

/// 成就插件主视图
class AchievementMainView extends StatelessWidget {
  const AchievementMainView({super.key, required this.controller});

  final AchievementController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: const AchievementGalleryScreen(),
    );
  }
}

/// 成就系统插件
///
/// 职责：进度存储、事件结算、升级发积分、达成弹窗、成就展览界面。
/// 定义见 docs/ACHIEVEMENT_SYSTEM_PLAN.md
class AchievementPlugin extends BasePlugin {
  static AchievementPlugin? _instance;

  static AchievementPlugin get instance {
    if (_instance == null) {
      _instance = PluginManager.instance.getPlugin('achievement')
          as AchievementPlugin?;
      if (_instance == null) {
        throw StateError('AchievementPlugin has not been initialized');
      }
    }
    return _instance!;
  }

  late AchievementController _controller;
  bool _isInitialized = false;

  @override
  final String id = 'achievement';

  @override
  Color get color => const Color(0xFFE6A817);

  @override
  IconData get icon => Icons.emoji_events_outlined;

  @override
  String? getPluginName(context) => 'achievement_name'.tr;

  @override
  Future<void> initialize() async {
    _controller = AchievementController(this);
    await _controller.initialize();

    // 快照结算器（延迟全量 + 事件防抖重算）
    _statsResolver = AchievementStatsResolver(_controller);
    await _statsResolver!.initialize();

    // 达成成就 → 全局弹窗
    EventManager.instance.subscribe('achievement_level_up', _onLevelUp);

    _isInitialized = true;
    _instance = this;
  }

  AchievementStatsResolver? _statsResolver;

  /// 触发一次全量快照结算（打开成就页时调用，幂等）
  void resolveStats() => _statsResolver?.resolveAll();

  void _onLevelUp(EventArgs args) {
    if (args is AchievementLevelUpEventArgs) {
      AchievementUnlockDialog.enqueue(args);
    }
  }

  /// 供其他模块（小组件、JS API 等）调用的控制器
  AchievementController get controller => _controller;

  @override
  Future<void> registerToApp(
    PluginManager pluginManager,
    ConfigManager configManager,
  ) async {}

  @override
  Widget buildMainView(BuildContext context) {
    return AchievementMainView(controller: _controller);
  }

  @override
  Widget? buildCardView(BuildContext context) {
    if (!_isInitialized) return null;
    final theme = Theme.of(context);
    final unlocked = _controller.unlockedLevels;
    final total = _controller.totalLevels;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                'achievement_name'.tr,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _controller.overallProgress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${'achievement_progressTitle'.tr}: $unlocked/$total ${'achievement_levels'.tr}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> uninstall() async {
    EventManager.instance.unsubscribe('achievement_level_up', _onLevelUp);
    _statsResolver?.dispose();
    _controller.dispose();
    _instance = null;
  }
}
