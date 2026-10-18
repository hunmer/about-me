import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// 循环周期单位：截止日期 = 上次重置日期 + 叠加量
enum RecurrenceUnit { days, months, years }

class MemorialDay {
  final String id;
  final String title;
  final DateTime creationDate;
  final DateTime targetDate;
  final List<String> notes;

  /// 各笔记的创建时间（与 [notes] 索引对齐；旧数据为 null）
  final List<DateTime?> noteDates;
  final Color backgroundColor;
  final String? backgroundImageUrl;
  final int sortIndex;
  final IconData? icon;
  final Color? iconColor;

  /// 循环单位；null 表示不循环（targetDate 即截止日期）
  final RecurrenceUnit? recurrenceUnit;

  /// 循环叠加量（每 N 天 / 每 N 月 / 每 N 年），仅 [recurrenceUnit] 非 null 时生效
  final int recurrenceInterval;

  MemorialDay({
    String? id,
    required this.title,
    required this.targetDate,
    DateTime? creationDate,
    List<String>? notes,
    List<DateTime?>? noteDates,
    Color? backgroundColor,
    this.backgroundImageUrl,
    int? sortIndex,
    this.icon,
    this.iconColor,
    this.recurrenceUnit,
    int? recurrenceInterval,
  }) : id = id ?? const Uuid().v4(),
       creationDate = creationDate ?? DateTime.now(),
       notes = notes ?? [],
       // 不变式：noteDates 与 notes 等长（缺失补 null），
       // 否则新增笔记 append 的时间戳会错位到前面的行
       noteDates = _alignNoteDates(notes ?? [], noteDates),
       backgroundColor = backgroundColor ?? _getRandomColor(),
       sortIndex = sortIndex ?? 0,
       recurrenceInterval = recurrenceInterval ?? 1;

  /// 把 [dates] 对齐到 [notes] 的长度：短的补 null，长的截断
  static List<DateTime?> _alignNoteDates(
    List<String> notes,
    List<DateTime?>? dates,
  ) {
    return [
      for (var i = 0; i < notes.length; i++)
        dates != null && i < dates.length ? dates[i] : null,
    ];
  }

  // 是否开启循环
  bool get isRecurring => recurrenceUnit != null && recurrenceInterval > 0;

  /// [base] 叠加 [cycles] 个周期（可为负，用于回退到上一轮起点）
  DateTime _addCycle(DateTime base, [int cycles = 1]) {
    return switch (recurrenceUnit) {
      RecurrenceUnit.days => DateTime(
        base.year,
        base.month,
        base.day + cycles * recurrenceInterval,
      ),
      RecurrenceUnit.months => DateTime(
        base.year,
        base.month + cycles * recurrenceInterval,
        base.day,
      ),
      RecurrenceUnit.years => DateTime(
        base.year + cycles * recurrenceInterval,
        base.month,
        base.day,
      ),
      null => base,
    };
  }

  /// 上次重置循环日期：循环开启时随过期自动推进到当前一轮的起点
  DateTime get cycleStartDate {
    if (!isRecurring) return targetDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(targetDate.year, targetDate.month, targetDate.day);
    // 截止日期取第一个不早于今天的循环点；目标日期尚未到期时就是它本身，
    // 不能再多叠加一轮（否则生日还剩30天+每12月循环会显示390+天）
    if (recurrenceUnit == RecurrenceUnit.days) {
      // 按天可整除，直接算出让截止日不早于今天的最小倍数，避免逐轮循环
      final diff = today.difference(start).inDays;
      final k =
          diff <= 0 ? 0 : (diff + recurrenceInterval - 1) ~/ recurrenceInterval;
      return _addCycle(start, k - 1);
    }
    var due = start;
    while (due.isBefore(today)) {
      due = _addCycle(due);
    }
    return _addCycle(due, -1);
  }

  /// 实际生效的截止日期：循环时为 上次重置日期 + 叠加量，否则为所选日期
  DateTime get effectiveTargetDate =>
      isRecurring ? _addCycle(cycleStartDate) : targetDate;

  /// 循环摘要文案（"每3天"/"每2月"/"每1年"）；未开启循环返回 null
  String? get recurrenceSummary {
    if (!isRecurring) return null;
    return switch (recurrenceUnit) {
      RecurrenceUnit.days => 'day_everyDays'.trParams({
        'count': recurrenceInterval.toString(),
      }),
      RecurrenceUnit.months => 'day_everyMonths'.trParams({
        'count': recurrenceInterval.toString(),
      }),
      RecurrenceUnit.years => 'day_everyYears'.trParams({
        'count': recurrenceInterval.toString(),
      }),
      null => null,
    };
  }

  // 计算剩余天数
  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = effectiveTargetDate;
    return DateTime(target.year, target.month, target.day)
        .difference(today)
        .inDays;
  }

  // 判断是否已经过期
  bool get isExpired => daysRemaining < 0;

  // 计算已经过去的天数（如果已过期）
  int get daysPassed => isExpired ? -daysRemaining : 0;

  // 计算纪念日是否在今天
  bool get isToday => daysRemaining == 0;

  // 获取格式化的日期字符串（循环时展示实际生效的截止日期）
  String get formattedTargetDate {
    final d = effectiveTargetDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // 从JSON创建实例
  factory MemorialDay.fromJson(Map<String, dynamic> json) {
    return MemorialDay(
      id: json['id'],
      title: json['title'],
      creationDate: DateTime.parse(json['creationDate']),
      targetDate: DateTime.parse(json['targetDate']),
      notes: List<String>.from(json['notes'] ?? []),
      noteDates:
          (json['noteDates'] as List<dynamic>? ?? [])
              .map(
                (e) => e == null ? null : DateTime.parse(e as String),
              )
              .toList(),
      backgroundColor: Color(json['backgroundColor']),
      backgroundImageUrl: json['backgroundImageUrl'],
      sortIndex: json['sortIndex'] ?? 0,
      icon:
          json['icon'] != null
              ? dynamicIconData(json['icon'], fontFamily: 'MaterialIcons')
              : null,
      iconColor: json['iconColor'] != null ? Color(json['iconColor']) : null,
      recurrenceUnit:
          json['recurrenceUnit'] == null
              ? null
              : RecurrenceUnit.values.byName(json['recurrenceUnit']),
      recurrenceInterval: json['recurrenceInterval'] ?? 1,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'creationDate': creationDate.toIso8601String(),
      'targetDate': targetDate.toIso8601String(),
      'notes': notes,
      'noteDates': noteDates.map((d) => d?.toIso8601String()).toList(),
      // ignore: deprecated_member_use
      'backgroundColor': backgroundColor.value,
      'backgroundImageUrl': backgroundImageUrl,
      'sortIndex': sortIndex,
      'icon': icon?.codePoint,
      'iconColor': iconColor?.value,
      'recurrenceUnit': recurrenceUnit?.name,
      'recurrenceInterval': recurrenceInterval,
    };
  }

  // 生成随机颜色
  static Color _getRandomColor() {
    final random = Random();
    final colors = [
      Colors.red[300],
      Colors.pink[300],
      Colors.purple[300],
      Colors.deepPurple[300],
      Colors.indigo[300],
      Colors.blue[300],
      Colors.lightBlue[300],
      Colors.cyan[300],
      Colors.teal[300],
      Colors.green[300],
      Colors.lightGreen[300],
      Colors.amber[300],
      Colors.orange[300],
    ];
    return colors[random.nextInt(colors.length)]!;
  }

  // 创建带有修改的副本
  MemorialDay copyWith({
    String? id,
    String? title,
    DateTime? targetDate,
    List<String>? notes,
    List<DateTime?>? noteDates,
    Color? backgroundColor,
    String? backgroundImageUrl,
    int? sortIndex,
    IconData? icon,
    Color? iconColor,
    RecurrenceUnit? recurrenceUnit,
    int? recurrenceInterval,
  }) {
    return MemorialDay(
      id: id ?? this.id,
      title: title ?? this.title,
      creationDate: creationDate,
      targetDate: targetDate ?? this.targetDate,
      notes: notes ?? this.notes,
      noteDates: noteDates ?? this.noteDates,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      sortIndex: sortIndex ?? this.sortIndex,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      recurrenceUnit: recurrenceUnit ?? this.recurrenceUnit,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
    );
  }

  // 创建测试数据
  static List<MemorialDay> generateTestData() {
    final now = DateTime.now();
    final random = Random();

    return [
      MemorialDay(
        title: '新年倒计时',
        targetDate: DateTime(now.year + 1, 1, 1),
        notes: ['准备跨年活动', '购买礼物'],
      ),
      MemorialDay(
        title: '生日',
        targetDate: DateTime(now.year, now.month + 2, 15),
        notes: ['准备派对', '邀请朋友'],
      ),
      MemorialDay(
        title: '毕业纪念日',
        targetDate: DateTime(now.year - 2, 6, 30),
        notes: ['已经毕业两年了'],
      ),
      MemorialDay(
        title: '结婚纪念日',
        targetDate: DateTime(now.year, now.month, now.day + random.nextInt(10)),
        notes: ['准备惊喜', '订餐厅'],
      ),
      MemorialDay(
        title: '项目截止日',
        targetDate: DateTime(now.year, now.month, now.day + random.nextInt(30)),
        notes: ['完成文档', '准备演示'],
      ),
    ];
  }
}
