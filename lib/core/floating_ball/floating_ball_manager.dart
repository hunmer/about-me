import 'dart:core';
import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'floating_ball_service.dart';
import 'package:aboutme/dialogs/plugin_list_dialog.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/widgets/route_history_dialog/route_history_dialog.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/screens/tool_template_screen/tool_template_screen.dart';
import 'package:aboutme/plugins/agent_chat/screens/tool_management_screen/tool_management_screen.dart';
import 'models/floating_ball_gesture.dart';
import 'config/floating_ball_config.dart';
import 'package:aboutme/widgets/route_viewer_dialog.dart';

/// 动作信息类，包含动作标题和回调函数
class ActionInfo {
  final String title;
  final Function callback;

  ActionInfo(this.title, this.callback);
}

/// 悬浮球大小变化回调
typedef SizeChangeCallback = void Function(double newSize);

/// 悬浮球管理器
class FloatingBallManager {
  static final FloatingBallManager _instance = FloatingBallManager._internal();
  factory FloatingBallManager() => _instance;
  FloatingBallManager._internal() {
    _loadActions().then((_) => _initCompleter.complete());
  }

  final Map<FloatingBallGesture, ActionInfo> _actions = {};
  // 默认位置
  Offset _position = FloatingBallConfig.defaultPosition;

  // 初始化完成器，确保数据加载完成
  final Completer<void> _initCompleter = Completer<void>();

  // 大小变化回调列表
  final List<SizeChangeCallback> _sizeChangeCallbacks = [];

  // 预定义的动作映射表
  static final Map<String, Function(BuildContext)> _predefinedActionCreators = {
    '打开上次插件':
        (context) => () {
          if (context.mounted) {
            // 当前插件以实际路由为准做排除：getCurrentPluginId() 在普通
            // 返回手势后不清空，会把真正最近使用的插件误排除；
            // 不在插件页时不排除，直接打开最近使用的插件
            final currentPluginId = PluginManager.instance
                .getCurrentRoutePluginId();
            final lastPlugin = PluginManager.instance.getLastOpenedPlugin(
              excludePluginId: currentPluginId,
            );
            if (lastPlugin != null) {
              PluginManager.instance.openPlugin(context, lastPlugin);
            } else {
              Toast.info('floating_ball_noRecentPlugin'.tr);
            }
          }
        },
    '选择打开插件':
        (context) => () {
          if (context.mounted) {
            showPluginListDialog(context);
          }
        },
    '返回上一页':
        (context) => () {
          if (context.mounted) {
            NavigationHelper.smartBack(context);
          }
        },
    '返回首页':
        (context) => () {
          if (context.mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
    '刷新页面':
        (context) => () {
          if (context.mounted) {
            Toast.success('floating_ball_pageRefreshed'.tr);
          }
        },
    '路由历史记录':
        (context) => () {
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (context) => const RouteHistoryDialog(),
            );
          }
        },
    '打开上个路由':
        (context) => () async {
          if (context.mounted) {
            final lastPage = RouteHistoryManager.getLastVisitedPage();
            if (lastPage != null) {
              await _reopenPage(context, lastPage);
            } else {
              Toast.info('没有历史记录');
            }
          }
        },
    '路由查看器':
        (context) => () {
          if (context.mounted) {
            RouteViewerDialog.show(context);
          }
        },
  };

  /// 根据页面记录重新打开页面
  static Future<void> _reopenPage(
    BuildContext context,
    dynamic lastPage,
  ) async {
    if (!context.mounted) return;

    switch (lastPage.pageId) {
      case 'tool_template':
        final templateService = AgentChatPlugin.instance.templateService;
        if (templateService == null) {
          Toast.error('工具模板服务未初始化');
          break;
        }
        await NavigationHelper.push(
          context,
          ToolTemplateScreen(templateService: templateService),
        );
        break;
      case 'tool_management':
        await NavigationHelper.push(context, const ToolManagementScreen());
        break;
      default:
        if (context.mounted) {
          Toast.error('未知页面类型: ${lastPage.pageId}');
        }
    }
  }

  static get noRecentPlugin => null;

  // 确保初始化完成
  Future<void> _ensureInitialized() async {
    if (!_initCompleter.isCompleted) {
      await _initCompleter.future;
    }
  }

  // 加载保存的动作
  Future<void> _loadActions() async {
    final config = await FloatingBallConfigManager.loadConfig();
    config.actionMappings.forEach((gesture, title) {
      _actions[gesture] = ActionInfo(title, () {});
    });
  }

  // 保存动作
  Future<void> _saveAction(
    FloatingBallGesture gesture,
    String? actionTitle,
  ) async {
    await _ensureInitialized();
    final config = await FloatingBallConfigManager.loadConfig();
    final newConfig = actionTitle != null
        ? config.setAction(gesture, actionTitle)
        : config.clearAction(gesture);
    await FloatingBallConfigManager.saveConfig(newConfig);
  }

  // 获取悬浮球大小比例
  Future<double> getSizeScale() async {
    await _ensureInitialized();
    final config = await FloatingBallConfigManager.loadConfig();
    return config.sizeScale;
  }

  // 保存悬浮球大小比例
  Future<void> saveSizeScale(double scale) async {
    await _ensureInitialized();
    final config = await FloatingBallConfigManager.loadConfig();
    await FloatingBallConfigManager.saveConfig(
      config.copyWith(sizeScale: scale),
    );

    // 通知悬浮球大小变化
    FloatingBallService().notifySizeChange(scale);

    // 通知所有注册的回调
    _notifySizeChange(scale);
  }

  // 获取悬浮球启用状态
  Future<bool> isEnabled() async {
    await _ensureInitialized();
    final config = await FloatingBallConfigManager.loadConfig();
    return config.enabled;
  }
  // 保存悬浮球启用状态
  Future<void> setEnabled(bool enabled) async {
    await _ensureInitialized();
    final config = await FloatingBallConfigManager.loadConfig();
    await FloatingBallConfigManager.saveConfig(
      config.copyWith(enabled: enabled),
    );

    // 如果禁用，直接隐藏悬浮球
    if (!enabled) {
      FloatingBallService().hide();
    }
  }

  // 获取贴边收纳开关
  Future<bool> isEdgeDockEnabled() async {
    await _ensureInitialized();
    final config = await FloatingBallConfigManager.loadConfig();
    return config.edgeDockEnabled;
  }

  // 保存贴边收纳开关
  Future<void> setEdgeDockEnabled(bool value) async {
    await _ensureInitialized();
    final config = await FloatingBallConfigManager.loadConfig();
    await FloatingBallConfigManager.saveConfig(
      config.copyWith(edgeDockEnabled: value),
    );

    // 通知悬浮球组件配置变化
    FloatingBallService().notifyConfigChange();
  }

  // 获取保存的位置
  Future<Offset> getPosition() async {
    await _ensureInitialized();
    final config = await FloatingBallConfigManager.loadConfig();
    _position = config.position;
    return _position;
  }

  // 保存位置
  Future<void> savePosition(Offset position) async {
    await _ensureInitialized();
    _position = position;
    final config = await FloatingBallConfigManager.loadConfig();
    await FloatingBallConfigManager.saveConfig(
      config.copyWith(position: position),
    );
  }

  // 设置动作
  Future<void> setAction(
    FloatingBallGesture gesture,
    String title,
    final Function() callback,
  ) async {
    await _ensureInitialized();
    _actions[gesture] = ActionInfo(title, callback);
    await _saveAction(gesture, title);
  }

  // 获取动作
  Function()? getAction(FloatingBallGesture gesture) {
    return _actions[gesture]?.callback as Function()?;
  }

  // 获取动作标题
  String? getActionTitle(FloatingBallGesture gesture) {
    return _actions[gesture]?.title;
  }

  // 获取所有动作
  Map<FloatingBallGesture, ActionInfo> getAllActions() {
    return Map.from(_actions);
  }

  // 获取所有预定义动作标题
  List<String> getAllPredefinedActionTitles() {
    final List<String> titles = _predefinedActionCreators.keys.toList();
    // 添加自定义动作标题
    for (var action in _actions.values) {
      if (!titles.contains(action.title)) {
        titles.add(action.title);
      }
    }
    return titles;
  }

  // 清除动作
  Future<void> clearAction(FloatingBallGesture gesture) async {
    await _ensureInitialized();
    _actions.remove(gesture);
    await _saveAction(gesture, null);
  }

  // 设置动作的上下文
  void setActionContext(BuildContext context) {
    // 更新所有已保存动作的回调函数
    for (var gesture in FloatingBallGesture.values) {
      final actionInfo = _actions[gesture];
      if (actionInfo != null) {
        if (_predefinedActionCreators.containsKey(actionInfo.title)) {
          final creator = _predefinedActionCreators[actionInfo.title]!;
          _actions[gesture] = ActionInfo(actionInfo.title, creator(context));
        }
      }
    }
  }

  // 重置悬浮球位置到默认值
  Future<void> resetPosition() async {
    await _ensureInitialized();
    final defaultPosition = FloatingBallConfig.defaultPosition;
    _position = defaultPosition;
    final config = await FloatingBallConfigManager.loadConfig();
    await FloatingBallConfigManager.saveConfig(
      config.copyWith(position: defaultPosition),
    );

    // 通知悬浮球服务更新位置
    FloatingBallService().updatePosition(defaultPosition);
  }

  // 添加大小变化回调
  void addSizeChangeCallback(SizeChangeCallback callback) {
    _sizeChangeCallbacks.add(callback);
  }

  // 移除大小变化回调
  void removeSizeChangeCallback(SizeChangeCallback callback) {
    _sizeChangeCallbacks.remove(callback);
  }

  // 通知所有大小变化回调
  void _notifySizeChange(double newScale) {
    for (var callback in _sizeChangeCallbacks) {
      try {
        callback(newScale);
      } catch (e) {
        debugPrint('Error in size change callback: $e');
      }
    }
  }
}
