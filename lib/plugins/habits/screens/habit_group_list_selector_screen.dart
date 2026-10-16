import 'package:get/get.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:home_widget/home_widget.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/habits/habits_plugin.dart';
import 'package:aboutme/plugins/habits/models/habit.dart';
import 'package:aboutme/plugins/habits/models/skill.dart';
import 'package:aboutme/widgets/widget_config_editor/index.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// 习惯分组列表小组件配置界面
///
/// 功能：
/// 1. 配置小组件颜色主题
/// 2. 调整透明度
/// 3. 实时预览小组件效果
class HabitGroupListSelectorScreen extends StatefulWidget {
  /// 小组件ID（Android appWidgetId）
  final int? widgetId;

  const HabitGroupListSelectorScreen({super.key, this.widgetId});

  @override
  State<HabitGroupListSelectorScreen> createState() =>
      _HabitGroupListSelectorScreenState();
}

class _HabitGroupListSelectorScreenState
    extends State<HabitGroupListSelectorScreen> {
  final HabitsPlugin _habitsPlugin = HabitsPlugin.instance;
  late WidgetConfig _widgetConfig;
  bool _isLoading = true;

  // 默认颜色
  static const Color _defaultPrimaryColor = Color(0xFF6366F1); // Indigo
  static const Color _defaultAccentColor = Color(0xFF818CF8);
  static const Color _defaultBackgroundColor = Color(0xFF1A1A2E); // Dark
  static const Color _defaultTextColor = Color(0xFFE5E7EB); // Light gray

  @override
  void initState() {
    super.initState();
    // 初始化默认配置
    _widgetConfig = WidgetConfig(
      colors: [
        ColorConfig(
          key: 'primary',
          label: '主色调',
          defaultValue: _defaultPrimaryColor,
          currentValue: _defaultPrimaryColor,
        ),
        ColorConfig(
          key: 'accent',
          label: '强调色',
          defaultValue: _defaultAccentColor,
          currentValue: _defaultAccentColor,
        ),
        ColorConfig(
          key: 'background',
          label: '背景色',
          defaultValue: _defaultBackgroundColor,
          currentValue: _defaultBackgroundColor,
        ),
        ColorConfig(
          key: 'text',
          label: '文字色',
          defaultValue: _defaultTextColor,
          currentValue: _defaultTextColor,
        ),
      ],
      opacity: 1.0,
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
      // 加载主色调
      final primaryColorStr = await HomeWidget.getWidgetData<String>(
        'habit_group_list_primary_color_${widget.widgetId}',
      );
      if (primaryColorStr != null) {
        final colorValue = int.tryParse(primaryColorStr);
        if (colorValue != null) {
          _widgetConfig = _widgetConfig.updateColor(
            'primary',
            Color(colorValue),
          );
        }
      }

      // 加载强调色
      final accentColorStr = await HomeWidget.getWidgetData<String>(
        'habit_group_list_accent_color_${widget.widgetId}',
      );
      if (accentColorStr != null) {
        final colorValue = int.tryParse(accentColorStr);
        if (colorValue != null) {
          _widgetConfig = _widgetConfig.updateColor(
            'accent',
            Color(colorValue),
          );
        }
      }

      // 加载背景色
      final bgColorStr = await HomeWidget.getWidgetData<String>(
        'habit_group_list_background_color_${widget.widgetId}',
      );
      if (bgColorStr != null) {
        final colorValue = int.tryParse(bgColorStr);
        if (colorValue != null) {
          _widgetConfig = _widgetConfig.updateColor(
            'background',
            Color(colorValue),
          );
        }
      }

      // 加载文字色
      final textColorStr = await HomeWidget.getWidgetData<String>(
        'habit_group_list_text_color_${widget.widgetId}',
      );
      if (textColorStr != null) {
        final colorValue = int.tryParse(textColorStr);
        if (colorValue != null) {
          _widgetConfig = _widgetConfig.updateColor('text', Color(colorValue));
        }
      }

      // 加载透明度
      final opacityStr = await HomeWidget.getWidgetData<String>(
        'habit_group_list_opacity_${widget.widgetId}',
      );
      if (opacityStr != null) {
        final opacity = double.tryParse(opacityStr);
        if (opacity != null) {
          _widgetConfig = _widgetConfig.copyWith(opacity: opacity);
        }
      }
    } catch (e) {
      debugPrint('加载配置失败: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: DSThemeBridge(child: Center(child: DSLoadingDots())),
        ),
      );
    }

    final habits = _habitsPlugin.getHabitController().getHabits();
    final skills = _habitsPlugin.getSkillController().getSkills();

    return Scaffold(
      appBar: AppBar(
        title: Text('habits_configureHabitGroupListWidget'.tr),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body:
          habits.isEmpty
              ? _buildEmptyState()
              : WidgetConfigEditor(
                widgetSize: WidgetSize.large,
                initialConfig: _widgetConfig,
                previewTitle: '小组件预览',
                onConfigChanged: (config) {
                  setState(() => _widgetConfig = config);
                },
                previewBuilder:
                    (context, config) =>
                        _buildPreview(context, config, habits, skills),
              ),
      bottomNavigationBar: SafeArea(
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
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: DSEmptyState(
        icon: DsIconKind.sparkle,
        title: 'habits_emptyTitle'.tr,
        message: 'habits_emptyHint'.tr,
      ),
    );
  }

  /// 构建实时预览
  Widget _buildPreview(
    BuildContext context,
    WidgetConfig config,
    List<Habit> habits,
    List<Skill> skills,
  ) {
    final primaryColor = config.getColor('primary') ?? _defaultPrimaryColor;
    final accentColor = config.getColor('accent') ?? _defaultAccentColor;
    final bgColor = config.getColor('background') ?? _defaultBackgroundColor;
    final textColor = config.getColor('text') ?? _defaultTextColor;
    final opacity = config.opacity;

    // 构建分组数据（包括内置分组）
    final groups = <Map<String, String>>[
      {'id': '__all__', 'name': '所有', 'icon': '📋'},
      {'id': '__ungrouped__', 'name': '未分组', 'icon': '📁'},
    ];

    // 添加技能作为分组
    for (final skill in skills) {
      groups.add({
        'id': skill.id,
        'name': skill.title,
        'icon': skill.icon ?? '📂',
      });
    }

    // 获取前几个习惯用于预览
    final previewHabits = habits.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: bgColor.withOpacity(opacity),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A3A5C), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧分组列表
          Container(
            width: 80,
            decoration: BoxDecoration(
              color: bgColor.withOpacity(0.8),
              border: Border(
                right: BorderSide(color: const Color(0xFF3A3A5C), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 分组标题
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '分组',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // 分组项
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: groups.take(4).length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final isSelected = index == 0;
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? accentColor.withOpacity(0.3)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Text(
                              group['icon']!,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                group['name']!,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // 右侧习惯列表
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 习惯标题
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '习惯',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // 习惯项
                Expanded(
                  child:
                      previewHabits.isEmpty
                          ? Center(
                            child: Text(
                              'habits_emptyTitle'.tr,
                              style: TextStyle(
                                color: textColor.withOpacity(0.5),
                                fontSize: 10,
                              ),
                            ),
                          )
                          : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: previewHabits.length,
                            itemBuilder: (context, index) {
                              final habit = previewHabits[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    // Checkbox
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: primaryColor,
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Icon
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child:
                                            habit.icon != null
                                                ? Icon(
                                                  dynamicIconData(
                                                    int.tryParse(habit.icon!) ??
                                                        Icons.star.codePoint,
                                                    fontFamily: 'MaterialIcons',
                                                  ),
                                                  size: 10,
                                                  color: primaryColor,
                                                )
                                                : Text(
                                                  '✨',
                                                  style: const TextStyle(
                                                    fontSize: 8,
                                                  ),
                                                ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Name
                                    Expanded(
                                      child: Text(
                                        habit.title,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 10,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 保存配置并完成
  Future<void> _saveAndFinish() async {
    if (widget.widgetId == null) {
      Navigator.of(context).pop();
      return;
    }

    try {
      // 1. 获取配置值
      final primaryColor =
          _widgetConfig.getColor('primary') ?? _defaultPrimaryColor;
      final accentColor =
          _widgetConfig.getColor('accent') ?? _defaultAccentColor;
      final bgColor =
          _widgetConfig.getColor('background') ?? _defaultBackgroundColor;
      final textColor = _widgetConfig.getColor('text') ?? _defaultTextColor;
      final opacity = _widgetConfig.opacity;

      // 2. 保存配置标记
      await HomeWidget.saveWidgetData<bool>(
        'habit_group_list_configured_${widget.widgetId}',
        true,
      );

      // 3. 保存颜色配置
      await HomeWidget.saveWidgetData<String>(
        'habit_group_list_primary_color_${widget.widgetId}',
        primaryColor.value.toString(),
      );

      await HomeWidget.saveWidgetData<String>(
        'habit_group_list_accent_color_${widget.widgetId}',
        accentColor.value.toString(),
      );

      await HomeWidget.saveWidgetData<String>(
        'habit_group_list_background_color_${widget.widgetId}',
        bgColor.value.toString(),
      );

      await HomeWidget.saveWidgetData<String>(
        'habit_group_list_text_color_${widget.widgetId}',
        textColor.value.toString(),
      );

      await HomeWidget.saveWidgetData<String>(
        'habit_group_list_opacity_${widget.widgetId}',
        opacity.toString(),
      );

      // 4. 同步习惯数据到小组件
      await _syncHabitGroupListData();

      // 等待 SharedPreferences 数据写入完成
      await Future.delayed(const Duration(milliseconds: 200));

      // 5. 更新小组件
      debugPrint('正在更新习惯分组列表小组件...');
      await HomeWidget.updateWidget(
        name: 'HabitGroupListWidgetProvider',
        iOSName: 'HabitGroupListWidgetProvider',
        qualifiedAndroidName:
            'github.hunmer.aboutme.widgets.providers.HabitGroupListWidgetProvider',
      );
      debugPrint('HabitGroupListWidgetProvider 更新完成');

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('保存配置失败: $e');
      if (mounted) {
        Toast.error('保存失败: $e');
      }
    }
  }

  /// 同步习惯分组列表数据到小组件
  Future<void> _syncHabitGroupListData() async {
    try {
      final habits = _habitsPlugin.getHabitController().getHabits();
      final skills = _habitsPlugin.getSkillController().getSkills();

      // 构建分组数据
      final groupsData =
          skills.map((skill) {
            return {
              'id': skill.id,
              'name': skill.title,
              'icon': skill.icon ?? '📂',
            };
          }).toList();

      // 构建习惯数据
      final habitsData =
          habits.map((habit) {
            return {
              'id': habit.id,
              'title': habit.title,
              'icon': habit.icon,
              'group': habit.skillId,
              'completed': false, // TODO: 从完成记录中获取今日完成状态
            };
          }).toList();

      // 保存为 JSON 字符串
      await HomeWidget.saveWidgetData<String>(
        'habit_group_list_widget_data',
        jsonEncode({'groups': groupsData, 'habits': habitsData}),
      );

      debugPrint('已同步习惯分组列表数据: ${habits.length} 个习惯, ${skills.length} 个技能');
    } catch (e) {
      debugPrint('同步习惯分组列表数据失败: $e');
    }
  }
}
