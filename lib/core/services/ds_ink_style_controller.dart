import 'package:flutter/foundation.dart';

import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 墨线风格控制器
///
/// 管理全局手绘墨线风格（skribble 三档粗糙度：Gentle/Playful/Expressive，
/// 及随主题预设的笔宽）的选择与持久化。写入 [DsInkStyle.level] 与
/// [DsInkStyle.strokeWidth] 后经 [DsThemeBridge]（已合并监听本控制器）
/// 重建主题树，全局即时生效。
class DsInkStyleController extends ChangeNotifier {
  static final DsInkStyleController _instance = DsInkStyleController._internal();

  factory DsInkStyleController() => _instance;

  DsInkStyleController._internal();

  /// 配置键名
  static const String _configKey = 'ds_ink_style';

  /// 笔宽合法区间（异常配置回落默认值）
  static const double _minStrokeWidth = 0.5;
  static const double _maxStrokeWidth = 5;

  bool _initialized = false;
  bool get initialized => _initialized;

  /// 初始化：从配置加载墨线档位与笔宽并写入全局风格
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final config = await globalConfigManager.getPluginConfig(_configKey);
      if (config != null) {
        final index = config['level'] as int?;
        if (index != null &&
            index >= 0 &&
            index < DsInkStyle.labels.length) {
          DsInkStyle.level = DsInkStyle.byIndex(index);
        }
        final strokeWidth = (config['strokeWidth'] as num?)?.toDouble();
        if (strokeWidth != null &&
            strokeWidth >= _minStrokeWidth &&
            strokeWidth <= _maxStrokeWidth) {
          DsInkStyle.strokeWidth = strokeWidth;
        }
      }
    } catch (e) {
      debugPrint('加载墨线风格配置失败: $e');
    }

    _initialized = true;
    notifyListeners();
  }

  /// 切换墨线风格（档位 index 对应 DsInkStyle.labels 下标 + 笔宽）并持久化
  Future<void> setStyle(int index, double strokeWidth) async {
    if (index < 0 || index >= DsInkStyle.labels.length) return;
    if (strokeWidth < _minStrokeWidth || strokeWidth > _maxStrokeWidth) return;
    if (index == DsInkStyle.index && strokeWidth == DsInkStyle.strokeWidth) {
      return;
    }

    DsInkStyle.level = DsInkStyle.byIndex(index);
    DsInkStyle.strokeWidth = strokeWidth;

    try {
      await globalConfigManager.savePluginConfig(_configKey, {
        'level': index,
        'strokeWidth': strokeWidth,
      });
    } catch (e) {
      debugPrint('保存墨线风格配置失败: $e');
    }

    notifyListeners();
  }
}
