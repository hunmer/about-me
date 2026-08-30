import 'package:flutter/foundation.dart';

/// 主页日期控制器（单例）- 持有主页当前选中的日期
///
/// 按日期聚合的主页卡片（待办日卡、日记日卡等）通过监听本控制器，
/// 在日期变化时自动刷新为对应日期的数据。
///
/// 第二阶段的「日期横条」只需调用 [setDate] 即可驱动所有卡片，
/// 卡片自身不提供切换日期的交互。
class HomeDateController extends ChangeNotifier {
  // 单例模式
  static final HomeDateController _instance = HomeDateController._internal();
  factory HomeDateController() => _instance;
  HomeDateController._internal() {
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  late DateTime _date;

  /// 当前选中的日期（只含年月日，默认今天）
  DateTime get date => _date;

  /// 是否选中今天
  bool get isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  /// 设置选中日期
  ///
  /// 自动归一化到年月日（去掉时分秒），日期变化时通知监听者
  void setDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    if (normalized == _date) return;
    _date = normalized;
    notifyListeners();
  }
}
