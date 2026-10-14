import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/store/store_plugin.dart';
import 'package:aboutme/widgets/form_fields/event_multi_select_field.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 奖励事件开关页：按分类列出所有支持的事件，直接以开关启用/停用积分奖励
class StoreEventSwitchesScreen extends StatefulWidget {
  final PluginBase plugin;

  const StoreEventSwitchesScreen({super.key, required this.plugin});

  @override
  State<StoreEventSwitchesScreen> createState() =>
      _StoreEventSwitchesScreenState();
}

class _StoreEventSwitchesScreenState extends State<StoreEventSwitchesScreen> {
  Map<String, int> _awards = {};

  @override
  void initState() {
    super.initState();
    _loadAwards();
  }

  void _loadAwards() {
    final pointAwards =
        widget.plugin.settings['point_awards'] as Map<String, dynamic>? ?? {};
    setState(() {
      _awards = pointAwards.map(
        (key, value) => MapEntry(key, value is int ? value : 0),
      );
    });
  }

  bool _isEnabled(String eventName) => (_awards[eventName] ?? 0) > 0;

  int _defaultPoints(String eventName) {
    final defaults =
        StorePlugin.defaultPointSettings['point_awards']
            as Map<String, dynamic>?;
    return defaults?[eventName] as int? ?? 10;
  }

  /// 开关事件奖励：开启写入默认积分值，关闭移除
  Future<void> _onToggle(String eventName, bool value) async {
    final newAwards = Map<String, dynamic>.from(_awards);
    if (value) {
      newAwards[eventName] = _defaultPoints(eventName);
    } else {
      newAwards.remove(eventName);
    }

    setState(() {
      _awards = newAwards.map(
        (key, value) => MapEntry(key, value is int ? value : 0),
      );
    });

    await widget.plugin.updateSettings({'point_awards': newAwards});
  }

  /// 按分类分组（保持 kDefaultAvailableEvents 中的出现顺序）
  Map<String, List<EventOption>> _groupedByCategory() {
    final grouped = <String, List<EventOption>>{};
    for (final option in kDefaultAvailableEvents) {
      grouped.putIfAbsent(option.category, () => []).add(option);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return SuperCupertinoNavigationWrapper(
      title: Text('store_eventSwitchesTitle'.tr),
      largeTitle: 'store_eventSwitchesTitle'.tr,
      body: DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            final grouped = _groupedByCategory();

            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'store_eventSwitchesSubtitle'.tr,
                    style: DsTypography.body.copyWith(color: theme.textSub),
                  ),
                ),
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Text(
                      entry.key,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                  ),
                  DSCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < entry.value.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              color: theme.stroke.withValues(alpha: 0.4),
                            ),
                          _buildEventRow(context, entry.value[i]),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEventRow(BuildContext context, EventOption option) {
    final theme = DSThemeBridge.resolve(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.description,
                  style: DsTypography.body.copyWith(color: theme.text),
                ),
                Text(
                  option.eventName,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ],
            ),
          ),
          DSSwitch(
            value: _isEnabled(option.eventName),
            onChanged: (value) => _onToggle(option.eventName, value),
          ),
        ],
      ),
    );
  }
}
