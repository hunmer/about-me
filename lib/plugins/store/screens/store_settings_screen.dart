import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/store/screens/store_event_switches_screen.dart';
import 'package:aboutme/plugins/store/store_plugin.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/form_fields/event_multi_select_field.dart';
import 'package:universal_platform/universal_platform.dart';

/// Store 插件设置界面
class StoreSettingsScreen extends StatefulWidget {
  final PluginBase plugin;

  const StoreSettingsScreen({super.key, required this.plugin});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // 选中的事件列表
  List<String> _selectedEvents = [];

  // 积分奖励设置
  final Map<String, int> _pointAwards = {};
  final Map<String, TextEditingController> _controllers = {};
  // 各事件输入框的校验错误文案（DSInput 经 errorText 展示）
  final Map<String, String?> _inputErrors = {};

  // 今日目标积分
  int _dailyTarget = 50;
  late final TextEditingController _dailyTargetController =
      TextEditingController();

  // 其他设置
  bool _enablePointsNotification = true; // 积分变动通知
  bool _enableExpiringReminder = true; // 到期提醒

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    // 释放所有控制器
    _dailyTargetController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 文本改变回调 - 实时保存
  void _onTextChanged(String eventKey) {
    _savePointAwards();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 释放旧控制器并清空旧状态（子页面开关事件后重载时避免泄漏）
      for (var controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();
      _pointAwards.clear();
      _selectedEvents = [];
      _inputErrors.clear();

      final settings = widget.plugin.settings;
      final pointAwards = settings['point_awards'] as Map<String, dynamic>?;

      if (pointAwards != null) {
        // 加载积分奖励设置和选中的事件
        pointAwards.forEach((key, value) {
          // 只加载积分值大于 0 的事件
          if (value is int && value > 0) {
            _pointAwards[key] = value;
            _selectedEvents.add(key);
            final controller = TextEditingController(text: value.toString());
            controller.addListener(() => _onTextChanged(key));
            _controllers[key] = controller;
          }
        });
      }

      // 今日目标积分
      _dailyTarget = settings['dailyPointsTarget'] as int? ?? 50;
      _dailyTargetController.text = _dailyTarget.toString();

      // 加载其他设置
      _enablePointsNotification =
          settings['enablePointsNotification'] as bool? ?? true;
      _enableExpiringReminder =
          settings['enableExpiringReminder'] as bool? ?? true;
    } catch (e) {
      _showError('加载设置失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 保存今日目标积分
  Future<void> _saveDailyTarget(int target) async {
    if (_dailyTarget == target) return;
    _dailyTarget = target;
    try {
      await widget.plugin.updateSettings({'dailyPointsTarget': target});
    } catch (e) {
      debugPrint('❌ [Store设置页面] 保存今日目标失败: $e');
    }
  }

  /// 跳转事件开关页，返回后重载设置
  Future<void> _openEventSwitches() async {
    await NavigationHelper.push(
      context,
      StoreEventSwitchesScreen(plugin: widget.plugin),
    );
    if (mounted) {
      _loadSettings();
    }
  }

  /// 保存积分奖励设置（实时保存）
  Future<void> _savePointAwards() async {
    try {
      // 只保存选中事件的积分值
      final newPointAwards = <String, dynamic>{};

      // 为每个选中事件保存积分值
      for (final eventKey in _selectedEvents) {
        final controller = _controllers[eventKey];
        final value =
            controller != null
                ? (int.tryParse(controller.text) ??
                    getDefaultPointsForEvent(eventKey))
                : getDefaultPointsForEvent(eventKey);
        newPointAwards[eventKey] = value;
      }

      await widget.plugin.updateSettings({
        'point_awards': newPointAwards,
        'enablePointsNotification': _enablePointsNotification,
        'enableExpiringReminder': _enableExpiringReminder,
      });
    } catch (e) {
      debugPrint('❌ [Store设置页面] 保存失败: $e');
    }
  }

  /// 获取事件的默认积分值
  int getDefaultPointsForEvent(String eventKey) {
    final defaults =
        StorePlugin.defaultPointSettings['point_awards']
            as Map<String, dynamic>?;
    return defaults?[eventKey] as int? ?? 10;
  }

  /// 从 kDefaultAvailableEvents 获取事件显示名称
  String _getEventDisplayName(String eventKey) {
    final eventOption = kDefaultAvailableEvents.firstWhere(
      (e) => e.eventName == eventKey,
      orElse:
          () => EventOption(
            eventName: eventKey,
            category: '未知',
            description: eventKey,
          ),
    );
    return eventOption.description;
  }

  /// 保存开关设置（不需要表单验证）
  Future<void> _saveSwitchSettings() async {
    try {
      await widget.plugin.updateSettings({
        'enablePointsNotification': _enablePointsNotification,
        'enableExpiringReminder': _enableExpiringReminder,
      });

      debugPrint('🔧 [Store设置页面] 开关设置已自动保存');
    } catch (e) {
      debugPrint('❌ [Store设置页面] 自动保存失败: $e');
      _showError('自动保存失败: $e');
    }
  }

  /// 重置为默认设置
  Future<void> _resetToDefault() async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: '重置设置',
                    message: '确定要重置为默认设置吗？此操作不可撤销。',
                    cancelText: '取消',
                    confirmText: '确定',
                    onCancel: () => Navigator.of(context).pop(false),
                    onConfirm: () => Navigator.of(context).pop(true),
                  ),
            ),
          ),
    );

    if (confirmed == true) {
      try {
        await widget.plugin.updateSettings(StorePlugin.defaultPointSettings);
        await _loadSettings();
        if (mounted) {
          toastService.showToast('已重置为默认设置');
        }
      } catch (e) {
        _showError('重置设置失败: $e');
      }
    }
  }

  /// 显示错误
  void _showError(String message) {
    if (!mounted) return;
    toastService.showToast(message);
  }

  /// 校验积分输入，返回错误文案（null 表示通过）
  String? _validatePoints(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入积分值';
    }
    final points = int.tryParse(value);
    if (points == null || points < 0) {
      return '必须为非负整数';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('store_storeSettings'.tr),
        actions: [
          // 重置按钮
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.refresh,
                  size: 38,
                  color: theme.surface,
                  iconColor: theme.text,
                  tooltip: '重置为默认设置',
                  onPressed: _resetToDefault,
                );
              },
            ),
          ),
        ],
      ),
      body: DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 通知设置 - 仅在移动端平台显示
                  if (UniversalPlatform.isIOS ||
                      UniversalPlatform.isAndroid) ...[
                    // 通知设置标题
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        '通知设置',
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                    ),

                    // 积分变动通知开关
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: DSCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'store_enablePointsNotification'.tr,
                                    style: DsTypography.body.copyWith(
                                      color: theme.text,
                                    ),
                                  ),
                                  Text(
                                    'store_enablePointsNotificationDescription'
                                        .tr,
                                    style: DsTypography.caption.copyWith(
                                      color: theme.textSub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DSSwitch(
                              value: _enablePointsNotification,
                              onChanged: (value) {
                                setState(() {
                                  _enablePointsNotification = value;
                                });
                                _saveSwitchSettings(); // 自动保存
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 到期提醒开关
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: DSCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'store_enableExpiringReminder'.tr,
                                    style: DsTypography.body.copyWith(
                                      color: theme.text,
                                    ),
                                  ),
                                  Text(
                                    'store_enableExpiringReminderDescription'
                                        .tr,
                                    style: DsTypography.caption.copyWith(
                                      color: theme.textSub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DSSwitch(
                              value: _enableExpiringReminder,
                              onChanged: (value) {
                                setState(() {
                                  _enableExpiringReminder = value;
                                });
                                _saveSwitchSettings(); // 自动保存
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Container(
                      height: 1,
                      color: theme.stroke.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // 积分奖励设置标题
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'store_pointsAwardSection'.tr,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                  ),

                  // 事件开关入口菜单：跳转到新页面直接展示所有事件 + switch
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: DSCard(
                      onTap: _openEventSwitches,
                      child: Row(
                        children: [
                          DsIcon(DsIconKind.tune, color: theme.text),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'store_eventSwitchesEntry'.tr,
                                  style: DsTypography.body.copyWith(
                                    color: theme.text,
                                  ),
                                ),
                                Text(
                                  'store_eventSwitchesEntryDesc'.tr,
                                  style: DsTypography.caption.copyWith(
                                    color: theme.textSub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          DsIcon(
                            DsIconKind.chevronRight,
                            color: theme.textSub,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 今日目标积分
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: DSCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'store_dailyTargetLabel'.tr,
                                  style: DsTypography.body.copyWith(
                                    color: theme.text,
                                  ),
                                ),
                                Text(
                                  'store_dailyTargetDesc'.tr,
                                  style: DsTypography.caption.copyWith(
                                    color: theme.textSub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 96,
                            child: DSInput(
                              controller: _dailyTargetController,
                              keyboardType: TextInputType.number,
                              hint: _dailyTarget.toString(),
                              suffix: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  'store_points'.tr,
                                  style: DsTypography.caption.copyWith(
                                    color: theme.textSub,
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                final target = int.tryParse(value);
                                if (target != null && target > 0) {
                                  _saveDailyTarget(target);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 积分奖励表单
                  if (_isLoading)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: DSLoadingDots(),
                      ),
                    )
                  else if (_selectedEvents.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'store_noEventsEnabled'.tr,
                          textAlign: TextAlign.center,
                          style: DsTypography.body.copyWith(
                            color: theme.textSub,
                          ),
                        ),
                      ),
                    )
                  else
                    Form(
                      key: _formKey,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children:
                              _selectedEvents.map((eventKey) {
                                final displayName = _getEventDisplayName(
                                  eventKey,
                                );
                                final controller = _controllers[eventKey];

                                // 如果没有控制器，创建一个默认的
                                if (controller == null) {
                                  _controllers[eventKey] =
                                      TextEditingController(
                                        text:
                                            getDefaultPointsForEvent(
                                              eventKey,
                                            ).toString(),
                                      );
                                  _controllers[eventKey]?.addListener(
                                    () => _onTextChanged(eventKey),
                                  );
                                }

                                final effectiveController =
                                    _controllers[eventKey]!;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          displayName,
                                          style: DsTypography.body.copyWith(
                                            color: theme.text,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: DSInput(
                                          controller: effectiveController,
                                          keyboardType: TextInputType.number,
                                          hint: '0',
                                          errorText: _inputErrors[eventKey],
                                          suffix: Padding(
                                            padding: const EdgeInsets.only(
                                              left: 4,
                                            ),
                                            child: Text(
                                              'store_points'.tr,
                                              style: DsTypography.caption
                                                  .copyWith(
                                                    color: theme.textSub,
                                                  ),
                                            ),
                                          ),
                                          onChanged: (value) {
                                            // DSInput 无 Form 校验，手动校验并展示错误
                                            final error = _validatePoints(
                                              value,
                                            );
                                            if (_inputErrors[eventKey] !=
                                                error) {
                                              setState(() {
                                                _inputErrors[eventKey] = error;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
