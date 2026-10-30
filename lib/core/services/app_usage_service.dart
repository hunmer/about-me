import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shared_models/shared_models.dart';
/// App 累计使用时长统计（仅前台时间）
///
/// - 生命周期 resumed → 离开前台区间累计，切后台/熄屏/退出时落盘
/// - 另有每分钟兜底落盘，进程被杀时最多丢 1 分钟
/// - 首次使用日期持久化，供"使用天数"展示
class AppUsageService with WidgetsBindingObserver {
  AppUsageService._();
  static final AppUsageService instance = AppUsageService._();

  static const _kTotalSeconds = 'app_usage_total_seconds';
  static const _kFirstUseDate = 'app_usage_first_use_date';

  SharedPreferences? _prefs;
  DateTime? _sessionStart;
  bool _initialized = false;

  int _totalSeconds = 0;
  DateTime _firstUseDate = DateTime.now();

  /// 累计使用秒数（含本次会话未落盘部分，读取即实时）
  int get totalSeconds {
    final start = _sessionStart;
    final live =
        start == null ? 0 : DateTime.now().difference(start).inSeconds;
    return _totalSeconds + live;
  }

  /// 首次使用日期
  DateTime get firstUseDate => _firstUseDate;

  /// 使用天数（首日起算含当天，最小 1）
  int get usageDays => DateTime.now().difference(_firstUseDate).inDays + 1;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _totalSeconds = prefs.getInt(_kTotalSeconds) ?? 0;

    final stored = prefs.getString(_kFirstUseDate);
    _firstUseDate = tryParseIsoDateTime(stored ?? '') ?? DateTime.now();
    if (stored == null) {
      await prefs.setString(_kFirstUseDate, _firstUseDate.toIso8601String());
    }

    _sessionStart = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    // 兜底落盘：单例随 app 存活，无需取消
    Timer.periodic(const Duration(minutes: 1), (_) => _flush());
    _initialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sessionStart ??= DateTime.now();
    } else {
      // inactive/hidden/paused/detached：结算本次前台区间
      _flush();
      _sessionStart = null;
    }
  }

  void _flush() {
    final prefs = _prefs;
    final start = _sessionStart;
    if (prefs == null || start == null) return;
    final delta = DateTime.now().difference(start).inSeconds;
    if (delta <= 0) return;
    _sessionStart = DateTime.now();
    _totalSeconds += delta;
    prefs.setInt(_kTotalSeconds, _totalSeconds);
  }
}
