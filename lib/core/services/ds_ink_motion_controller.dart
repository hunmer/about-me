import 'package:flutter/foundation.dart';

import 'package:aboutme/core/app_initializer.dart';

/// 墨线入场动画（skribble 描画）时长控制器
///
/// 管理全局手绘入场动画时长的选择与持久化：
/// - 0 = 关闭描画动画（墨线直接呈现）
/// - >0 = WiredDraw 入场描画时长（毫秒）
/// 根节点经 `WiredMotion(enabled / drawDuration)` 全局生效，
/// 未显式传时长的 WiredDraw 自动跟随（design.md §10）。
class DsInkMotionController extends ChangeNotifier {
  static final DsInkMotionController _instance = DsInkMotionController._internal();

  factory DsInkMotionController() => _instance;

  DsInkMotionController._internal();

  /// 配置键名
  static const String _configKey = 'ds_ink_motion';

  /// design.md §10 默认时长 650ms
  static const int defaultDurationMs = 650;

  /// 时长上限（毫秒）
  static const int maxDurationMs = 2000;

  bool _initialized = false;
  bool get initialized => _initialized;

  int _durationMs = defaultDurationMs;

  /// 当前时长（毫秒）；0 = 关闭动画
  int get durationMs => _durationMs;

  bool get enabled => _durationMs > 0;

  /// 初始化：从配置加载时长
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final config = await globalConfigManager.getPluginConfig(_configKey);
      final ms = (config?['durationMs'] as num?)?.toInt();
      if (ms != null && ms >= 0 && ms <= maxDurationMs) {
        _durationMs = ms;
      }
    } catch (e) {
      debugPrint('加载墨线动画时长配置失败: $e');
    }

    _initialized = true;
    notifyListeners();
  }

  /// 设置时长（毫秒，内部钳制到 0–2000），立即全局生效并持久化
  Future<void> setDurationMs(int ms) async {
    final clamped = ms.clamp(0, maxDurationMs);
    if (clamped == _durationMs) return;

    _durationMs = clamped;
    notifyListeners();

    try {
      await globalConfigManager.savePluginConfig(_configKey, {
        'durationMs': clamped,
      });
    } catch (e) {
      debugPrint('保存墨线动画时长配置失败: $e');
    }
  }
}
