import 'package:flutter/foundation.dart';

import 'package:aboutme/core/app_initializer.dart';

/// 贴条样式（枚举居控制器以便持久化；hand_drawn_list_view 转发导出）
enum HandDrawnTapeStyle {
  /// 顶部居中胶带:skribble 墨线 + 不透明纸底 + 三个圆孔
  centerTape('settings_screen_tapeStyleCenterTape'),

  /// 左上角文件夹标签页:墨线纸底叠在卡体上沿,可显示标题文字
  /// （需调用点传 tapeTitle,不进全局选择）
  folderTab(''),

  /// 半透明和纸胶带:无孔、微倾斜、卡体透色
  washiTape('settings_screen_tapeStyleWashiTape'),

  /// 双角斜贴:左上/右上两条短胶带反向微斜
  cornerTapes('settings_screen_tapeStyleCornerTapes'),

  /// 订书钉:顶部两枚钉扣固定
  staple('settings_screen_tapeStyleStaple');

  const HandDrawnTapeStyle(this.labelKey);

  /// 设置页选项文案 key（folderTab 不进全局选择,留空）
  final String labelKey;

  /// 按名字解析（配置读取用）,未知值回落 centerTape
  static HandDrawnTapeStyle byNameOrDefault(String? name) =>
      HandDrawnTapeStyle.values.asNameMap()[name] ?? HandDrawnTapeStyle.centerTape;
}

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
  HandDrawnTapeStyle _tapeStyle = HandDrawnTapeStyle.centerTape;

  /// 是否绘制顶部贴条（含 folderTab 标签页）
  bool get tapeEnabled => _tapeEnabled;

  /// 是否启用倾斜姿态（关闭后角度与水平偏移归零，悬浮动效保留）
  bool get tiltEnabled => _tiltEnabled;

  /// 是否启用入场动画（淡入 + 上滑，列表按索引瀑布延迟）
  bool get entranceEnabled => _entranceEnabled;

  /// 全局默认贴条样式（组件未显式指定 tapeStyle 时跟随）
  HandDrawnTapeStyle get tapeStyle => _tapeStyle;

  /// 初始化：从配置加载开关状态
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final config = await globalConfigManager.getPluginConfig(_configKey);
      if (config != null) {
        _tapeEnabled = config['tape'] as bool? ?? true;
        _tiltEnabled = config['tilt'] as bool? ?? true;
        _entranceEnabled = config['entrance'] as bool? ?? true;
        _tapeStyle = HandDrawnTapeStyle.byNameOrDefault(
          config['tapeStyle'] as String?,
        );
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

  /// 切换全局默认贴条样式（即时生效并持久化）
  Future<void> setTapeStyle(HandDrawnTapeStyle style) async {
    if (style == _tapeStyle) return;
    _tapeStyle = style;
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await globalConfigManager.savePluginConfig(_configKey, {
        'tape': _tapeEnabled,
        'tilt': _tiltEnabled,
        'entrance': _entranceEnabled,
        'tapeStyle': _tapeStyle.name,
      });
    } catch (e) {
      debugPrint('保存手绘风格配置失败: $e');
    }
  }
}
