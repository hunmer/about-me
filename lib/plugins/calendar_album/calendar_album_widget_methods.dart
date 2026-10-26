import 'package:flutter/material.dart';

import 'controllers/calendar_controller.dart';
import 'controllers/tag_controller.dart';
import 'models/calendar_entry.dart';

/// 日历相册插件的小组件支撑方法（统计 + 每周相册数据）
///
/// 从 calendar_album_plugin.dart 抽离，通过 mixin 挂到
/// [CalendarAlbumPlugin] 上，外部 `plugin.xxx()` 调用方式不变。
mixin CalendarAlbumWidgetMethods {
  /// 日历控制器（由插件主类提供）
  CalendarController? get calendarController;

  /// 标签控制器（由插件主类提供）
  TagController? get tagController;

  // ==================== 小组件统计方法 ====================

  /// 获取总照片数
  int getTotalPhotosCount() {
    try {
      final controller = calendarController;
      if (controller == null) {
        debugPrint('calendarController 未初始化');
        return 0;
      }
      return controller.getAllImages().length;
    } catch (e) {
      debugPrint('获取总照片数失败: $e');
      return 0;
    }
  }

  /// 获取今日新增照片数
  int getTodayPhotosCount() {
    try {
      final controller = calendarController;
      if (controller == null) {
        debugPrint('calendarController 未初始化');
        return 0;
      }
      final todayEntries = controller.getEntriesForDate(DateTime.now());
      int photoCount = 0;

      for (final entry in todayEntries) {
        // 统计imageUrls中的照片
        photoCount += entry.imageUrls.length;
        // 统计Markdown内容中的照片
        photoCount += entry.extractImagesFromMarkdown().length;
      }

      return photoCount;
    } catch (e) {
      debugPrint('获取今日新增照片数失败: $e');
      return 0;
    }
  }

  /// 获取标签总数
  int getTagsCount() {
    try {
      final controller = tagController;
      if (controller == null) {
        debugPrint('tagController 未初始化');
        return 0;
      }
      return controller.tags.length;
    } catch (e) {
      debugPrint('获取标签总数失败: $e');
      return 0;
    }
  }

  // ==================== 每周相册小组件相关方法 ====================

  /// 获取本周日记条目（用于每周相册小组件）
  /// @param weekOffset 相对于当前周的偏移量（0=当前周，1=下周，-1=上周）
  /// @param startDate 起始日期（可选，默认从周一开始）
  List<CalendarEntry> getWeeklyEntries({int weekOffset = 0, DateTime? startDate}) {
    try {
      final controller = calendarController;
      if (controller == null) {
        debugPrint('calendarController 未初始化');
        return [];
      }

      // 计算目标周的起始日期（周一）
      final now = DateTime.now();
      final currentWeekStart = _getWeekStart(now);
      final targetWeekStart = currentWeekStart.add(Duration(days: weekOffset * 7));

      final entries = <CalendarEntry>[];

      // 获取这一周每一天的日记
      for (int i = 0; i < 7; i++) {
        final date = targetWeekStart.add(Duration(days: i));
        entries.addAll(controller.getEntriesForDate(date));
      }

      // 按日期排序
      entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return entries;
    } catch (e) {
      debugPrint('获取本周日记失败: $e');
      return [];
    }
  }

  /// 获取指定日期的日记条目（周一到周日点击用）
  /// @param date 日期
  List<CalendarEntry> getEntriesForDate(DateTime date) {
    final controller = calendarController;
    if (controller == null) {
      debugPrint('calendarController 未初始化');
      return [];
    }
    return controller.getEntriesForDate(date);
  }

  /// 计算指定周的周开始日期（周一）
  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  /// 获取周信息（用于小组件标题显示）
  /// @param weekOffset 相对于当前周的偏移量
  Map<String, dynamic> getWeeklyInfo({int weekOffset = 0}) {
    final now = DateTime.now();
    final currentWeekStart = _getWeekStart(now);
    final targetWeekStart = currentWeekStart.add(Duration(days: weekOffset * 7));
    final weekEnd = targetWeekStart.add(const Duration(days: 6));

    // 计算这是第几周（基于年份）
    final yearStart = DateTime(now.year, 1, 1);
    final yearWeekStart = _getWeekStart(yearStart);
    final weekNumber = ((targetWeekStart.difference(yearWeekStart).inDays) / 7).floor() + 1;

    return {
      'weekNumber': weekNumber,
      'startDate': targetWeekStart,
      'endDate': weekEnd,
      'startDateStr': '${targetWeekStart.month}月 ${targetWeekStart.day}日',
      'endDateStr': '${weekEnd.month}月 ${weekEnd.day}日',
    };
  }
}
