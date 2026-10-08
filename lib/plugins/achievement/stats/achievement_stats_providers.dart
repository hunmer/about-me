import 'package:flutter/foundation.dart';

// ---- 各插件取数入口 ----
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/services/prompt_preset_service.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/diary/utils/diary_utils.dart';
import 'package:aboutme/plugins/activity/activity_plugin.dart';
import 'package:aboutme/plugins/habits/habits_plugin.dart';
import 'package:aboutme/plugins/checkin/checkin_plugin.dart';
import 'package:aboutme/plugins/todo/todo_plugin.dart';
import 'package:aboutme/plugins/notes/notes_plugin.dart';
import 'package:aboutme/plugins/nodes/nodes_plugin.dart';
import 'package:aboutme/plugins/nodes/models/node.dart';
import 'package:aboutme/plugins/day/day_plugin.dart';
import 'package:aboutme/plugins/calendar/calendar_plugin.dart';
import 'package:aboutme/plugins/calendar_album/calendar_album_plugin.dart';
import 'package:aboutme/plugins/reminder/reminder_plugin.dart';
import 'package:aboutme/plugins/bill/bill_plugin.dart';
import 'package:aboutme/plugins/goods/goods_plugin.dart';
import 'package:aboutme/plugins/goods/models/goods_item.dart';
import 'package:aboutme/plugins/store/store_plugin.dart';
import 'package:aboutme/plugins/contact/contact_plugin.dart';
import 'package:aboutme/plugins/tracker/tracker_plugin.dart';
import 'package:aboutme/plugins/database/database_plugin.dart';
import 'package:aboutme/plugins/timer/timer_plugin.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';
import 'package:aboutme/plugins/webview/webview_plugin.dart';
import 'package:aboutme/plugins/scripts_center/scripts_center_plugin.dart';

/// 成就快照统计提供器：成就编号 → (数据来源插件id, 取数函数)
///
/// 约定：
/// - 返回 null 表示数据源暂不可用（插件未就绪等），本次跳过结算；
/// - 返回值为当前存量统计，经 [AchievementController.setProgressValue] 幂等结算（只增不减）；
/// - 全部在后台低频触发（启动延迟/打开成就页/相关事件防抖），不做实时刷新。
typedef StatProvider = Future<int?> Function();

Future<int?> _guard(Future<int?> Function() fn) async {
  try {
    return await fn();
  } catch (e) {
    debugPrint('[Achievement] 快照取数失败: $e');
    return null;
  }
}

Map<String, (String, StatProvider)> buildStatProviders() {
  return {
    // ===== chat =====
    'A01': ('chat', () => _guard(() async {
          final channels = ChatPlugin.instance.dataService.channels;
          return channels.fold<int>(0, (sum, c) => sum + c.messages.length);
        })),
    'A02': ('chat', () => _guard(() async => ChatPlugin.instance.dataService.channels.length)),
    'A03': ('chat', () => _guard(() async {
          final tags = await ChatPlugin.instance.tagService.getAllTags();
          return tags.fold<int>(0, (sum, t) => sum + t.messageCount);
        })),
    'A04': ('chat', () => _guard(() async {
          final channels = ChatPlugin.instance.dataService.channels;
          return channels.fold<int>(0, (max, c) => c.messages.length > max ? c.messages.length : max);
        })),
    // A11 赛博知己【隐藏】：AI 主动消息（metadata.isProactive）
    'A11': ('chat', () => _guard(() async {
          final channels = ChatPlugin.instance.dataService.channels;
          return channels.fold<int>(
              0,
              (sum, c) =>
                  sum + c.messages.where((m) => m.metadata?['isProactive'] == true).length);
        })),

    // ===== agent_chat =====
    // A05 促膝长谈：累计 AI 对话轮数（用户消息计一轮）
    'A05': ('agent_chat', () => _guard(() async {
          final cc = AgentChatPlugin.instance.conversationController;
          if (cc == null) return null;
          var rounds = 0;
          for (final conversation in cc.conversations) {
            final messages = await cc.messageService.getMessages(conversation.id);
            rounds += messages.where((m) => m.isUser).length;
          }
          return rounds;
        })),
    // A07 工具大师：累计工具调用次数
    'A07': ('agent_chat', () => _guard(() async {
          final cc = AgentChatPlugin.instance.conversationController;
          if (cc == null) return null;
          var calls = 0;
          for (final conversation in cc.conversations) {
            final messages = await cc.messageService.getMessages(conversation.id);
            calls += messages.where((m) => m.toolCall != null).length;
          }
          return calls;
        })),

    // ===== openai =====
    'A08': ('openai', () => _guard(() async => (await AgentController().getAllAgents()).length)),
    'A09': ('openai', () => _guard(() async {
          final service = PromptPresetService();
          await service.loadPresets();
          return service.presets.length;
        })),
    'A10': ('openai', () => _guard(() async {
          final service = MomentsService.instance;
          await service.loadPosts();
          return service.posts.length;
        })),

    // ===== live2d =====
    'A12': ('live2d', () => _guard(() async => Live2DPlugin.instance.archives.length)),

    // ===== diary =====
    'A14': ('diary', () => _guard(() async => (await DiaryUtils.loadDiaryEntries()).length)),
    // A15 习惯成自然：最长连续写日记天数
    'A15': ('diary', () => _guard(() async {
          final entries = await DiaryUtils.loadDiaryEntries();
          return longestStreak(entries.keys.map(_dateOnly).toSet());
        })),
    // A16 长篇大论：单篇日记最长字数
    'A16': ('diary', () => _guard(() async {
          final entries = await DiaryUtils.loadDiaryEntries();
          return entries.values.fold<int>(0, (max, e) => e.content.length > max ? e.content.length : max);
        })),

    // ===== activity =====
    // A18 千时如梭：累计活动时长（小时）。全量扫描较重，仅全局结算触发。
    'A18': ('activity', () => _guard(() async {
          final service = ActivityPlugin.instance.activityService;
          final records = await service.getActivitiesForRange(DateTime(2000), DateTime.now());
          final minutes = records.fold<int>(0, (sum, r) => sum + r.durationInMinutes);
          return minutes ~/ 60;
        })),
    // A19 标签收藏家：活动标签库标签总数
    'A19': ('activity', () => _guard(() async {
          final groups = await ActivityPlugin.instance.activityService.getTagGroups();
          return groups.fold<int>(0, (sum, g) => sum + g.tags.length);
        })),

    // ===== habits =====
    // A20 习惯成瘾：单个习惯最长连续打卡天数
    'A20': ('habits', () => _guard(() async {
          final plugin = HabitsPlugin.instance;
          final recordController = plugin.getRecordController();
          var maxStreak = 0;
          for (final habit in plugin.getHabitController().getHabits()) {
            final records = await recordController.getHabitCompletionRecords(habit.id);
            final streak = longestStreak(records.map((r) => _dateOnly(r.date)).toSet());
            if (streak > maxStreak) maxStreak = streak;
          }
          return maxStreak;
        })),
    // A21 技能点满：累计技能练习记录次数（插件无"技能点"概念，以技能打卡记录计数）
    'A21': ('habits', () => _guard(() async {
          final plugin = HabitsPlugin.instance;
          final skillController = plugin.getSkillController();
          await skillController.loadSkills();
          var total = 0;
          for (final skill in skillController.getSkills()) {
            final records = await skillController.getSkillCompletionRecords(skill.id);
            total += records.length as int;
          }
          return total;
        })),
    // A22 多线操作：近 7 天有打卡记录的习惯数（快照只增不减，天然形成峰值口径）
    'A22': ('habits', () => _guard(() async {
          final plugin = HabitsPlugin.instance;
          final recordController = plugin.getRecordController();
          final weekAgo = DateTime.now().subtract(const Duration(days: 7));
          var active = 0;
          for (final habit in plugin.getHabitController().getHabits()) {
            final records = await recordController.getHabitCompletionRecords(habit.id);
            if (records.any((r) => r.date.isAfter(weekAgo))) active++;
          }
          return active;
        })),

    // ===== checkin =====
    'A25': ('checkin', () => _guard(() async => CheckinPlugin.instance.checkinItems.length)),
    // A24 全勤奖：所有打卡项都有记录的天数
    'A24': ('checkin', () => _guard(() async {
          final items = CheckinPlugin.instance.checkinItems;
          if (items.isEmpty) return 0;
          final days = items.expand((item) => item.checkInRecords.keys).toSet();
          return days.where((day) => items.every((item) => item.checkInRecords.containsKey(day))).length;
        })),

    // ===== todo =====
    // A26 效率专家：累计完成任务数（已完成列表快照）
    'A26': ('todo', () => _guard(() async => TodoPlugin.instance.taskController.completedTasks.length)),
    // A27 今日事今日毕：单日完成任务数峰值
    'A27': ('todo', () => _guard(() async {
          final completed = TodoPlugin.instance.taskController.completedTasks;
          final byDay = <DateTime, int>{};
          for (final task in completed) {
            final day = task.completedDate == null ? null : _dateOnly(task.completedDate!);
            if (day != null) byDay[day] = (byDay[day] ?? 0) + 1;
          }
          return byDay.values.fold<int>(0, (max, c) => c > max ? c : max);
        })),
    // A28 立志者：累计创建任务数（活跃 + 已完成）
    'A28': ('todo', () => _guard(() async {
          final controller = TodoPlugin.instance.taskController;
          return controller.tasks.length + controller.completedTasks.length;
        })),

    // ===== notes =====
    // A30 分门别类：笔记文件夹个数（排除内置 root）
    'A30': ('notes', () => _guard(() async {
          final folders = NotesPlugin.instance.controller.getAllFolders();
          return folders.where((f) => f.id != 'root').length;
        })),

    // ===== nodes =====
    'A31': ('nodes', () => _guard(() async => NodesPlugin.instance.getTotalNodeCount())),
    // A32 闭环完成：累计置为 done 的节点数
    'A32': ('nodes', () => _guard(() async {
          var done = 0;
          void countNodes(List<dynamic> nodes) {
            for (final node in nodes) {
              if (node.status == NodeStatus.done) done++;
              countNodes(node.children);
            }
          }
          final notebooks = NodesPlugin.instance.controller.notebooks;
          for (final notebook in notebooks) {
            countNodes(notebook.nodes);
          }
          return done;
        })),

    // ===== day =====
    'A34': ('day', () => _guard(() async => DayPlugin.instance.getMemorialDayCount())),

    // ===== calendar =====
    // A36 行程满档：累计创建日程事件数（本地未完成 + 已完成，不含系统日历）
    'A36': ('calendar', () => _guard(() async {
          final controller = CalendarPlugin.instance.controller;
          return controller.events.length + controller.completedEvents.length;
        })),
    // A37 忙碌一周：单周日程事件数峰值（周一为一周开始）
    'A37': ('calendar', () => _guard(() async {
          final controller = CalendarPlugin.instance.controller;
          final all = [...controller.events, ...controller.completedEvents];
          final byWeek = <DateTime, int>{};
          for (final event in all) {
            final week = _weekKey(event.startTime);
            byWeek[week] = (byWeek[week] ?? 0) + 1;
          }
          return byWeek.values.fold<int>(0, (max, c) => c > max ? c : max);
        })),

    // ===== calendar_album =====
    'A38': ('calendar_album', () => _guard(() async => CalendarAlbumPlugin.instance.getTotalPhotosCount())),
    // A39 标签相册：条目上实际使用过的照片标签种数
    'A39': ('calendar_album', () => _guard(() async {
          final controller = CalendarAlbumPlugin.instance.calendarController;
          if (controller == null) return null;
          return controller.getAllTags().length;
        })),

    // ===== reminder =====
    'A40': ('reminder', () => _guard(() async => ReminderPlugin.instance.service.reminders.length)),

    // ===== bill =====
    'A42': ('bill', () => _guard(() async => (await BillPlugin.instance.controller.getBills()).length)),
    // A43 连续记账：最长连续记账天数
    'A43': ('bill', () => _guard(() async {
          final bills = await BillPlugin.instance.controller.getBills();
          return longestStreak(bills.map((b) => _dateOnly(b.date)).toSet());
        })),
    'A44': ('bill', () => _guard(() async => BillPlugin.instance.controller.accounts.length)),

    // ===== goods =====
    'A45': ('goods', () => _guard(() async => GoodsPlugin.instance.getTotalItemsCount())),
    'A46': ('goods', () => _guard(() async => GoodsPlugin.instance.warehouses.length)),
    // A47 物尽其用：累计物品使用/领用次数
    'A47': ('goods', () => _guard(() async {
          int countUsages(List<GoodsItem> items) => items.fold<int>(
              0,
              (sum, item) =>
                  sum + item.usageRecords.length + countUsages(item.subItems));
          final plugin = GoodsPlugin.instance;
          return plugin.warehouses.fold<int>(
              0, (sum, w) => sum + countUsages(w.items));
        })),

    // ===== store =====
    // A49 血拼达人：累计兑换商品次数（按积分流水"消耗"记录计数，避免 userItems 用完即删失真）
    'A49': ('store', () => _guard(() async {
          final logs = StorePlugin.instance.controller.pointsLogs;
          return logs.where((l) => l.type == '消耗').length;
        })),
    // A50 兑换图鉴：兑换过的不同商品种数（当前持有 + 已使用完）
    'A50': ('store', () => _guard(() async {
          final controller = StorePlugin.instance.controller;
          final ids = <String>{
            ...controller.userItems.map((i) => i.productId),
            ...controller.usedItems.map((i) => i.productId),
          };
          return ids.length;
        })),

    // ===== contact =====
    'A51': ('contact', () => _guard(() async => (await ContactPlugin.instance.controller.getAllContacts()).length)),
    'A52': ('contact', () => _guard(() async => (await ContactPlugin.instance.controller.getAllInteractions()).length)),
    // A53 社交蝴蝶【隐藏】：单个联系人累计互动次数峰值
    'A53': ('contact', () => _guard(() async {
          final interactions =
              await ContactPlugin.instance.controller.getAllInteractions();
          final byContact = <String, int>{};
          for (final record in interactions) {
            byContact[record.contactId] = (byContact[record.contactId] ?? 0) + 1;
          }
          return byContact.values.fold<int>(0, (max, c) => c > max ? c : max);
        })),

    // ===== tracker =====
    // A54 旗开得胜：完成（进度100%）的 Goal 个数
    'A54': ('tracker', () => _guard(() async =>
        TrackerPlugin.instance.controller.goals.where((g) => g.isCompleted).length)),
    'A55': ('tracker', () => _guard(() async => TrackerPlugin.instance.controller.records.length)),

    // ===== database =====
    'A56': ('database', () => _guard(() async {
          final plugin = DatabasePlugin.instance;
          return await plugin.service.getDatabaseCount();
        })),
    'A57': ('database', () => _guard(() async {
          final plugin = DatabasePlugin.instance;
          return await plugin.service.getTotalRecordCount(plugin.controller);
        })),
    // A58 全字段控：单库使用的字段类型种数峰值
    'A58': ('database', () => _guard(() async {
          final databases = await DatabasePlugin.instance.service.getAllDatabases();
          return databases.fold<int>(
              0,
              (max, db) {
                final types = db.fields.map((f) => f.type).toSet().length;
                return types > max ? types : max;
              });
        })),

    // ===== timer =====
    // A60 万分钟专注：累计计时时长（分钟，按已完成计时项的 completedDuration 求和）
    'A60': ('timer', () => _guard(() async {
          final tasks = TimerPlugin.instance.getTasks();
          return tasks.fold<int>(
              0,
              (sum, task) => sum + task.timerItems.fold<int>(0, (s, item) => s + item.completedDuration.inMinutes));
        })),

    // ===== tts =====
    // A62 三通道玩家：已配置的 TTS 通道种数（插件无使用记录，以配置口径近似）
    'A62': ('tts', () => _guard(() async {
          final services = await TTSPlugin.instance.managerService.getAllServices();
          return services.map((s) => s.type).toSet().length;
        })),

    // ===== webview =====
    // A65 冲浪起点：累计打开网页次数（按卡片打开计数求和；浏览器内新开页不计）
    'A65': ('webview', () => _guard(() async {
          final cards = WebViewPlugin.instance.cardManager.cards;
          return cards.fold<int>(0, (sum, c) => sum + c.openCount);
        })),
    'A66': ('webview', () => _guard(() async => WebViewPlugin.instance.getUrlCardsCount())),
    // A67 多线程浏览：同时打开标签页数峰值（当前值经只增不减结算形成峰值）
    'A67': ('webview', () => _guard(() async => WebViewPlugin.instance.getActiveTabsCount())),

    // ===== scripts_center =====
    // A68 Hello World：累计运行脚本次数（执行日志有 200 条上限，超出部分按上限近似）
    'A68': ('scripts_center', () => _guard(() async =>
        ScriptsCenterPlugin.instance.scriptExecutor.executionLogger.entries.length)),
    // A69 脚本作者：保存的自制脚本个数
    'A69': ('scripts_center', () => _guard(() async {
          final scripts = await ScriptsCenterPlugin.instance.scriptManager.loadAllScripts();
          return scripts.where((s) => !s.isBuiltIn).length;
        })),
    // A70 效率革命：单个脚本累计运行次数（受日志 200 条上限约束）
    'A70': ('scripts_center', () => _guard(() async {
          final entries = ScriptsCenterPlugin.instance.scriptExecutor.executionLogger.entries;
          final byScript = <String, int>{};
          for (final entry in entries) {
            byScript[entry.scriptId] = (byScript[entry.scriptId] ?? 0) + 1;
          }
          return byScript.values.fold<int>(0, (max, c) => c > max ? c : max);
        })),
  };
}

// ============ 公共计算辅助 ============

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 周标识（周一为一周开始）
DateTime _weekKey(DateTime d) {
  final date = _dateOnly(d);
  return date.subtract(Duration(days: date.weekday - 1));
}

/// 日期集合的最长连续天数
int longestStreak(Set<DateTime> days) {
  if (days.isEmpty) return 0;
  final sorted = days.toList()..sort();
  var longest = 1;
  var current = 1;
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
      current++;
      if (current > longest) longest = current;
    } else {
      current = 1;
    }
  }
  return longest;
}

/// 跨插件日期聚合：A72 全方位记录 / A73 百日筑基
class RecordDayStats {
  /// 同一天产生 diary+bill+todo+打卡 四类记录的天数
  final int allFourDays;

  /// 连续产生任一记录的最长天数
  final int anyRecordStreak;

  RecordDayStats(this.allFourDays, this.anyRecordStreak);
}

Future<RecordDayStats?> collectRecordDayStats() async {
  try {
    // 日记日期
    final diaryDays = (await DiaryUtils.loadDiaryEntries())
        .keys
        .map(_dateOnly)
        .toSet();

    // 账单日期
    final bills = await BillPlugin.instance.controller.getBills();
    final billDays = bills.map((b) => _dateOnly(b.date)).toSet();

    // 任务完成日期
    final completed = TodoPlugin.instance.taskController.completedTasks;
    final todoDays = completed
        .map((t) => t.completedDate)
        .whereType<DateTime>()
        .map(_dateOnly)
        .toSet();

    // 打卡日期
    final checkinDays = CheckinPlugin.instance.checkinItems
        .expand((item) => item.checkInRecords.keys)
        .map((day) => DateTime.parse(day))
        .map(_dateOnly)
        .toSet();

    final allFour =
        diaryDays.toSet().intersection(billDays).intersection(todoDays).intersection(checkinDays);
    final anyRecord = {...diaryDays, ...billDays, ...todoDays, ...checkinDays};

    return RecordDayStats(allFour.length, longestStreak(anyRecord));
  } catch (e) {
    debugPrint('[Achievement] 跨插件记录统计失败: $e');
    return null;
  }
}
