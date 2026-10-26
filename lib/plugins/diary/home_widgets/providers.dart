/// 日记插件主页小组件数据提供者
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/common_widgets.dart';
import '../widgets/diary_query_guard.dart';
import '../diary_plugin.dart';
import '../models/diary_entry.dart';
import '../utils/diary_utils.dart';
import '../widgets/diary_mood_face.dart';
import 'utils.dart';

/// 公共小组件提供者函数 - 本月日记列表
///
/// 异步加载本月日记数据，返回可用的公共小组件配置
Future<Map<String, Map<String, dynamic>>> provideMonthlyDiaryListWidgets(
  Map<String, dynamic> data,
) async {
  final plugin = PluginManager.instance.getPlugin('diary') as DiaryPlugin?;
  if (plugin == null) return {};

  final now = DateTime.now();
  final year = now.year;
  final month = now.month;
  final totalDays = DateTime(year, month + 1, 0).day;

  // 异步加载所有日记条目
  final allEntries = await DiaryUtils.loadDiaryEntries();

  // 过滤本月的日记
  final monthlyEntries = <DateTime, DiaryEntry>{};
  for (final entry in allEntries.entries) {
    if (entry.key.year == year && entry.key.month == month) {
      monthlyEntries[entry.key] = entry.value;
    }
  }

  final entryCount = monthlyEntries.length;

  // 计算统计数据
  final totalWordCount = monthlyEntries.values.fold<int>(
    0,
    (sum, e) => sum + (DiaryUtils.contentToPlainText(e.content).trim().length),
  );

  // 按心情统计
  final moodStats = <String, int>{};
  for (final entry in monthlyEntries.values) {
    if (entry.mood != null && entry.mood!.isNotEmpty) {
      moodStats[entry.mood!] = (moodStats[entry.mood!] ?? 0) + 1;
    }
  }

  // 按日期排序（倒序）
  final sortedEntries = monthlyEntries.entries.toList()
    ..sort((a, b) => b.key.compareTo(a.key));

  return {
    // 任务进度列表卡片 - 显示本月日记进度
    'taskProgressList': {
      'title': '本月日记',
      'icon': Icons.book.codePoint,
      'tasks': sortedEntries.take(5).map((e) {
        final dateStr = DateFormat('MM月dd日').format(e.key);
        final wordCount = DiaryUtils.contentToPlainText(
          e.value.content,
        ).trim().length;
        final progress = wordCount > 500
            ? 1.0
            : (wordCount / 500).clamp(0.0, 1.0);
        String status;
        if (wordCount >= 500) {
          status = 'completed';
        } else if (wordCount >= 200) {
          status = 'inProgress';
        } else {
          status = 'started';
        }
        return {
          'title': e.value.title.isNotEmpty ? e.value.title : '无标题日记',
          'time': dateStr,
          'progress': progress,
          'status': status,
        };
      }).toList(),
      'moreCount': (entryCount - 5).clamp(0, 999),
    },

    // 每周点追踪卡片 - 显示本月每日打卡情况
    'monthlyDotTrackerCard': {
      'title': '本月日记打卡',
      'currentValue': entryCount,
      'totalDays': totalDays,
      'iconCodePoint': Icons.edit_calendar.codePoint,
      'daysData': List.generate(totalDays, (index) {
        final day = index + 1;
        final date = DateTime(year, month, day);
        final hasEntry = monthlyEntries.containsKey(date);
        return {'day': day, 'isChecked': hasEntry};
      }),
    },

    // 任务列表卡片 - 显示本月日记列表
    'taskListCard': {
      'title': '本月日记',
      'count': entryCount,
      'countLabel': '篇日记',
      'items': sortedEntries.take(8).map((e) {
        final title = e.value.title.isNotEmpty ? e.value.title : '无标题日记';
        return '$title (${DateFormat('MM月dd日').format(e.key)})';
      }).toList(),
      'moreCount': (entryCount - 8).clamp(0, 999),
    },

    // 月度进度圆点卡片 - 与 monthlyDotTrackerCard 类似
    'monthlyProgressDotsCard': {
      'title': '本月日记打卡',
      'currentValue': entryCount,
      'totalDays': totalDays,
      'iconCodePoint': Icons.edit_calendar.codePoint,
      'daysData': List.generate(totalDays, (index) {
        final day = index + 1;
        final date = DateTime(year, month, day);
        final hasEntry = monthlyEntries.containsKey(date);
        return {'day': day, 'isChecked': hasEntry};
      }),
    },

    // 消息列表卡片 - 显示日记摘要列表
    'messageListCard': {
      'featuredMessage': {
        'sender': '我的日记',
        'title': entryCount > 0
            ? '本月已记录 ${DiaryUtils.contentToPlainText(sortedEntries.first.value.content).trim().length} 字'
            : '开始记录你的生活',
        'summary': entryCount > 0
            ? '本月共写了 $entryCount 篇日记，总计 $totalWordCount 字'
            : '点击开始写第一篇日记',
        'avatarUrl': '',
      },
      'messages': sortedEntries.take(5).map((e) {
        final dateStr = DateFormat('MM月dd日 EEEE', 'zh_CN').format(e.key);
        final title = e.value.title.isNotEmpty ? e.value.title : '无标题日记';
        final mood = _moodEmojiOf(e.value.mood);
        return {
          'title': '$mood $title',
          'sender': dateStr,
          'channel':
              '${DiaryUtils.contentToPlainText(e.value.content).trim().length} 字',
          'avatarUrl': '',
        };
      }).toList(),
    },

    // 彩色标签任务卡片 - 按心情分类显示日记
    'colorTagTaskCard': {
      'taskCount': entryCount,
      'label': '本月日记',
      'tasks': sortedEntries.map((e) {
        final title = e.value.title.isNotEmpty ? e.value.title : '无标题日记';
        final dateStr = DateFormat('MM月dd日').format(e.key);
        final mood = _moodEmojiOf(e.value.mood, '😊');
        // 根据心情映射颜色
        int colorValue;
        switch (mood) {
          case '😊':
            colorValue = Colors.yellow.value;
            break;
          case '😢':
            colorValue = Colors.blue.value;
            break;
          case '😡':
            colorValue = Colors.red.value;
            break;
          default:
            colorValue = Colors.indigo.value;
        }
        return {
          'title': '($dateStr)',
          'color': colorValue,
          'tag': '$mood $title',
        };
      }).toList(),
      'moreCount': 0,
    },

    // 收件箱消息卡片
    'inboxMessageCard': {
      'title': '日记列表',
      'messages': sortedEntries.take(6).map((e) {
        final title = e.value.title.isNotEmpty ? e.value.title : '无标题日记';
        final dateStr = DateFormat('MM月dd日').format(e.key);
        final mood = _moodEmojiOf(e.value.mood);
        final text = DiaryUtils.contentToPlainText(e.value.content).trim();
        final preview = text.length > 50 ? '${text.substring(0, 50)}...' : text;
        return {
          'title': title,
          'subtitle': '$dateStr ${mood.isNotEmpty ? '· $mood' : ''}',
          'content': preview,
          'time': dateStr,
          'isRead': true,
          'avatarUrl': null,
        };
      }).toList(),
      'unreadCount': 0,
    },

    // 即将到来的任务小组件 - 显示最近的日记
    'upcomingTasksWidget': {
      'title': '最近日记',
      'taskCount': entryCount.clamp(0, 4),
      'moreCount': (entryCount - 4).clamp(0, 999),
      'tasks': sortedEntries.take(4).map((e) {
        final title = e.value.title.isNotEmpty ? e.value.title : '无标题日记';
        final dateStr = DateFormat('MM月dd日').format(e.key);
        final mood = _moodEmojiOf(e.value.mood, '😊');
        int colorValue = Colors.indigo.value;
        if (mood == '😊') {
          colorValue = Colors.yellow.value;
        } else if (mood == '😢') {
          colorValue = Colors.blue.value;
        } else if (mood == '😡') {
          colorValue = Colors.red.value;
        }
        return {'title': title, 'color': colorValue, 'tag': dateStr};
      }).toList(),
    },

    // 圆角提醒事项列表 - 显示日记提醒
    'roundedRemindersList': {
      'title': '本月日记',
      'count': entryCount,
      'items': sortedEntries.take(5).map((e) {
        final title = e.value.title.isNotEmpty ? e.value.title : '无标题日记';
        final dateStr = DateFormat('MM月dd日').format(e.key);
        return {'text': '$dateStr - $title', 'isCompleted': true};
      }).toList(),
    },
  };
}

/// 构建本月日记列表通用小组件（根据配置渲染选中的公共小组件）
Widget buildMonthlyDiaryListWidget(
  BuildContext context,
  Map<String, dynamic> config,
) {
  final selectorConfig =
      config['selectorWidgetConfig'] as Map<String, dynamic>?;
  if (selectorConfig == null) {
    return HomeWidget.buildErrorWidget(context, '配置错误：缺少 selectorWidgetConfig');
  }

  final commonWidgetId = selectorConfig['commonWidgetId'] as String?;

  if (commonWidgetId == null) {
    return HomeWidget.buildErrorWidget(context, '配置错误：缺少 commonWidgetId');
  }

  // 查找对应的 CommonWidgetId 枚举
  final widgetIdEnum = CommonWidgetId.values.asNameMap()[commonWidgetId];
  if (widgetIdEnum == null) {
    return HomeWidget.buildErrorWidget(context, '未知的公共小组件类型: $commonWidgetId');
  }

  // 使用专用的 StatefulWidget 来持有缓存数据
  return _MonthlyDiaryListStatefulWidget(
    config: config,
    commonWidgetId: commonWidgetId,
  );
}

/// 内部 StatefulWidget 用于持有缓存的事件数据
class _MonthlyDiaryListStatefulWidget extends StatelessWidget {
  final Map<String, dynamic> config;
  final String commonWidgetId;
  const _MonthlyDiaryListStatefulWidget({
    required this.config,
    required this.commonWidgetId,
  });

  @override
  Widget build(BuildContext context) => DiarySnapshotBuilder(
    builder: (context, entries) {
      final now = DateTime.now();
      final monthly = entries.entries
          .where(
            (entry) =>
                entry.key.year == now.year && entry.key.month == now.month,
          )
          .map((entry) => (entry.key, entry.value))
          .toList();
      return _buildMonthlyDiaryListContent(
        context,
        config,
        commonWidgetId,
        monthly,
      );
    },
  );
}

/// 构建本月日记列表内容
/// [cachedEntries] 事件携带的缓存数据（性能优化），为 null 时从插件获取
Widget _buildMonthlyDiaryListContent(
  BuildContext context,
  Map<String, dynamic> config,
  String commonWidgetId,
  List<(DateTime, DiaryEntry)>? cachedEntries,
) {
  // 查找对应的 CommonWidgetId 枚举
  final widgetIdEnum = CommonWidgetId.values.asNameMap()[commonWidgetId];
  if (widgetIdEnum == null) {
    return HomeWidget.buildErrorWidget(context, '未知的公共小组件类型: $commonWidgetId');
  }

  // 获取元数据以确定默认尺寸
  final metadata = CommonWidgetsRegistry.getMetadata(widgetIdEnum);
  final size = config['widgetSize'] as HomeWidgetSize? ?? metadata.defaultSize;

  // 优先使用事件携带的缓存数据（性能优化），否则从插件获取
  final latestProps = _getMonthlyDiaryListDataSync(
    commonWidgetId,
    cachedEntries,
  );

  return CommonWidgetBuilder.build(
    context,
    widgetIdEnum,
    latestProps ?? {},
    size,
    inline: true,
  );
}

/// 同步获取本月日记列表小组件数据
/// [cachedEntries] 事件携带的缓存数据（性能优化），为 null 时从插件获取
Map<String, dynamic>? _getMonthlyDiaryListDataSync(
  String commonWidgetId,
  List<(DateTime, DiaryEntry)>? cachedEntries,
) {
  try {
    // 优先使用事件携带的缓存数据（性能优化）
    List<(DateTime, DiaryEntry)> monthlyEntries;

    if (cachedEntries != null) {
      monthlyEntries = cachedEntries;
    } else {
      // 回退：从插件同步获取（首次构建或向后兼容）
      final plugin = PluginManager.instance.getPlugin('diary') as DiaryPlugin?;
      if (plugin == null) return null;
      monthlyEntries = plugin.getMonthlyDiaryEntriesSync();
    }

    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final totalDays = DateTime(year, month + 1, 0).day;
    final entryCount = monthlyEntries.length;

    // 转换为 Map<DateTime, DiaryEntry> 格式用于统计
    final entriesMap = <DateTime, DiaryEntry>{};
    for (final entry in monthlyEntries) {
      entriesMap[entry.$1] = entry.$2;
    }

    // 计算统计数据
    final totalWordCount = entriesMap.values.fold<int>(
      0,
      (sum, e) =>
          sum + (DiaryUtils.contentToPlainText(e.content).trim().length),
    );

    // 按心情统计
    final moodStats = <String, int>{};
    for (final entry in entriesMap.values) {
      if (entry.mood != null && entry.mood!.isNotEmpty) {
        final id = diaryMoodIdOf(entry.mood!);
        moodStats[id] = (moodStats[id] ?? 0) + 1;
      }
    }

    // 按日期排序（倒序）
    final sortedEntries = monthlyEntries.toList()
      ..sort((a, b) => b.$1.compareTo(a.$1));

    // 根据 commonWidgetId 返回对应的数据
    switch (commonWidgetId) {
      case 'taskProgressList':
        return {
          'title': '本月日记',
          'icon': Icons.book.codePoint,
          'tasks': sortedEntries.take(5).map((e) {
            final dateStr = DateFormat('MM月dd日').format(e.$1);
            final wordCount = DiaryUtils.contentToPlainText(
              e.$2.content,
            ).trim().length;
            final progress = wordCount > 500
                ? 1.0
                : (wordCount / 500).clamp(0.0, 1.0);
            String status;
            if (wordCount >= 500) {
              status = 'completed';
            } else if (wordCount >= 200) {
              status = 'inProgress';
            } else {
              status = 'started';
            }
            return {
              'title': e.$2.title.isNotEmpty ? e.$2.title : '无标题日记',
              'time': dateStr,
              'progress': progress,
              'status': status,
            };
          }).toList(),
          'moreCount': (entryCount - 5).clamp(0, 999),
        };

      case 'monthlyDotTrackerCard':
        return {
          'title': '本月日记打卡',
          'currentValue': entryCount,
          'totalDays': totalDays,
          'iconCodePoint': Icons.edit_calendar.codePoint,
          'daysData': List.generate(totalDays, (index) {
            final day = index + 1;
            final date = DateTime(year, month, day);
            final hasEntry = entriesMap.containsKey(date);
            return {'day': day, 'isChecked': hasEntry};
          }),
        };

      case 'monthlyProgressDotsCard':
        return {
          'title': '本月日记打卡',
          'currentValue': entryCount,
          'totalDays': totalDays,
          'iconCodePoint': Icons.edit_calendar.codePoint,
          'daysData': List.generate(totalDays, (index) {
            final day = index + 1;
            final date = DateTime(year, month, day);
            final hasEntry = entriesMap.containsKey(date);
            return {'day': day, 'isChecked': hasEntry};
          }),
        };

      case 'taskListCard':
        return {
          'title': '本月日记',
          'count': entryCount,
          'countLabel': '篇日记',
          'items': sortedEntries.take(8).map((e) {
            final title = e.$2.title.isNotEmpty ? e.$2.title : '无标题日记';
            return '$title (${DateFormat('MM月dd日').format(e.$1)})';
          }).toList(),
          'moreCount': (entryCount - 8).clamp(0, 999),
        };

      case 'messageListCard':
        return {
          'featuredMessage': {
            'sender': '我的日记',
            'title': entryCount > 0
                ? '本月已记录 ${sortedEntries.first.$2.content.length} 字'
                : '开始记录你的生活',
            'summary': entryCount > 0
                ? '本月共写了 $entryCount 篇日记，总计 $totalWordCount 字'
                : '点击开始写第一篇日记',
            'avatarUrl': '',
          },
          'messages': sortedEntries.take(5).map((e) {
            final dateStr = DateFormat('MM月dd日 EEEE', 'zh_CN').format(e.$1);
            final title = e.$2.title.isNotEmpty ? e.$2.title : '无标题日记';
            final mood = _moodEmojiOf(e.$2.mood);
            return {
              'title': '$mood $title',
              'sender': dateStr,
              'channel':
                  '${DiaryUtils.contentToPlainText(e.$2.content).trim().length} 字',
              'avatarUrl': '',
            };
          }).toList(),
        };

      case 'colorTagTaskCard':
        return {
          'taskCount': entryCount,
          'label': '本月日记',
          'tasks': sortedEntries.map((e) {
            final title = e.$2.title.isNotEmpty ? e.$2.title : '无标题日记';
            final dateStr = DateFormat('MM月dd日').format(e.$1);
            final mood = _moodEmojiOf(e.$2.mood, '😊');
            int colorValue;
            switch (mood) {
              case '😊':
                colorValue = Colors.yellow.value;
                break;
              case '😢':
                colorValue = Colors.blue.value;
                break;
              case '😡':
                colorValue = Colors.red.value;
                break;
              default:
                colorValue = Colors.indigo.value;
            }
            return {
              'title': '($dateStr)',
              'color': colorValue,
              'tag': '$mood $title',
            };
          }).toList(),
          'moreCount': 0,
        };

      case 'inboxMessageCard':
        return {
          'title': '日记列表',
          'messages': sortedEntries.take(6).map((e) {
            final title = e.$2.title.isNotEmpty ? e.$2.title : '无标题日记';
            final dateStr = DateFormat('MM月dd日').format(e.$1);
            final mood = _moodEmojiOf(e.$2.mood);
            final text = DiaryUtils.contentToPlainText(e.$2.content).trim();
            final preview = text.length > 50
                ? '${text.substring(0, 50)}...'
                : text;
            return {
              'title': title,
              'subtitle': '$dateStr ${mood.isNotEmpty ? '· $mood' : ''}',
              'content': preview,
              'time': dateStr,
              'isRead': true,
              'avatarUrl': null,
            };
          }).toList(),
          'unreadCount': 0,
        };

      case 'upcomingTasksWidget':
        return {
          'title': '最近日记',
          'taskCount': entryCount.clamp(0, 4),
          'moreCount': (entryCount - 4).clamp(0, 999),
          'tasks': sortedEntries.take(4).map((e) {
            final title = e.$2.title.isNotEmpty ? e.$2.title : '无标题日记';
            final dateStr = DateFormat('MM月dd日').format(e.$1);
            final mood = _moodEmojiOf(e.$2.mood, '😊');
            int colorValue = Colors.indigo.value;
            if (mood == '😊') {
              colorValue = Colors.yellow.value;
            } else if (mood == '😢') {
              colorValue = Colors.blue.value;
            } else if (mood == '😡') {
              colorValue = Colors.red.value;
            }
            return {'title': title, 'color': colorValue, 'tag': dateStr};
          }).toList(),
        };

      case 'roundedRemindersList':
        return {
          'title': '本月日记',
          'count': entryCount,
          'items': sortedEntries.take(5).map((e) {
            final title = e.$2.title.isNotEmpty ? e.$2.title : '无标题日记';
            final dateStr = DateFormat('MM月dd日').format(e.$1);
            return {'text': '$dateStr - $title', 'isCompleted': true};
          }).toList(),
        };

      default:
        return null;
    }
  } catch (e) {
    debugPrint('[Diary] 获取本月日记数据失败: $e');
    return null;
  }
}

/// 公共小组件提供者函数 - 七日周报
///
/// 异步加载本周日记数据，返回可用的公共小组件配置
Future<Map<String, Map<String, dynamic>>> provideWeeklyDiaryWidgets(
  Map<String, dynamic> data,
) async {
  final plugin = PluginManager.instance.getPlugin('diary') as DiaryPlugin?;
  if (plugin == null) return {};

  final now = DateTime.now();

  // 异步加载所有日记条目
  final allEntries = await DiaryUtils.loadDiaryEntries();

  // 获取本周日期
  final weekDays = getCurrentWeekDays(now);

  // 过滤本周的日记
  final weeklyEntries = <DateTime, DiaryEntry>{};
  for (final date in weekDays) {
    final entry = allEntries[DateTime(date.year, date.month, date.day)];
    if (entry != null) {
      weeklyEntries[date] = entry;
    }
  }

  // 统计本周心情
  final moodStats = <String, int>{};
  for (final entry in weeklyEntries.values) {
    if (entry.mood != null && entry.mood!.isNotEmpty) {
      moodStats[entry.mood!] = (moodStats[entry.mood!] ?? 0) + 1;
    }
  }

  // 创建心情图表数据
  final moodChartData = moodStats.entries.map((e) {
    final emoji = diaryMoodSpecOf(e.key).emoji;
    final label = _getMoodLabel(emoji);
    final value = e.value;
    return {'emoji': emoji, 'label': label, 'value': value};
  }).toList();

  return {
    // 七日周报小组件 - 标准样式
    'weeklyDiaryWidget': {
      'title': '本周日记',
      'showTitle': true,
      'primaryColor': Colors.indigo.value,
    },

    // 心情图表卡片
    'moodChartCard': {
      'title': '本周心情',
      'subtitle': '共 ${weeklyEntries.length} 篇日记',
      'moods': moodChartData,
      'displayType': 'emoji',
      'primaryColor': Colors.indigo.value,
    },
  };
}

/// 获取心情标签
/// 心情值 -> 显示用 emoji（mood 存储 id，旧数据可能是 emoji）
String _moodEmojiOf(String? mood, [String fallback = '']) =>
    mood == null || mood.isEmpty ? fallback : diaryMoodSpecOf(mood).emoji;

String _getMoodLabel(String emoji) {
  final moodLabels = {
    '😊': '开心',
    '😢': '难过',
    '😡': '生气',
    '😴': '困倦',
    '🤔': '思考',
    '😎': '酷',
    '😍': '喜欢',
    '🤮': '不适',
    '😱': '惊讶',
    '🥳': '庆祝',
  };
  return moodLabels[emoji] ?? '其他';
}

/// 构建七日周报通用小组件（根据配置渲染选中的公共小组件）
Widget buildWeeklyDiaryWidget(
  BuildContext context,
  Map<String, dynamic> config,
) {
  final selectorConfig =
      config['selectorWidgetConfig'] as Map<String, dynamic>?;
  if (selectorConfig == null) {
    return HomeWidget.buildErrorWidget(context, '配置错误：缺少 selectorWidgetConfig');
  }

  final commonWidgetId = selectorConfig['commonWidgetId'] as String?;

  if (commonWidgetId == null) {
    return HomeWidget.buildErrorWidget(context, '配置错误：缺少 commonWidgetId');
  }

  // 查找对应的 CommonWidgetId 枚举
  final widgetIdEnum = CommonWidgetId.values.asNameMap()[commonWidgetId];
  if (widgetIdEnum == null) {
    return HomeWidget.buildErrorWidget(context, '未知的公共小组件类型: $commonWidgetId');
  }

  // 使用专用的 StatefulWidget 来持有缓存数据
  return _WeeklyDiaryStatefulWidget(
    config: config,
    commonWidgetId: commonWidgetId,
  );
}

/// 内部 StatefulWidget 用于持有缓存的事件数据
class _WeeklyDiaryStatefulWidget extends StatelessWidget {
  final Map<String, dynamic> config;
  final String commonWidgetId;
  const _WeeklyDiaryStatefulWidget({
    required this.config,
    required this.commonWidgetId,
  });

  @override
  Widget build(BuildContext context) => DiarySnapshotBuilder(
    builder: (context, entries) => _buildWeeklyDiaryContent(
      context,
      config,
      commonWidgetId,
      entries.entries.map((entry) => (entry.key, entry.value)).toList(),
    ),
  );
}

/// 构建七日周报内容
/// [cachedEntries] 事件携带的缓存数据（性能优化），为 null 时从插件获取
Widget _buildWeeklyDiaryContent(
  BuildContext context,
  Map<String, dynamic> config,
  String commonWidgetId,
  List<(DateTime, DiaryEntry)>? cachedEntries,
) {
  // 查找对应的 CommonWidgetId 枚举
  final widgetIdEnum = CommonWidgetId.values.asNameMap()[commonWidgetId];
  if (widgetIdEnum == null) {
    return HomeWidget.buildErrorWidget(context, '未知的公共小组件类型: $commonWidgetId');
  }

  // 获取元数据以确定默认尺寸
  final metadata = CommonWidgetsRegistry.getMetadata(widgetIdEnum);
  final size = config['widgetSize'] as HomeWidgetSize? ?? metadata.defaultSize;

  // 获取最新数据
  final latestProps = _getWeeklyDiaryDataSync(commonWidgetId, cachedEntries);

  return CommonWidgetBuilder.build(
    context,
    widgetIdEnum,
    latestProps ?? {},
    size,
    inline: true,
  );
}

/// 同步获取七日周报小组件数据
/// [cachedEntries] 事件携带的缓存数据（性能优化），为 null 时从插件获取
Map<String, dynamic>? _getWeeklyDiaryDataSync(
  String commonWidgetId,
  List<(DateTime, DiaryEntry)>? cachedEntries,
) {
  try {
    // 优先使用事件携带的缓存数据（性能优化）
    List<(DateTime, DiaryEntry)> monthlyEntries;

    if (cachedEntries != null) {
      monthlyEntries = cachedEntries;
    } else {
      // 回退：从插件同步获取（首次构建或向后兼容）
      final plugin = PluginManager.instance.getPlugin('diary') as DiaryPlugin?;
      if (plugin == null) return null;
      monthlyEntries = plugin.getMonthlyDiaryEntriesSync();
    }

    final now = DateTime.now();

    // 转换为 Map<DateTime, DiaryEntry> 格式
    final entriesMap = <DateTime, DiaryEntry>{};
    for (final entry in monthlyEntries) {
      entriesMap[entry.$1] = entry.$2;
    }

    // 获取本周日期
    final weekDays = getCurrentWeekDays(now);

    // 过滤本周的日记
    final weeklyEntries = <DateTime, DiaryEntry>{};
    for (final date in weekDays) {
      final entry = entriesMap[DateTime(date.year, date.month, date.day)];
      if (entry != null) {
        weeklyEntries[date] = entry;
      }
    }

    // 根据 commonWidgetId 返回对应的数据
    switch (commonWidgetId) {
      case 'weeklyDiaryWidget':
        return {
          'title': '本周日记',
          'showTitle': true,
          'primaryColor': Colors.indigo.value,
        };

      case 'moodChartCard':
        // 统计本周心情
        final moodStats = <String, int>{};
        for (final entry in weeklyEntries.values) {
          if (entry.mood != null && entry.mood!.isNotEmpty) {
            moodStats[entry.mood!] = (moodStats[entry.mood!] ?? 0) + 1;
          }
        }

        // 创建心情图表数据
        final moodChartData = moodStats.entries.map((e) {
          final emoji = diaryMoodSpecOf(e.key).emoji;
          final label = _getMoodLabel(emoji);
          final value = e.value;
          return {'emoji': emoji, 'label': label, 'value': value};
        }).toList();

        return {
          'title': '本周心情',
          'subtitle': '共 ${weeklyEntries.length} 篇日记',
          'moods': moodChartData,
          'displayType': 'emoji',
          'primaryColor': Colors.indigo.value,
        };

      default:
        return null;
    }
  } catch (e) {
    debugPrint('[Diary] 获取七日周报数据失败: $e');
    return null;
  }
}
