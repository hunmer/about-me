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

  /// 是否启用底栏整域磨砂玻璃（背景模糊 + 半透明填充）
  bool get frosted => _frosted;

  double _blurSigma = 12;

  /// 磨砂背景模糊强度
  double get blurSigma => _blurSigma;

  double _featherRadius = 24;

  /// 顶部背景模糊从零渐入的宽度（逻辑像素，0 = 硬边）
  double get featherRadius => _featherRadius;

  double _tintFade = 0.2;

  /// 纸色 tint 顶部渐入长度（占面板高度比例）
  double get tintFade => _tintFade;

  /// 初始化：从配置加载开关状态
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final config = await globalConfigManager.getPluginConfig(_configKey);
      if (config != null) {
        _frosted = config['frosted'] as bool? ?? true;
        _blurSigma = (config['blurSigma'] as num?)?.toDouble() ?? 12;
        _featherRadius = (config['featherRadius'] as num?)?.toDouble() ?? 24;
        _tintFade = (config['tintFade'] as num?)?.toDouble() ?? 0.2;
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

  Future<void> setBlurSigma(double value) async {
    final clamped = value.clamp(0.0, 30.0).toDouble();
    if (clamped == _blurSigma) return;
    _blurSigma = clamped;
    await _save();
    notifyListeners();
  }

  Future<void> setFeatherRadius(double value) async {
    final clamped = value.clamp(0.0, 48.0).toDouble();
    if (clamped == _featherRadius) return;
    _featherRadius = clamped;
    await _save();
    notifyListeners();
  }

  Future<void> setTintFade(double value) async {
    final clamped = value.clamp(0.0, 0.5).toDouble();
    if (clamped == _tintFade) return;
    _tintFade = clamped;
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await globalConfigManager.savePluginConfig(_configKey, {
        'frosted': _frosted,
        'blurSigma': _blurSigma,
        'featherRadius': _featherRadius,
        'tintFade': _tintFade,
      });
    } catch (e) {
      debugPrint('保存底栏风格配置失败: $e');
    }
  }
}
