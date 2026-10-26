import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 系统日历导入设置（仅移动端生效）
///
/// 引导第二步收集，控制是否读取系统日历事件以及是否包含节假日日历
class SystemCalendarSettings {
  static const String _prefsKey = 'calendar_system_calendar_settings';

  /// 是否导入系统日历（默认开启，保持既有行为）
  bool enabled = true;

  /// 导入系统日历时是否包含节假日日历
  bool includeHolidays = true;

  static Future<SystemCalendarSettings> load() async {
    final settings = SystemCalendarSettings();
    try {
      final prefs = await SharedPreferences.getInstance();
      settings.enabled = prefs.getBool('$_prefsKey.enabled') ?? true;
      settings.includeHolidays =
          prefs.getBool('$_prefsKey.includeHolidays') ?? true;
    } catch (e) {
      debugPrint('SystemCalendarSettings: 读取失败: $e');
    }
    return settings;
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefsKey.enabled', enabled);
      await prefs.setBool('$_prefsKey.includeHolidays', includeHolidays);
    } catch (e) {
      debugPrint('SystemCalendarSettings: 保存失败: $e');
    }
  }
}
