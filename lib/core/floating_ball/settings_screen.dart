import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/action/action_manager.dart';
import 'package:aboutme/core/action/widgets/action_selector_dialog.dart';
import 'package:aboutme/screens/settings_screen/widgets/settings_group.dart';
import 'package:aboutme/screens/settings_screen/widgets/settings_tile.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'floating_ball_manager.dart';
import 'floating_ball_service.dart';
import 'models/floating_ball_gesture.dart';

class FloatingBallSettingsScreen extends StatefulWidget {
  const FloatingBallSettingsScreen({super.key});

  @override
  State<FloatingBallSettingsScreen> createState() =>
      _FloatingBallSettingsScreenState();
}

class _FloatingBallSettingsScreenState extends State<FloatingBallSettingsScreen> {
  final FloatingBallManager _manager = FloatingBallManager();
  final ActionManager _actionManager = ActionManager();
  double _sizeScale = 1.0;
  bool _isEnabled = false;
  final Map<FloatingBallGesture, GestureActionConfig?> _selectedActions = {};

  @override
  void initState() {
    super.initState();
    // 初始化 ActionManager（如果尚未初始化）
    if (!_actionManager.isInitialized) {
      _actionManager.initialize().then((_) {
        if (mounted) {
          _loadSettings();
        }
      });
    } else {
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    // 加载悬浮球大小
    final scale = await _manager.getSizeScale();

    // 加载悬浮球启用状态
    final enabled = await _manager.isEnabled();

    // 从 ActionManager 加载手势动作配置
    for (var gesture in FloatingBallGesture.values) {
      final config = _actionManager.getGestureAction(gesture);
      _selectedActions[gesture] = config;
    }

    if (mounted) {
      setState(() {
        _sizeScale = scale;
        _isEnabled = enabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SuperCupertinoNavigationWrapper(
      title: Text('floating_ball_floatingBallSettings'.tr),
      largeTitle: 'floating_ball_floatingBallSettings'.tr,
      enableLargeTitle: false,
      body: DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return ListView(
              padding: EdgeInsets.fromLTRB(
                16.0,
                16.0,
                16.0,
                16.0 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                // 悬浮球启用开关
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: DsIconKind.touchApp,
                      iconColor: DsAccentColors.pink,
                      title: 'floating_ball_enableFloatingBall'.tr,
                      showChevron: false,
                      trailing: DSSwitch(
                        value: _isEnabled,
                        onChanged: (value) async {
                          setState(() {
                            _isEnabled = value;
                          });
                          await _manager.setEnabled(value);

                          // 如果启用悬浮球，则显示悬浮球
                          if (value) {
                            FloatingBallService().show(context);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 悬浮球大小设置
                SettingsGroup(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'floating_ball_small'.tr,
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DSSlider(
                              // 0.5 ~ 1.5 映射到 0 ~ 1
                              value: (_sizeScale - 0.5) / 1.0,
                              onChanged: (value) {
                                final scale = 0.5 + value;
                                setState(() {
                                  _sizeScale = scale;
                                });
                                _manager.saveSizeScale(scale);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'floating_ball_large'.tr,
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 44,
                            child: Text(
                              '${(_sizeScale * 100).round()}%',
                              textAlign: TextAlign.end,
                              style: DsTypography.heading.copyWith(
                                color: theme.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 悬浮球动作设置：为每种手势提供选择入口
                SettingsGroup(
                  children: _buildGestureActionSelectors(),
                ),
                const SizedBox(height: 16),

                // 重置位置
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: DsIconKind.pin,
                      iconColor: DsAccentColors.violet,
                      title: 'floating_ball_resetPosition'.tr,
                      showChevron: false,
                      onTap: () {
                        _manager.resetPosition();
                        Toast.success('floating_ball_positionReset'.tr);
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 构建所有手势动作选择器
  List<Widget> _buildGestureActionSelectors() {
    final List<Widget> selectors = [];

    for (var gesture in FloatingBallGesture.values) {
      if (gesture != FloatingBallGesture.longPress) {
        final config = _selectedActions[gesture];
        final displayText = _getGestureActionDisplayText(config);

        selectors.add(
          SettingsTile(
            icon: _getGestureIcon(gesture),
            iconColor: _getGestureColor(gesture),
            title: _getGestureName(gesture),
            subtitle: displayText,
            onTap: () async {
              final result = await ActionSelectorDialog.show(
                context,
                gesture: gesture,
                initialValue:
                    config != null
                        ? ActionSelectorResult(
                          singleAction: config.singleAction,
                          actionGroup: config.group,
                        )
                        : null,
              );

              if (result != null && mounted) {
                setState(() {
                  if (result.isGroup && result.actionGroup != null) {
                    _selectedActions[gesture] = GestureActionConfig(
                      gesture: gesture,
                      group: result.actionGroup,
                    );
                  } else if (result.isSingleAction &&
                      result.singleAction != null) {
                    _selectedActions[gesture] = GestureActionConfig(
                      gesture: gesture,
                      singleAction: result.singleAction,
                    );
                  } else {
                    _selectedActions[gesture] = null;
                  }
                });

                // 保存到 ActionManager
                final actionConfig = _selectedActions[gesture];
                if (actionConfig != null) {
                  await _actionManager.setGestureAction(
                    gesture,
                    actionConfig,
                  );
                } else {
                  await _actionManager.clearGestureAction(gesture);
                }
              }
            },
          ),
        );
      }
    }

    return selectors;
  }

  /// 获取手势动作的显示文本
  String _getGestureActionDisplayText(GestureActionConfig? config) {
    if (config == null || config.isEmpty) {
      return 'floating_ball_notSet'.tr;
    }

    if (config.singleAction != null) {
      return config.singleAction!.displayTitle;
    }

    if (config.group != null) {
      return 'floating_ball_groupActionCount'.trParams({
        'title': config.group!.title,
        'count': '${config.group!.actionCount}',
      });
    }

    return 'floating_ball_notSet'.tr;
  }

  /// 获取手势图标
  DsIconKind _getGestureIcon(FloatingBallGesture gesture) {
    switch (gesture) {
      case FloatingBallGesture.tap:
        return DsIconKind.touchApp;
      case FloatingBallGesture.doubleTap:
        return DsIconKind.gesture;
      case FloatingBallGesture.longPress:
        return DsIconKind.timer;
      case FloatingBallGesture.swipeUp:
        return DsIconKind.chevronUp;
      case FloatingBallGesture.swipeDown:
        return DsIconKind.chevronDown;
      case FloatingBallGesture.swipeLeft:
        return DsIconKind.chevronLeft;
      case FloatingBallGesture.swipeRight:
        return DsIconKind.chevronRight;
    }
  }

  /// 获取手势条目粉彩图标底色
  Color _getGestureColor(FloatingBallGesture gesture) {
    switch (gesture) {
      case FloatingBallGesture.tap:
        return DsAccentColors.blue;
      case FloatingBallGesture.doubleTap:
        return DsAccentColors.violet;
      case FloatingBallGesture.longPress:
        return DsAccentColors.slate;
      case FloatingBallGesture.swipeUp:
        return DsAccentColors.emerald;
      case FloatingBallGesture.swipeDown:
        return DsAccentColors.teal;
      case FloatingBallGesture.swipeLeft:
        return DsAccentColors.orange;
      case FloatingBallGesture.swipeRight:
        return DsAccentColors.amber;
    }
  }

  // 获取手势名称
  String _getGestureName(FloatingBallGesture gesture) {
    switch (gesture) {
      case FloatingBallGesture.tap:
        return 'floating_ball_tapGesture'.tr;
      case FloatingBallGesture.doubleTap:
        return 'floating_ball_doubleTapGesture'.tr;
      case FloatingBallGesture.longPress:
        return 'floating_ball_longPressGesture'.tr;
      case FloatingBallGesture.swipeUp:
        return 'floating_ball_swipeUpGesture'.tr;
      case FloatingBallGesture.swipeDown:
        return 'floating_ball_swipeDownGesture'.tr;
      case FloatingBallGesture.swipeLeft:
        return 'floating_ball_swipeLeftGesture'.tr;
      case FloatingBallGesture.swipeRight:
        return 'floating_ball_swipeRightGesture'.tr;
    }
  }
}
