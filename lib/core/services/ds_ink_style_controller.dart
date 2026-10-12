import 'package:flutter/foundation.dart';

import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 墨线风格控制器
///
/// 管理全局手绘墨线档位（skribble 三档粗糙度：Gentle/Playful/Expressive）
/// 的选择与持久化。写入 [DsInkStyle.level] 后经 [DsThemeBridge]
/// （已合并监听本控制器）重建主题树，全局即时生效。
class DsInkStyleController extends ChangeNotifier {
  static final DsInkStyleController _instance = DsInkStyleController._internal();

  factory DsInkStyleController() => _instance;

  DsInkStyleController._internal();

  /// 配置键名
  static const String _configKey = 'ds_ink_style';

  bool _initialized = false;
  bool get initialized => _initialized;

  /// 初始化：从配置加载墨线档位并写入全局档位
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
      }
    } catch (e) {
      debugPrint('加载墨线风格配置失败: $e');
    }

    _initialized = true;
    notifyListeners();
  }

  /// 切换墨线档位并持久化（index 对应 DsInkStyle.labels 下标）
  Future<void> setLevel(int index) async {
    if (index < 0 || index >= DsInkStyle.labels.length) return;
    if (index == DsInkStyle.index) return;

    DsInkStyle.level = DsInkStyle.byIndex(index);

    try {
      await globalConfigManager.savePluginConfig(_configKey, {
        'level': index,
      });
    } catch (e) {
      debugPrint('保存墨线风格配置失败: $e');
    }

    notifyListeners();
  }
}
