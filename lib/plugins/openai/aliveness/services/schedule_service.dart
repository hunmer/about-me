import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:aboutme/plugins/activity/models/activity_record.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';

/// 一条日程：今日具体时间段的活动
class ScheduleEntry {
  final DateTime start;
  final DateTime end;
  final String title;
  final String? description;

  const ScheduleEntry({
    required this.start,
    required this.end,
    required this.title,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'title': title,
    if (description != null && description!.isNotEmpty)
      'description': description,
  };

  static ScheduleEntry fromJson(Map<String, dynamic> json) => ScheduleEntry(
    start: DateTime.parse(json['start'] as String),
    end: DateTime.parse(json['end'] as String),
    title: json['title'] as String,
    description: json['description'] as String?,
  );
}

/// 某一天的完整日程（按 start 升序）
class AgentSchedule {
  final DateTime date;
  final List<ScheduleEntry> entries;
  const AgentSchedule({required this.date, required this.entries});

  Map<String, dynamic> toJson() => {
    'dateKey': dateKey(date),
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static AgentSchedule fromJson(Map<String, dynamic> json) => AgentSchedule(
    date: DateTime.parse(json['dateKey'] as String),
    entries: (json['entries'] as List<dynamic>? ?? [])
        .map((e) => ScheduleEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

/// AI 日程表（活人感·真实生活）：
/// - 今日首次互动时按人物设定用 LLM 生成一份 24 小时日常安排，按天失效重生成
/// - 聊天时把"现在正在做什么/接下来做什么"注入提示词，
///   让 AI 回答自己近况时引用真实安排而不是编造
/// - 展示复用 activity 插件的 ActivityTimeline（转为 ActivityRecord）
class ScheduleService {
  ScheduleService._();
  static final ScheduleService instance = ScheduleService._();

  final _store = AlivenessStore.instance;
  final _generating = <String>{};

  /// 读取今日日程；非今日（或不存在）返回 null
  Future<AgentSchedule?> loadToday(String agentId) async {
    try {
      final data = await _store.loadSchedule(agentId);
      if (data == null) return null;
      final schedule = AgentSchedule.fromJson(data);
      if (AgentSchedule.dateKey(schedule.date) !=
          AgentSchedule.dateKey(DateTime.now())) {
        return null;
      }
      return schedule;
    } catch (_) {
      return null;
    }
  }

  /// 确保今日日程存在：没有则按人物设定生成（生成中防重入）。
  /// [force] = true 时丢弃现有日程重新生成（管理页"重新生成"）。
  /// 返回 null 表示生成失败（保留旧日程时返回旧日程）。
  Future<AgentSchedule?> ensureTodaySchedule(
    AIAgent agent, {
    bool force = false,
  }) async {
    if (!force) {
      final existing = await loadToday(agent.id);
      if (existing != null) return existing;
    }
    if (_generating.contains(agent.id)) return null;
    _generating.add(agent.id);
    try {
      final schedule = await _generate(agent);
      if (schedule != null) {
        await _store.saveSchedule(agent.id, schedule.toJson());
        debugPrint('[Aliveness][日程] 已生成 ${agent.name} 今日日程 | '
            '${schedule.entries.length} 项安排');
        return schedule;
      }
      return null;
    } catch (e) {
      debugPrint('[Aliveness][日程] 生成失败（已忽略）: $e');
      return null;
    } finally {
      _generating.remove(agent.id);
    }
  }

  /// 用 agent 自己的 LLM 按人物设定生成 24 小时安排
  Future<AgentSchedule?> _generate(AIAgent agent) async {
    final now = DateTime.now();
    final weekday = ['一', '二', '三', '四', '五', '六', '日'][now.weekday - 1];
    final isWeekend = now.weekday >= 6;
    final persona = agent.effectiveSystemPrompt.trim();
    final prompt = '${persona.isEmpty ? "你是「${agent.name}」" : persona}\n\n'
        '今天是 ${now.year}年${now.month}月${now.day}日（星期$weekday，'
        '${isWeekend ? "周末" : "工作日"}）。请根据你的人设，规划你今天从起床到睡觉的日常安排。\n'
        '只输出 JSON 数组，不要输出其他内容，格式：\n'
        '[{"start":"07:30","end":"08:10","title":"起床洗漱","desc":"一句补充"}]\n'
        '规则：\n'
        '- 8~14 条，时间从早晨到夜里（如 07:00 ~ 24:00），按 start 升序\n'
        '- 相邻条目时间衔接，可以有小段空档（自由时间）\n'
        '- title 10 字内，贴合你的职业/爱好/生活习惯，工作日与周末安排要合理\n'
        '- desc 可省略；不要出现与用户相关的安排（这是你自己的生活）';

    final result = await RequestService.chat(
      prompt,
      agent,
      // 推理模型 reasoning 吃 token，小上限会导致输出为空
      maxTokens: 8000,
    );
    final entries = parseSchedule(result, now);
    if (entries.length < 4) return null;
    return AgentSchedule(date: now, entries: entries);
  }

  /// 解析 LLM 输出为日程条目（纯逻辑，可单测）：
  /// 截取首个 JSON 数组段，容忍 markdown 包裹与前置思考文本；
  /// end<=start 或跨天的条目做防御性修正；按 start 排序。
  static List<ScheduleEntry> parseSchedule(String text, DateTime day) {
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start < 0 || end <= start) return const [];
    try {
      final list = json.decode(text.substring(start, end + 1)) as List<dynamic>;
      final entries = <ScheduleEntry>[];
      for (final item in list) {
        if (item is! Map) continue;
        final startAt = _parseHM(item['start'] as String?, day);
        var endAt = _parseHM(item['end'] as String?, day);
        final title = (item['title'] as String?)?.trim();
        if (startAt == null || endAt == null || title == null || title.isEmpty) {
          continue;
        }
        if (!endAt.isAfter(startAt)) {
          endAt = startAt.add(const Duration(minutes: 30));
        }
        entries.add(
          ScheduleEntry(
            start: startAt,
            end: endAt,
            title: title,
            description: (item['desc'] as String?)?.trim(),
          ),
        );
      }
      entries.sort((a, b) => a.start.compareTo(b.start));
      return entries;
    } catch (_) {
      return const [];
    }
  }

  static DateTime? _parseHM(String? hm, DateTime day) {
    if (hm == null) return null;
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(hm.trim());
    if (match == null) return null;
    final h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    if (h > 24 || m > 59) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  /// 注入段：现在正在做什么 + 前后安排 + 全天概览（真实信息，防编造）
  String buildScheduleContext(AgentSchedule schedule, {DateTime? now}) {
    now ??= DateTime.now();
    final entries = schedule.entries;
    final hhmm =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    ScheduleEntry? current;
    ScheduleEntry? prev;
    ScheduleEntry? next;
    for (final e in entries) {
      if (!now.isBefore(e.end)) {
        prev = e; // 已结束：最近做完的一件事
      } else if (now.isBefore(e.start)) {
        next = e; // 尚未开始
        break;
      } else {
        current = e; // start <= now < end：正在做
      }
    }

    final buffer = StringBuffer('现在是今天 $hhmm。');
    if (current != null) {
      buffer.write('你正在${current.title}'
          '（${_hm(current.start)}-${_hm(current.end)}）。');
    } else {
      buffer.write('你正处于两件事之间的空档时间。');
    }
    if (prev != null) {
      buffer.write('之前你刚${prev.title}完毕。');
    }
    if (next != null) {
      buffer.write('${_hm(next.start)} 你要做的是：${next.title}。');
    }
    buffer.write('\n你今天的完整安排：');
    buffer.writeAll(
      entries.map((e) => '${_hm(e.start)} ${e.title}'),
      ' → ',
    );
    return buffer.toString();
  }

  String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// 转为 activity 插件的时间线数据（UI 复用）
  List<ActivityRecord> toActivityRecords(AgentSchedule schedule) => schedule
      .entries
      .map(
        (e) => ActivityRecord(
          startTime: e.start,
          endTime: e.end,
          title: e.title,
          description: e.description,
          tags: const ['AI日程'],
        ),
      )
      .toList();
}
