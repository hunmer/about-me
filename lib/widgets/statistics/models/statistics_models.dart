import 'package:flutter/material.dart';

/// 日期范围选项
enum DateRangeOption {
  today,
  thisWeek,
  thisMonth,
  thisYear,
  custom,
}

/// 分布数据（用于饼图）
class DistributionData {
  final String label;
  final double value;
  final Color? color;
  final String? icon;

  const DistributionData({
    required this.label,
    required this.value,
    this.color,
    this.icon,
  });
}

/// 排行榜数据
class RankingData {
  final String label;
  final double value;
  final Color? color;
  final String? icon;
  final int? order;
  final Map<String, dynamic>? extraData;

  const RankingData({
    required this.label,
    required this.value,
    this.color,
    this.icon,
    this.order,
    this.extraData,
  });
}

/// 时间序列数据点
class TimeSeriesPoint {
  final DateTime date;
  final double value;

  const TimeSeriesPoint({
    required this.date,
    required this.value,
  });
}

/// 时间序列数据（用于趋势图）
class TimeSeriesData {
  final String label;
  final List<TimeSeriesPoint> points;
  final Color? color;

  const TimeSeriesData({
    required this.label,
    required this.points,
    this.color,
  });
}

/// 通用统计数据
class StatisticsData {
  /// 标题
  final String title;

  /// 副标题
  final String? subtitle;

  /// 日期范围
  final DateTime startDate;
  final DateTime endDate;

  /// 总量统计
  final double? totalValue;
  final String? totalValueLabel;

  /// 分布数据（饼图）
  final List<DistributionData>? distributionData;

  /// 排行榜数据
  final List<RankingData>? rankingData;

  /// 时间序列数据（趋势图）
  final List<TimeSeriesData>? timeSeriesData;

  /// 24小时分布数据（仅单日有效）
  final List<TimeSeriesPoint>? hourlyDistribution;

  /// 24小时分布的主要标签（可选，用于显示标签名称）
  final Map<int, String>? hourlyMainTags;

  /// 额外数据
  final Map<String, dynamic>? extraData;

  const StatisticsData({
    required this.title,
    this.subtitle,
    required this.startDate,
    required this.endDate,
    this.totalValue,
    this.totalValueLabel,
    this.distributionData,
    this.rankingData,
    this.timeSeriesData,
    this.hourlyDistribution,
    this.hourlyMainTags,
    this.extraData,
  });

  /// 是否为单日数据
  bool get isSingleDay {
    return startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day;
  }
}
