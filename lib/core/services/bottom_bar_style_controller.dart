import 'package:flutter/foundation.dart';

import 'package:aboutme/core/app_initializer.dart';

/// 底部导航栏风格控制器
///
/// 全局控制 DSBottomNavigation（radial_disc_bottom_bar）的磨砂玻璃效果，
/// 组件内部监听本控制器，切换后所有使用处即时刷新，无需逐页传参。
class BottomBarStyleController extends ChangeNotifier {
  static final BottomBarStyleController _instance =
      BottomBarStyleController._internal();

  factory BottomBarStyleController() => _instance;

  BottomBarStyleController._internal();

  /// 配置键名
  static const String _configKey = 'bottom_bar_style';

  bool _initialized = false;
  bool get initialized => _initialized;

  bool _frosted = true;

  /// 是否启用扇环磨砂玻璃（背景模糊 + 半透明填充）
  bool get frosted => _frosted;

  /// 初始化：从配置加载开关状态
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final config = await globalConfigManager.getPluginConfig(_configKey);
      if (config != null) {
        _frosted = config['frosted'] as bool? ?? true;
      }
    } catch (e) {
      debugPrint('加载底栏风格配置失败: $e');
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> setFrosted(bool value) async {
    if (value == _frosted) return;
    _frosted = value;
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await globalConfigManager.savePluginConfig(_configKey, {
        'frosted': _frosted,
      });
    } catch (e) {
      debugPrint('保存底栏风格配置失败: $e');
    }
  }
}
