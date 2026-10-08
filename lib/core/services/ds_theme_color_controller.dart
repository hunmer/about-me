import 'package:flutter/foundation.dart';

import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 主题色板控制器
///
/// 管理全局主题色板（樱花粉/莓果紫/海空蓝等）的选择与持久化，
/// [DsThemeBridge] 监听本控制器构建 DS 主题，切换后全局即时生效。
class DsThemeColorController extends ChangeNotifier {
  static final DsThemeColorController _instance =
      DsThemeColorController._internal();

  factory DsThemeColorController() => _instance;

  DsThemeColorController._internal();

  /// 配置键名
  static const String _configKey = 'ds_theme_color';

  bool _initialized = false;
  bool get initialized => _initialized;

  DsThemePalette _palette = DsThemePalettes.pink;

  /// 当前色板
  DsThemePalette get palette => _palette;

  /// 当前色板 id
  String get paletteId => _palette.id;

  /// 初始化：从配置加载色板选择
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final config = await globalConfigManager.getPluginConfig(_configKey);
      if (config != null) {
        _palette = DsThemePalettes.byId(config['paletteId'] as String?);
      }
    } catch (e) {
      debugPrint('加载主题色板配置失败: $e');
    }

    _initialized = true;
    notifyListeners();
  }

  /// 切换色板并持久化
  Future<void> setPalette(String id) async {
    final palette = DsThemePalettes.byId(id);
    if (palette.id == _palette.id) return;

    _palette = palette;

    try {
      await globalConfigManager.savePluginConfig(_configKey, {
        'paletteId': _palette.id,
      });
    } catch (e) {
      debugPrint('保存主题色板配置失败: $e');
    }

    notifyListeners();
  }
}
