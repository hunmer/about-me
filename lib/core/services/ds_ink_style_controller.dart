import 'package:flutter/foundation.dart';

import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 墨线风格控制器
///
/// 管理全局描边线风格（[DsStrokeStyles] 命名风格）的选择与持久化，
/// 优先级：用户自选风格 > 主题预设默认值。
/// - [customStyleId] 非空：自选风格生效，切换主题预设不改描边；
/// - [customStyleId] 为空（跟随主题）：主题预设自带的基础墨线生效。
/// 写入 [DsInkStyle] 后经 [DsThemeBridge]（已合并监听本控制器）
/// 重建主题树，全局即时生效。
class DsInkStyleController extends ChangeNotifier {
  static final DsInkStyleController _instance = DsInkStyleController._internal();

  factory DsInkStyleController() => _instance;

  DsInkStyleController._internal();

  /// 配置键名
  static const String _configKey = 'ds_ink_style';

  bool _initialized = false;
  bool get initialized => _initialized;

  /// 自选风格 id（null = 跟随主题预设默认值）
  String? _customStyleId;
  String? get customStyleId => _customStyleId;

  /// 最近一次应用的主题预设 id（「跟随主题」回落取其默认墨线）
  String _presetId = 'sketchbook';
  String get presetId => _presetId;

  /// 初始化：从配置加载描边风格并写入全局
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final config = await globalConfigManager.getPluginConfig(_configKey);
      if (config != null) {
        final customId = config['customStyleId'] as String?;
        if (customId != null && DsStrokeStyles.byId(customId) != null) {
          _customStyleId = customId;
        }
        final presetId = config['presetId'] as String?;
        if (presetId != null) {
          _presetId = presetId;
        }
      }

      // 旧版配置（level + strokeWidth）迁移：精确匹配命名风格，
      // 未命中回落该档位的基础风格
      var style = DsStrokeStyles.byId(config?['styleId'] as String?);
      style ??= _migrateLegacy(config);

      DsInkStyle.apply(style ?? DsStrokeStyles.playful);
    } catch (e) {
      debugPrint('加载墨线风格配置失败: $e');
    }

    _initialized = true;
    notifyListeners();
  }

  /// 旧配置迁移：{level: int, strokeWidth: num} → 命名风格
  DsStrokeStyle? _migrateLegacy(Map? config) {
    if (config == null) return null;
    final index = config['level'] as int?;
    final strokeWidth = (config['strokeWidth'] as num?)?.toDouble();
    if (index == null ||
        index < 0 ||
        index >= DsInkStyle.labels.length ||
        strokeWidth == null) {
      return null;
    }
    return DsStrokeStyles.match(DsInkStyle.byIndex(index), strokeWidth);
  }

  /// 应用主题预设：记录预设 id；仅「跟随主题」时套用其默认墨线
  Future<void> applyPreset(DsThemePreset preset) async {
    _presetId = preset.id;
    if (_customStyleId == null) {
      DsInkStyle.apply(DsStrokeStyles.base[preset.inkIndex]);
    }
    await _save();
    notifyListeners();
  }

  /// 自选描边风格（优先于主题预设默认值）
  Future<void> setCustomStyle(String id) async {
    final style = DsStrokeStyles.byId(id);
    if (style == null || id == _customStyleId) return;

    _customStyleId = id;
    DsInkStyle.apply(style);
    await _save();
    notifyListeners();
  }

  /// 取消自选，恢复跟随主题预设默认墨线
  Future<void> clearCustom() async {
    if (_customStyleId == null) return;

    _customStyleId = null;
    DsInkStyle.apply(DsStrokeStyles.base[DsThemePresets.byId(_presetId).inkIndex]);
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await globalConfigManager.savePluginConfig(_configKey, {
        'customStyleId': _customStyleId,
        'presetId': _presetId,
        // 冗余存一份当前风格，供旧版本回滚时经 level/strokeWidth 迁移
        'styleId': DsInkStyle.current.id,
        'level': DsInkStyle.index,
        'strokeWidth': DsInkStyle.strokeWidth,
      });
    } catch (e) {
      debugPrint('保存墨线风格配置失败: $e');
    }
  }
}
