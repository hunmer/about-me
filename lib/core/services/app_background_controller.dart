import 'package:aboutme/core/app_initializer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show BoxFit, Color;

/// 全局主题背景控制器
///
/// 管理应用于所有界面的背景设置（背景图与纯色背景），
/// 代替各界面默认的纯色主题背景。
/// 与主页布局管理器的背景配置（home_global_background）相互独立，
/// 主页自身的背景图优先于全局主题背景显示。
class AppBackgroundController extends ChangeNotifier {
  static final AppBackgroundController _instance =
      AppBackgroundController._internal();

  factory AppBackgroundController() => _instance;

  AppBackgroundController._internal();

  /// 配置键名
  static const String _configKey = 'app_theme_background';

  bool _initialized = false;
  bool get initialized => _initialized;

  String? _backgroundPath;
  String? get backgroundPath => _backgroundPath;

  BoxFit _backgroundFit = BoxFit.cover;
  BoxFit get backgroundFit => _backgroundFit;

  double _backgroundBlur = 0.0;
  double get backgroundBlur => _backgroundBlur;

  /// 纯色背景（ARGB 整型存储，null 表示未设置）
  int? _backgroundColorValue;

  Color? get backgroundColor =>
      _backgroundColorValue == null ? null : Color(_backgroundColorValue!);

  /// 是否设置了背景图
  bool get hasBackground => _backgroundPath != null;

  /// 是否设置了自定义背景（背景图或纯色）
  bool get hasCustomBackground =>
      _backgroundPath != null || _backgroundColorValue != null;

  /// 初始化：从配置加载背景设置
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final config = await globalConfigManager.getPluginConfig(_configKey);
      if (config != null) {
        _backgroundPath = config['backgroundImagePath'] as String?;
        _backgroundFit = _boxFitFromString(config['backgroundFit'] as String?);
        _backgroundBlur = (config['backgroundBlur'] as num?)?.toDouble() ?? 0.0;
        _backgroundColorValue = (config['backgroundColor'] as num?)?.toInt();
      }
    } catch (e) {
      debugPrint('加载全局主题背景配置失败: $e');
    }

    _initialized = true;
    notifyListeners();
  }

  /// 保存背景图设置（backgroundPath 传 null 表示清除背景图，不影响纯色背景）
  Future<void> save({
    String? backgroundPath,
    BoxFit? backgroundFit,
    double? backgroundBlur,
  }) async {
    _backgroundPath = backgroundPath;
    _backgroundFit = backgroundFit ?? _backgroundFit;
    _backgroundBlur = backgroundBlur ?? _backgroundBlur;

    try {
      await _writeConfig();
    } catch (e) {
      debugPrint('保存全局主题背景配置失败: $e');
      rethrow;
    }

    notifyListeners();
  }

  /// 保存纯色背景设置（color 传 null 表示清除，恢复系统默认背景）
  Future<void> saveBackgroundColor(Color? color) async {
    _backgroundColorValue = color == null ? null : _colorToValue(color);

    try {
      await _writeConfig();
    } catch (e) {
      debugPrint('保存全局主题背景配置失败: $e');
      rethrow;
    }

    notifyListeners();
  }

  Future<void> _writeConfig() async {
    await globalConfigManager.savePluginConfig(_configKey, {
      'backgroundImagePath': _backgroundPath,
      'backgroundFit': _boxFitToString(_backgroundFit),
      'backgroundBlur': _backgroundBlur,
      'backgroundColor': _backgroundColorValue,
    });
  }

  /// Color 转 ARGB 整型（兼容新版颜色分量 API）
  static int _colorToValue(Color color) {
    final a = (color.a * 255.0).round().clamp(0, 255);
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  static BoxFit _boxFitFromString(String? value) {
    switch (value) {
      case 'fill':
        return BoxFit.fill;
      case 'contain':
        return BoxFit.contain;
      case 'cover':
        return BoxFit.cover;
      case 'fitWidth':
        return BoxFit.fitWidth;
      case 'fitHeight':
        return BoxFit.fitHeight;
      case 'none':
        return BoxFit.none;
      case 'scaleDown':
        return BoxFit.scaleDown;
      default:
        return BoxFit.cover;
    }
  }

  static String _boxFitToString(BoxFit fit) {
    switch (fit) {
      case BoxFit.fill:
        return 'fill';
      case BoxFit.contain:
        return 'contain';
      case BoxFit.cover:
        return 'cover';
      case BoxFit.fitWidth:
        return 'fitWidth';
      case BoxFit.fitHeight:
        return 'fitHeight';
      case BoxFit.none:
        return 'none';
      case BoxFit.scaleDown:
        return 'scaleDown';
    }
  }
}
