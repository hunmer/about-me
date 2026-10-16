import 'package:flutter/foundation.dart';

import 'package:aboutme/core/app_initializer.dart';

/// 手绘便签风格控制器
///
/// 全局控制 HandDrawnListView / HandDrawnStickyItem 的贴条与倾斜效果，
/// 组件内部监听本控制器，切换后所有使用处即时刷新，无需逐页传参。
class HandDrawnStyleController extends ChangeNotifier {
  static final HandDrawnStyleController _instance =
      HandDrawnStyleController._internal();

  factory HandDrawnStyleController() => _instance;

  HandDrawnStyleController._internal();

  /// 配置键名
  static const String _configKey = 'hand_drawn_style';

  bool _initialized = false;
  bool get initialized => _initialized;

  bool _tapeEnabled = true;
  bool _tiltEnabled = true;
  bool _entranceEnabled = true;

  /// 是否绘制顶部贴条（含 folderTab 标签页）
  bool get tapeEnabled => _tapeEnabled;

  /// 是否启用倾斜姿态（关闭后角度与水平偏移归零，悬浮动效保留）
  bool get tiltEnabled => _tiltEnabled;

  /// 是否启用入场动画（淡入 + 上滑，列表按索引瀑布延迟）
  bool get entranceEnabled => _entranceEnabled;

  /// 初始化：从配置加载开关状态
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final config = await globalConfigManager.getPluginConfig(_configKey);
      if (config != null) {
        _tapeEnabled = config['tape'] as bool? ?? true;
        _tiltEnabled = config['tilt'] as bool? ?? true;
        _entranceEnabled = config['entrance'] as bool? ?? true;
      }
    } catch (e) {
      debugPrint('加载手绘风格配置失败: $e');
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> setTapeEnabled(bool value) async {
    if (value == _tapeEnabled) return;
    _tapeEnabled = value;
    await _save();
    notifyListeners();
  }

  Future<void> setTiltEnabled(bool value) async {
    if (value == _tiltEnabled) return;
    _tiltEnabled = value;
    await _save();
    notifyListeners();
  }

  Future<void> setEntranceEnabled(bool value) async {
    if (value == _entranceEnabled) return;
    _entranceEnabled = value;
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await globalConfigManager.savePluginConfig(_configKey, {
        'tape': _tapeEnabled,
        'tilt': _tiltEnabled,
        'entrance': _entranceEnabled,
      });
    } catch (e) {
      debugPrint('保存手绘风格配置失败: $e');
    }
  }
}
