import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aboutme/core/event/event_args.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/item_event_args.dart';
import 'package:aboutme/plugins/openai/services/ai_auto_reply_service.dart';

/// AI 自动回复纯逻辑测试（不启动插件/不触发 LLM）
void main() {
  group('readConfiguredEvents', () {
    test('未配置（键不存在）回退默认事件列表', () {
      final events = AiAutoReplyService.readConfiguredEvents({});
      expect(events, AiAutoReplyService.defaultEvents);
    });

    test('配置为非 List（脏数据）回退默认事件列表', () {
      final events = AiAutoReplyService.readConfiguredEvents({
        AiAutoReplyService.kSettingEvents: 'task_completed',
      });
      expect(events, AiAutoReplyService.defaultEvents);
    });

    test('显式空列表保持为空（用户主动全不选）', () {
      final events = AiAutoReplyService.readConfiguredEvents({
        AiAutoReplyService.kSettingEvents: <dynamic>[],
      });
      expect(events, isEmpty);
    });

    test('过滤目录外虚构事件并去重', () {
      final events = AiAutoReplyService.readConfiguredEvents({
        AiAutoReplyService.kSettingEvents: [
          'task_completed',
          'habit_checked', // 虚构事件（真实事件为 habit_completion_record_saved）
          'task_completed', // 重复
          42, // 非字符串
        ],
      });
      expect(events, ['task_completed']);
    });
  });

  group('describeEvent', () {
    test('目录内事件返回中文描述', () {
      expect(
        AiAutoReplyService.describeEvent('task_completed', null),
        '完成了一个待办任务',
      );
    });

    test('目录外事件返回兜底描述', () {
      expect(
        AiAutoReplyService.describeEvent('unknown_event', null),
        contains('unknown_event'),
      );
    });

    test('ItemEventArgs 携带标题时补充条目名', () {
      final args = ItemEventArgs(
        eventName: 'task_completed',
        itemId: 't1',
        title: '写周报',
        action: 'completed',
      );
      expect(
        AiAutoReplyService.describeEvent('task_completed', args),
        '完成了一个待办任务「写周报」',
      );
    });

    test('ItemEventArgs 标题为空时不追加分隔符', () {
      final args = ItemEventArgs(
        eventName: 'task_completed',
        itemId: 't1',
        title: '  ',
        action: 'completed',
      );
      expect(
        AiAutoReplyService.describeEvent('task_completed', args),
        '完成了一个待办任务',
      );
    });
  });

  group('describeEventDataJson', () {
    test('ItemEventArgs 提取 itemId/title/action 及附加数据', () {
      final args = ItemEventArgs(
        eventName: 'task_completed',
        itemId: 't1',
        title: '写周报',
        action: 'completed',
        data: {'extra': 1},
      );
      final decoded = jsonDecode(
        AiAutoReplyService.describeEventDataJson('task_completed', args),
      ) as Map<String, dynamic>;
      expect(decoded['event'], 'task_completed');
      expect(decoded['time'], isNotNull);
      final data = decoded['data'] as Map<String, dynamic>;
      expect(data['itemId'], 't1');
      expect(data['title'], '写周报');
      expect(data['action'], 'completed');
      expect(data['extra'], 1);
    });

    test('Value<Map> 载荷递归序列化（habit_completion_record_saved 场景）', () {
      final args = Value({'habitId': 'h1', 'count': 3});
      final decoded = jsonDecode(
        AiAutoReplyService.describeEventDataJson(
          'habit_completion_record_saved',
          args,
        ),
      ) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      final value = data['value'] as Map<String, dynamic>;
      expect(value['habitId'], 'h1');
      expect(value['count'], 3);
    });

    test('空载荷事件 data 为 null（不携带垃圾信息）', () {
      final decoded = jsonDecode(
        AiAutoReplyService.describeEventDataJson(
          'agent_chat_user_message',
          EventArgs('agent_chat_user_message'),
        ),
      ) as Map<String, dynamic>;
      expect(decoded['event'], 'agent_chat_user_message');
      expect(decoded['data'], isNull);
    });
  });

  group('buildPrompt', () {
    test('旧模板未引用 {eventData} 时自动追加事件详细 JSON', () {
      final prompt = AiAutoReplyService.buildPrompt(
        '根据以下事件鼓励用户：{eventDescription}',
        'task_completed',
        ItemEventArgs(
          eventName: 'task_completed',
          itemId: 't1',
          title: '写周报',
          action: 'completed',
        ),
      );
      expect(prompt, contains('「写周报」'));
      expect(prompt, contains('事件详细数据（JSON）'));
      expect(prompt, contains('"task_completed"'));
    });

    test('模板引用 {eventData} 时原位替换且不重复追加', () {
      final prompt = AiAutoReplyService.buildPrompt(
        '事件：{eventDescription} 数据：{eventData}',
        'task_completed',
        null,
      );
      expect(prompt, startsWith('事件：完成了一个待办任务 数据：{'));
      expect(prompt, isNot(contains('事件详细数据（JSON）')));
      // 仅出现一次 JSON 块（无重复追加）
      expect(prompt.split('"event"').length - 1, 1);
    });
  });

  group('事件目录约束', () {
    test('目录内事件不包含广播事件自身（防递归）', () {
      for (final e in AiAutoReplyService.availableEvents) {
        expect(
          e.eventName,
          isNot('ai_auto_reply'),
          reason: '目录不得收录广播事件自身',
        );
      }
    });

    test('目录不含 AI 自主行为且无载荷可过滤的事件（moment_posted）', () {
      final names = AiAutoReplyService.availableEvents
          .map((e) => e.eventName)
          .toSet();
      expect(names.contains('moment_posted'), isFalse);
    });

    test('默认事件全部在目录内', () {
      final names = AiAutoReplyService.eventDescriptions.keys.toSet();
      for (final e in AiAutoReplyService.defaultEvents) {
        expect(names.contains(e), isTrue, reason: '默认事件 $e 必须在目录内');
      }
    });
  });

  test('stop 停用服务并清理全部订阅', () {
    final service = AiAutoReplyService.instance;
    service.stop();
    expect(service.isRunning, isFalse);
  });

  test('EventArgs 基类 eventName 语义（广播不回填，订阅方闭包捕获）', () {
    final args = EventArgs('probe');
    expect(args.eventName, 'probe');
  });
}
