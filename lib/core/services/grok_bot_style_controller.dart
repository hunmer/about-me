import 'package:flutter/foundation.dart';

import 'package:aboutme/core/app_initializer.dart';
import 'package:grok_icon_study/grok_icon_study.dart';

/// GrokBot 外观控制器
///
/// 管理首页 grokbot 的身形（shapeId）与墨色（colorId）选择与持久化，
/// 角色实例监听本控制器后调用 setShape/setColor 即时生效。
class GrokBotStyleController extends ChangeNotifier {
  static final GrokBotStyleController _instance =
      GrokBotStyleController._internal();

  factory GrokBotStyleController() => _instance;

  GrokBotStyleController._internal();

  /// 配置键名
  static const String _configKey = 'grok_bot_style';

  bool _initialized = false;
  bool get initialized => _initialized;

  String _shapeId = 'blob';
  String get shapeId => _shapeId;

  String _colorId = 'black';
  String get colorId => _colorId;

  /// 初始化：从配置加载身形/墨色选择
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final config = await globalConfigManager.getPluginConfig(_configKey);
      if (config != null) {
        final shapeId = config['shapeId'] as String?;
        if (shapeId != null && GrokGeometry.shapes.containsKey(shapeId)) {
          _shapeId = shapeId;
        }
        final colorId = config['colorId'] as String?;
        if (colorId != null && GrokGeometry.palette.containsKey(colorId)) {
          _colorId = colorId;
        }
      }
    } catch (e) {
      debugPrint('加载 grokbot 外观配置失败: $e');
    }

    _initialized = true;
    notifyListeners();
  }

  /// 切换身形并持久化
  Future<void> setShape(String id) async {
    if (!GrokGeometry.shapes.containsKey(id) || id == _shapeId) return;

    _shapeId = id;
    await _save();
    notifyListeners();
  }

  /// 切换墨色并持久化
  Future<void> setColor(String id) async {
    if (!GrokGeometry.palette.containsKey(id) || id == _colorId) return;

    _colorId = id;
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await globalConfigManager.savePluginConfig(_configKey, {
        'shapeId': _shapeId,
        'colorId': _colorId,
      });
    } catch (e) {
      debugPrint('保存 grokbot 外观配置失败: $e');
    }
  }
}
