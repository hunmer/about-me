import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/event/ai_auto_reply_event_args.dart';
import 'package:aboutme/core/event/event_args.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/item_event_args.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/chat/models/message.dart';

import '../openai_plugin.dart';
import 'request_service.dart';

/// AI 自动回复支持的业务事件信息（事件名 / 分类 / 展示描述）
///
/// 事件名均为事件总线上真实广播的业务事件（与成就系统
/// achievement_controller.dart 的信号清单同源核实），不存在虚构事件；
/// moment_posted 等由 AI 自主行为触发且无载荷可过滤的事件不收录。
class AiAutoReplyEventInfo {
  final String eventName;
  final String category;
  final String description;

  const AiAutoReplyEventInfo(this.eventName, this.category, this.description);
}

/// AI 自动回复服务（迁自 online/scripts/ai_encouragement_bot，2026-11 原生化）
///
/// 行为：订阅用户选定的业务事件 → 用事件描述填充提示模板 →
/// 经 RequestService 调用指定 Agent 生成一句话回复 → 广播
/// [AiAutoReplyEventArgs]（宠物等展示方可同步置 handled=true 拦截）→
/// 未被拦截时默认 Toast 展示。
///
/// 防递归：永不订阅 [AiAutoReplyEventArgs.event] 自身；LLM 调用期间
/// （_processing）到达的新事件直接丢弃；AI 自身产生的聊天消息
/// （metadata.isAI=true）不触发回复。
/// 限流：两次回复之间强制最小间隔（默认 60s，可配置）。
class AiAutoReplyService {
  AiAutoReplyService._();
  static final AiAutoReplyService instance = AiAutoReplyService._();

  // ==== 配置键（持久化于 configs/openai/settings.json）====
  static const String kSettingEnabled = 'aiAutoReplyEnabled';
  static const String kSettingAgentId = 'aiAutoReplyAgentId';
  static const String kSettingTemplate = 'aiAutoReplyPromptTemplate';
  static const String kSettingEvents = 'aiAutoReplyEvents';
  static const String kSettingMinIntervalSec = 'aiAutoReplyMinIntervalSec';

  /// 默认提示模板（与原在线脚本一致）
  static const String defaultPromptTemplate =
      '根据以下事件，用一句话鼓励用户：{eventDescription}';

  /// 两次自动回复之间的默认最小间隔（秒）
  static const int defaultMinIntervalSec = 60;

  /// 单次 LLM 调用超时
  static const Duration _aiCallTimeout = Duration(seconds: 60);

  /// 旧在线脚本 id（scripts_center 分区存储其配置）
  static const String _legacyScriptId = 'ai_encouragement_bot';

  /// 可选业务事件目录
  static const List<AiAutoReplyEventInfo> availableEvents = [
    // 任务与打卡
    AiAutoReplyEventInfo('task_added', '任务', '新建了一个待办任务'),
    AiAutoReplyEventInfo('task_completed', '任务', '完成了一个待办任务'),
    AiAutoReplyEventInfo('checkin_completed', '打卡', '完成了一次打卡'),
    AiAutoReplyEventInfo('checkin_item_added', '打卡', '新建了一个打卡项'),
    AiAutoReplyEventInfo('habit_completion_record_saved', '打卡', '完成了一次习惯记录'),
    // 笔记与日记
    AiAutoReplyEventInfo('note_added', '笔记', '新建了一篇笔记'),
    AiAutoReplyEventInfo('note_folder_added', '笔记', '新建了一个笔记文件夹'),
    AiAutoReplyEventInfo('diary_entry_updated', '日记', '保存了一篇日记'),
    AiAutoReplyEventInfo('calendar_event_added', '日程', '新建了一个日程'),
    AiAutoReplyEventInfo('calendar_event_completed', '日程', '完成了一个日程'),
    AiAutoReplyEventInfo('memorial_day_added', '日程', '添加了一个纪念日'),
    // 记录类
    AiAutoReplyEventInfo('activity_added', '记录', '记录了一次活动'),
    AiAutoReplyEventInfo('activity_duration_added', '记录', '积累了活动时长'),
    AiAutoReplyEventInfo('bill_added', '记录', '记录了一笔账单'),
    AiAutoReplyEventInfo('account_added', '记录', '添加了一个账户'),
    AiAutoReplyEventInfo('onRecordAdded', '记录', '添加了一条追踪记录'),
    AiAutoReplyEventInfo('database_added', '记录', '新建了一个数据集'),
    AiAutoReplyEventInfo('database_record_added', '记录', '添加了一条数据记录'),
    AiAutoReplyEventInfo('goods_item_added', '记录', '添加了一件物品'),
    AiAutoReplyEventInfo('reminder_added', '记录', '新建了一个提醒'),
    // 聊天（AI 自身消息已在 _onEvent 中过滤）
    AiAutoReplyEventInfo('chat_message_sent', '聊天', '发送了一条频道消息'),
    AiAutoReplyEventInfo('chat_channel_added', '聊天', '新建了一个聊天频道'),
    AiAutoReplyEventInfo('agent_chat_user_message', '聊天', '在 AI 对话中发送了消息'),
    // 社交
    AiAutoReplyEventInfo('openai_agent_added', '社交', '新建了一个 AI 助手'),
    AiAutoReplyEventInfo('contact_created', '社交', '新建了一个联系人'),
    AiAutoReplyEventInfo('nodes_node_added', '社交', '新建了一个节点'),
  ];

  /// 事件名 → 描述（供 describeEvent 查询）
  static final Map<String, String> eventDescriptions = {
    for (final e in availableEvents) e.eventName: e.description,
  };

  /// 默认监听事件（鼓励向：完成/记录类行为）
  static const List<String> defaultEvents = [
    'task_completed',
    'checkin_completed',
    'habit_completion_record_saved',
    'diary_entry_updated',
    'activity_added',
    'note_added',
    'bill_added',
  ];

  /// 已注册的事件处理器（事件名 → 处理函数，闭包捕获事件名）
  final Map<String, Function(EventArgs)> _handlers = {};

  /// LLM 调用进行中标记（防重入/递归）
  bool _processing = false;

  /// 上次回复时间（限流）
  DateTime? _lastReplyAt;

  /// 订阅代际：stop/reload 时递增，使仍在途的旧 LLM 请求作废
  int _generation = 0;

  bool get isRunning => _handlers.isNotEmpty;

  /// 插件 initialize() 调用；先做旧配置迁移，再按当前配置决定是否订阅
  Future<void> start() async {
    await migrateLegacyConfig();
    reload();
  }

  /// 按最新配置重建订阅（设置变更后调用）
  void reload() {
    stop(); // 内部递增 generation，作废在途请求
    final settings = OpenAIPlugin.instance.settings;
    if (settings[kSettingEnabled] != true) {
      debugPrint('[AiAutoReply] 未启用，跳过订阅');
      return;
    }
    final agentId = settings[kSettingAgentId] as String?;
    if (agentId == null || agentId.isEmpty) {
      debugPrint('[AiAutoReply] 未配置回复 Agent，跳过订阅');
      return;
    }
    final events = readConfiguredEvents(settings);
    if (events.isEmpty) {
      debugPrint('[AiAutoReply] 监听事件为空（用户显式全不选），跳过订阅');
      return;
    }
    final eventManager = EventManager.instance;
    for (final eventName in events) {
      // 防递归：广播事件自身不可订阅
      if (eventName == AiAutoReplyEventArgs.event) continue;
      void handler(EventArgs args) => _onEvent(eventName, args);
      _handlers[eventName] = handler;
      eventManager.subscribe(eventName, handler);
    }
    debugPrint('[AiAutoReply] 已启动，监听 ${_handlers.length} 个事件');
  }

  void stop() {
    if (_handlers.isNotEmpty) {
      final eventManager = EventManager.instance;
      _handlers.forEach(eventManager.unsubscribe);
      _handlers.clear();
    }
    _generation++; // 作废在途请求
  }

  /// 读取配置的监听事件
  ///
  /// 未配置（非 List）→ 回退默认列表；显式配置（含空列表）→
  /// 过滤出目录内真实事件后原样返回，空即空（用户主动全不选）。
  static List<String> readConfiguredEvents(Map<String, dynamic> settings) {
    final raw = settings[kSettingEvents];
    if (raw is! List) return defaultEvents;
    return raw
        .whereType<String>()
        .where(eventDescriptions.containsKey)
        .toSet()
        .toList();
  }

  /// 旧在线脚本配置迁移：新配置从未设置过（不含启用键）且旧脚本
  /// （scripts_center 分区 configs/ai_encouragement_bot_config.json）
  /// 存在有效 agentId 时，迁入 agentId / promptTemplate 并默认启用，
  /// 避免老用户功能无声丢失。旧 agentId 兼容 string 与 {id: ...} 两种形态。
  Future<void> migrateLegacyConfig() async {
    final settings = OpenAIPlugin.instance.settings;
    if (settings.containsKey(kSettingEnabled)) return;
    try {
      final result = await AboutmeDataService.instance.call(
        'scripts_center',
        'getConfig',
        {'scriptId': _legacyScriptId},
      );
      if (result['success'] != true) return;
      final data = result['data'];
      if (data is! Map || data.isEmpty) return;
      var values = data.map((k, v) => MapEntry(k.toString(), v));
      // 兼容新 profiles 格式（取 default profile 的 values）
      final profiles = values['profiles'];
      if (profiles is List && profiles.isNotEmpty) {
        final defaultId = values['defaultProfileId'] as String?;
        Map? chosen;
        for (final p in profiles.whereType<Map>()) {
          if (p['id'] == defaultId) {
            chosen = p;
            break;
          }
        }
        chosen ??= profiles.first as Map;
        final v = chosen['values'];
        if (v is Map) values = v.map((k, v) => MapEntry(k.toString(), v));
      }
      // agentId 兼容 string / {id}
      final rawAgent = values['agentId'];
      String? agentId;
      if (rawAgent is String && rawAgent.trim().isNotEmpty) {
        agentId = rawAgent.trim();
      } else if (rawAgent is Map &&
          rawAgent['id'] is String &&
          (rawAgent['id'] as String).trim().isNotEmpty) {
        agentId = (rawAgent['id'] as String).trim();
      }
      if (agentId == null) return;
      final template = values['promptTemplate'];
      await OpenAIPlugin.instance.updateSettings({
        kSettingEnabled: true,
        kSettingAgentId: agentId,
        if (template is String && template.trim().isNotEmpty)
          kSettingTemplate: template.trim(),
      });
      debugPrint('[AiAutoReply] 已迁移旧脚本配置（agent=$agentId）');
    } catch (e) {
      debugPrint('[AiAutoReply] 旧配置迁移失败（忽略）: $e');
    }
  }

  void _onEvent(String eventName, EventArgs args) {
    // 防 AI 自身消息：chat_message_sent 载荷为 Value<Message>，
    // AI 回复消息 metadata 带 isAI=true，不触发自动回复
    if (args is Value && args.value is Message) {
      final message = args.value as Message;
      if (message.metadata?['isAI'] == true) return;
    }
    // 防重入：上一次调用未完成时丢弃
    if (_processing) return;

    final settings = OpenAIPlugin.instance.settings;
    final minIntervalSec =
        (settings[kSettingMinIntervalSec] as num?)?.toInt() ??
        defaultMinIntervalSec;
    final now = DateTime.now();
    // 限流：冷却期内忽略
    if (_lastReplyAt != null &&
        now.difference(_lastReplyAt!) < Duration(seconds: minIntervalSec)) {
      return;
    }

    final agentId = settings[kSettingAgentId] as String? ?? '';
    if (agentId.isEmpty) {
      debugPrint('[AiAutoReply] 未配置回复 Agent，忽略事件 $eventName');
      return;
    }

    final template =
        (settings[kSettingTemplate] as String?)?.trim().isNotEmpty == true
        ? settings[kSettingTemplate]! as String
        : defaultPromptTemplate;
    final prompt = template.replaceAll(
      '{eventDescription}',
      describeEvent(eventName, args),
    );

    _lastReplyAt = now;
    unawaited(_generateReply(agentId, prompt, eventName, _generation));
  }

  Future<void> _generateReply(
    String agentId,
    String prompt,
    String sourceEvent,
    int generation,
  ) async {
    _processing = true;
    try {
      final agent = await OpenAIPlugin.instance.controller.getAgent(agentId);
      if (agent == null) {
        debugPrint('[AiAutoReply] Agent 不存在: $agentId');
        return;
      }
      final reply = await RequestService.chat(
        prompt,
        agent,
      ).timeout(_aiCallTimeout);
      // 请求期间 stop/reload 已变更配置：旧回复作废，不再广播/展示
      if (generation != _generation) {
        debugPrint('[AiAutoReply] 配置已变更，丢弃过期回复');
        return;
      }
      final text = reply.trim();
      if (text.isEmpty || text.startsWith('Error:')) {
        debugPrint('[AiAutoReply] 生成失败: ${text.isEmpty ? '(空响应)' : text}');
        return;
      }
      // 广播给宠物等展示方；同步返回后未被拦截则默认 Toast 展示
      final args = AiAutoReplyEventArgs(
        text: text,
        agentId: agentId,
        sourceEvent: sourceEvent,
      );
      EventManager.instance.broadcast(AiAutoReplyEventArgs.event, args);
      if (!args.handled) {
        toastService.showToast(text, duration: const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('[AiAutoReply] 自动回复失败: $e');
    } finally {
      _processing = false;
    }
  }

  /// 事件 → 中文描述；ItemEventArgs 携带标题时补充具体条目名
  static String describeEvent(String eventName, EventArgs? args) {
    final base = eventDescriptions[eventName] ?? '触发了事件「$eventName」';
    if (args is ItemEventArgs && args.title.trim().isNotEmpty) {
      return '$base「${args.title.trim()}」';
    }
    return base;
  }
}
