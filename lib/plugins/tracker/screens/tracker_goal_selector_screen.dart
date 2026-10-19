import 'package:get/get.dart';
import 'dart:convert';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:aboutme/plugins/tracker/tracker_plugin.dart';
import 'package:aboutme/widgets/widget_config_editor/index.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// 目标选择器界面(用于小组件配置)
///
/// 提供实时预览、颜色配置和透明度调节功能。
class TrackerGoalSelectorScreen extends StatefulWidget {
  /// 小组件ID(Android appWidgetId)
  final int? widgetId;

  const TrackerGoalSelectorScreen({super.key, this.widgetId});

  @override
  State<TrackerGoalSelectorScreen> createState() =>
      _TrackerGoalSelectorScreenState();
}

class _TrackerGoalSelectorScreenState extends State<TrackerGoalSelectorScreen> {
  final TrackerPlugin _trackerPlugin = TrackerPlugin.instance;
  String? _selectedGoalId;
  late WidgetConfig _widgetConfig;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 初始化默认配置
    _widgetConfig = WidgetConfig(
      colors: [
        ColorConfig(
          key: 'primary',
          label: 'Background Color',
          defaultValue: Colors.red,
          currentValue: Colors.red,
        ),
        ColorConfig(
          key: 'accent',
          label: 'Accent Color',
          defaultValue: Colors.white,
          currentValue: Colors.white,
        ),
      ],
      opacity: 0.95,
    );
    _loadSavedConfig();
  }

  /// 加载已保存的配置
  Future<void> _loadSavedConfig() async {
    if (widget.widgetId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 加载目标ID
      final savedGoalId = await HomeWidget.getWidgetData<String>(
        'tracker_goal_id_${widget.widgetId}',
      );
      if (savedGoalId != null) {
        _selectedGoalId = savedGoalId;
      }

      // 加载背景色
      final savedColorStr = await HomeWidget.getWidgetData<String>(
        'tracker_widget_primary_color_${widget.widgetId}',
      );
      if (savedColorStr != null) {
        final colorValue = int.tryParse(savedColorStr);
        if (colorValue != null) {
          _widgetConfig = _widgetConfig.updateColor(
            'primary',
            Color(colorValue),
          );
        }
      }

      // 加载强调色
      final savedAccentColorStr = await HomeWidget.getWidgetData<String>(
        'tracker_widget_accent_color_${widget.widgetId}',
      );
      if (savedAccentColorStr != null) {
        final colorValue = int.tryParse(savedAccentColorStr);
        if (colorValue != null) {
          _widgetConfig = _widgetConfig.updateColor(
            'accent',
            Color(colorValue),
          );
        }
      }

      // 加载透明度
      final savedOpacityStr = await HomeWidget.getWidgetData<String>(
        'tracker_widget_opacity_${widget.widgetId}',
      );
      if (savedOpacityStr != null) {
        final opacity = double.tryParse(savedOpacityStr);
        if (opacity != null) {
          _widgetConfig = _widgetConfig.copyWith(opacity: opacity);
        }
      }
    } catch (e) {
      debugPrint('加载配置失败: $e');
    }

    setState(() => _isLoading = false);
  }

  /// 获取选中的目标
  Goal? _getSelectedGoal() {
    if (_selectedGoalId == null) return null;
    try {
      return _trackerPlugin.controller.goals.firstWhere(
        (goal) => goal.id == _selectedGoalId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: const Center(
          child: DSThemeBridge(child: Center(child: DSLoadingDots())),
        ),
      );
    }

    final goals = _trackerPlugin.controller.goals;

    return Scaffold(
      appBar: AppBar(
        title: Text('tracker_configureGoalTrackingWidget'.tr),
        leading: DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.close,
                size: 40,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                onPressed: () => Navigator.of(context).pop(),
              );
            },
          ),
        ),
      ),
      body:
          goals.isEmpty
              ? _buildEmptyState()
              : WidgetConfigEditor(
                widgetSize: WidgetSize.large,
                initialConfig: _widgetConfig,
                previewTitle: '进度增减预览',
                onConfigChanged: (config) {
                  setState(() => _widgetConfig = config);
                },
                previewBuilder: _buildPreview,
                customConfigWidgets: [_buildGoalSelector()],
              ),
      bottomNavigationBar:
          _selectedGoalId != null
              ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DSThemeBridge(
                    child: DSButton(
                      label: '确认配置',
                      size: DSButtonSize.lg,
                      expand: true,
                      onPressed: _saveAndFinish,
                    ),
                  ),
                ),
              )
              : null,
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return const DSThemeBridge(
      child: Center(
        // DS 无 track_changes 图标，用 refresh 顶替
        child: DSEmptyState(
          icon: DsIconKind.refresh,
          title: '暂无目标',
          message: '请先在目标追踪插件中创建目标',
        ),
      ),
    );
  }

  /// 构建预览
  Widget _buildPreview(BuildContext context, WidgetConfig config) {
    final primaryColor = config.getColor('primary') ?? Colors.red;
    final accentColor = config.getColor('accent') ?? Colors.white;
    final selectedGoal = _getSelectedGoal();

    if (selectedGoal == null) {
      return Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey.shade200.withOpacity(config.opacity),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.track_changes, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text('请选择目标', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    // 渲染进度增减小组件预览
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(config.opacity),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Text(
            selectedGoal.name,
            style: TextStyle(
              color: accentColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // 进度数字
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${selectedGoal.currentValue.toInt()}',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              Text(
                '/${selectedGoal.targetValue.toInt()}',
                style: TextStyle(
                  color: accentColor.withOpacity(0.7),
                  fontSize: 24,
                  height: 1.0,
                ),
              ),
            ],
          ),

          const Spacer(),

          // 加减按钮
          Row(
            children: [
              // 减号按钮
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(Icons.remove, color: accentColor, size: 28),
                ),
              ),
              const SizedBox(width: 8),

              // 加号按钮
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(Icons.add, color: accentColor, size: 28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建目标选择器
  Widget _buildGoalSelector() {
    final goals = _trackerPlugin.controller.goals;

    return DSThemeBridge(
      // WidgetConfigEditor 为共享 Material 容器，DS 组件先过桥
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // DS 无 track_changes 图标，用 refresh 顶替
                  DsIcon(DsIconKind.refresh, size: 22, color: theme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '选择追踪目标',
                    style: DsTypography.heading.copyWith(color: theme.text),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...goals.map((goal) {
                final isSelected = _selectedGoalId == goal.id;
                // 计算进度百分比
                final progress = goal.currentValue / goal.targetValue;
                final progressPercent = (progress * 100).clamp(0, 100).toInt();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Pressable(
                    onPressed: () => _onGoalSelected(goal),
                    builder: (context, states) {
                      final pressed = states.contains(WidgetState.pressed);
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: theme.radii.md,
                          border: Border.all(
                            color: isSelected ? theme.primary : theme.stroke,
                            width: isSelected ? 2 : 1,
                          ),
                          color:
                              isSelected
                                  ? theme.primary.withValues(alpha: 0.05)
                                  : pressed
                                  ? theme.surfaceAlt.withValues(alpha: 0.5)
                                  : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            // 图标（goal.icon 为持久化 codePoint，保留 Material）
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color:
                                    goal.iconColor != null
                                        ? Color(goal.iconColor!).withAlpha(30)
                                        : theme.danger.withAlpha(30),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                dynamicIconData(
                                  int.parse(goal.icon),
                                  fontFamily: 'MaterialIcons',
                                ),
                                color:
                                    goal.iconColor != null
                                        ? Color(goal.iconColor!)
                                        : theme.danger,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // 目标信息
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goal.name,
                                    style: DsTypography.body.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: theme.text,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${goal.currentValue.toInt()}/${goal.targetValue.toInt()} ${goal.unitType} ($progressPercent%)',
                                    style: DsTypography.caption.copyWith(
                                      color: theme.textSub,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 选中标记（空心圆未选中态无 DS 对应，保留 Material）
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color:
                                  isSelected ? theme.primary : theme.disabled,
                              size: 24,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  /// 选中目标
  void _onGoalSelected(Goal goal) {
    setState(() {
      _selectedGoalId = goal.id;
      // 可以选择性地更新主色调为目标的颜色
      if (goal.iconColor != null) {
        _widgetConfig = _widgetConfig.updateColor(
          'primary',
          Color(goal.iconColor!),
        );
      }
    });
  }

  /// 保存配置并关闭界面
  Future<void> _saveAndFinish() async {
    if (_selectedGoalId == null || widget.widgetId == null) {
      Navigator.of(context).pop();
      return;
    }

    try {
      // 保存目标ID
      await HomeWidget.saveWidgetData<String>(
        'tracker_goal_id_${widget.widgetId}',
        _selectedGoalId!,
      );

      // 保存背景色(使用 String 存储,因为 HomeWidget 不支持 int)
      final primaryColor = _widgetConfig.getColor('primary');
      if (primaryColor != null) {
        await HomeWidget.saveWidgetData<String>(
          'tracker_widget_primary_color_${widget.widgetId}',
          primaryColor.value.toString(),
        );
      }

      // 保存强调色(使用 String 存储)
      final accentColor = _widgetConfig.getColor('accent');
      if (accentColor != null) {
        await HomeWidget.saveWidgetData<String>(
          'tracker_widget_accent_color_${widget.widgetId}',
          accentColor.value.toString(),
        );
      }

      // 保存透明度(使用 String 存储)
      await HomeWidget.saveWidgetData<String>(
        'tracker_widget_opacity_${widget.widgetId}',
        _widgetConfig.opacity.toString(),
      );

      // 获取选中的目标
      final selectedGoal = _getSelectedGoal()!;

      // 同步目标数据到小组件
      await _syncGoalToWidget(selectedGoal);

      // 更新小组件
      await HomeWidget.updateWidget(
        name: 'TrackerGoalWidgetProvider',
        iOSName: 'TrackerGoalWidgetProvider',
        qualifiedAndroidName:
            'github.hunmer.aboutme.widgets.providers.TrackerGoalWidgetProvider',
      );

      if (mounted) {
        Toast.success('${'tracker_configured'.tr} "${selectedGoal.name}"');

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        Toast.error('${'tracker_configurationFailed'.tr}: $e');
      }
    }
  }

  /// 同步目标数据到小组件
  Future<void> _syncGoalToWidget(Goal goal) async {
    try {
      final widgetData = jsonEncode({
        'goals': [
          {
            'id': goal.id,
            'name': goal.name,
            'currentValue': goal.currentValue,
            'targetValue': goal.targetValue,
            'unitType': goal.unitType,
          },
        ],
      });

      await HomeWidget.saveWidgetData<String>(
        'tracker_goal_widget_data',
        widgetData,
      );

      debugPrint(
        '目标数据已同步: ${goal.name}, ${goal.currentValue}/${goal.targetValue} ${goal.unitType}',
      );
    } catch (e) {
      debugPrint('同步目标数据失败: $e');
    }
  }
}
