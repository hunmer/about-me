import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:agentlib/openai_compat.dart';
import 'package:aboutme_notifications/aboutme_notifications.dart';

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/plugins/openai/aliveness/models/agent_state.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
import 'package:aboutme/plugins/openai/aliveness/services/behavior_executor.dart';
import 'package:aboutme/plugins/openai/aliveness/services/keepalive_service.dart';
import 'package:aboutme/plugins/openai/aliveness/services/memory_service.dart';
import 'package:aboutme/plugins/openai/aliveness/services/state_service.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/moments/models/moment_post.dart';
import 'package:aboutme/plugins/openai/moments/services/agent_assets_service.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';
import 'package:aboutme/utils/image_utils.dart';

/// 主动消息服务（PRD 5.1.2 / Phase 3）：
/// 周期检查所有开启活人感的 agent，满足条件时主动发消息到上次互动频道。
/// 三重硬限制：免打扰时段 + 每日上限 + 冷却时间（代码强制，防骚扰）。
class ProactiveService {
  ProactiveService._();
  static final ProactiveService instance = ProactiveService._();

  static const _tickInterval = Duration(minutes: 1);
  /// 闲置思念的触发门槛：距上次互动超过该时长才可能主动
  static const _idleThreshold = Duration(hours: 4);
  /// 每次 tick 的闲置触发概率（期望约 20 分钟内命中一次）
  static const _idleChance = 0.05;
  /// 闲置思念命中后改发朋友圈（而非聊天消息）的概率：
  /// 发动态不打扰用户、不依赖上次互动频道，可适度更活跃
  static const _momentChance = 0.3;

  Timer? _timer;
  final _rng = Random();
  final _store = AlivenessStore.instance;
  final _states = StateService.instance;
  final _memory = MemoryService.instance;
  final _executor = BehaviorExecutor.instance;

  bool get isRunning => _timer?.isActive ?? false;

  void start() {
    if (isRunning) return;
    _timer = Timer.periodic(_tickInterval, (_) => _tick());
    // 按全局配置启动前台保活（Android：离开 app 后调度器仍可运行）
    unawaited(_syncKeepAlive());
    debugPrint('[Aliveness][主动] 调度器已启动（每分钟检查）');
  }

  Future<void> _syncKeepAlive() async {
    try {
      final settings = await _store.loadSettings();
      if (settings['keepAliveEnabled'] == true) {
        await AlivenessKeepAliveService.instance.start();
      }
    } catch (_) {}
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    unawaited(AlivenessKeepAliveService.instance.stop());
  }

  ChatPlugin get _plugin =>
      PluginManager.instance.getPlugin('chat')! as ChatPlugin;

  Future<void> _tick() async {
    try {
      final agents = await OpenAIPlugin.instance.controller.getAllAgents();
      for (final agent in agents) {
        final config = agent.alivenessConfig;
        if (config == null || !config.enabled || !config.proactiveEnabled) {
          continue;
        }
        await _checkAgent(agent, config);
      }
    } catch (e) {
      debugPrint('[Aliveness][主动] tick 失败: $e');
    }
  }

  Future<void> _checkAgent(AIAgent agent, AlivenessConfig config) async {
    final stats = await _store.loadStats(agent.id);
    final now = DateTime.now();

    // ---- 硬限制：免打扰时段 ----
    if (_inQuietHours(now, config.quietHours)) return;

    // ---- 硬限制：每日上限 ----
    final todayKey = '${now.year}-${now.month}-${now.day}';
    final countToday =
        stats['proactiveDateKey'] == todayKey
            ? (stats['proactiveCountToday'] as int? ?? 0)
            : 0;
    if (countToday >= config.proactiveDailyLimit) return;

    // ---- 硬限制：冷却 ----
    final cooldownUntil = stats['cooldownUntil'] as String?;
    if (cooldownUntil != null &&
        now.isBefore(DateTime.parse(cooldownUntil))) {
      return;
    }

    final state = await _states.load(
      agent.id,
      intimacyHalfLifeDays: config.forgettingHalfLifeDays,
    );

    // ---- 触发源 1：开环事件到期（如"用户明天面试"）----
    String triggerInstruction;
    final loops = await _memory.loadOpenLoops(agent.id);
    final dueLoop = loops
        .where(
          (l) =>
              !l.closed && l.followUpBy != null && now.isAfter(l.followUpBy!),
        )
        .firstOrNull;
    if (dueLoop != null) {
      debugPrint('[Aliveness][主动] 开环到期触发 | "${dueLoop.description}"');
      triggerInstruction =
          '你之前记住了用户的一件事：「${dueLoop.description}」，现在到了该跟进的时间。'
          '自然地问问这件事怎么样了，像朋友想起来随口一问。';
      dueLoop.closed = true; // 主动跟进一次后关闭该开环
      await _memory.saveOpenLoops(agent.id, loops);
    } else {
      // ---- 触发源 2：闲置思念（距上次互动久 + 关系够近 + 概率）----
      final last = state.lastInteractionAt;
      final idleLongEnough =
          last == null || now.difference(last) > _idleThreshold;
      if (!(idleLongEnough &&
          state.intimacy > 0.5 &&
          _rng.nextDouble() < _idleChance)) {
        return;
      }
      debugPrint('[Aliveness][主动] 闲置思念触发 | '
          '距上次互动=${last == null ? "从未" : "${now.difference(last).inHours}h"} '
          '亲密度=${state.intimacy.toStringAsFixed(2)}');
      // 分流：按概率改为发朋友圈（不打扰用户、不依赖上次互动频道）
      if (_rng.nextDouble() < _momentChance) {
        await _postProactiveMoment(agent, state);
        await _recordProactive(agent.id, stats, config, countToday, now);
        return;
      }
      triggerInstruction =
          '你已经有一段时间没和用户说话了，突然想起了 TA。'
          '像真人一样主动发一条消息：可以是你突然想到的事、或者自然地表达想念。'
          '一句话就好，不要太黏腻。';
    }

    // ---- 目标频道：上次互动频道 ----
    final channelId = stats['lastChannelId'] as String?;
    if (channelId == null) return;
    final channelExists = _plugin.channelService.channels.any(
      (c) => c.id == channelId,
    );
    if (!channelExists) return;

    await _sendProactive(agent, channelId, state, triggerInstruction);

    // ---- 更新统计（计数 + 冷却） ----
    await _recordProactive(agent.id, stats, config, countToday, now);
  }

  /// 记录一次主动行为（计数 + 冷却，朋友圈与聊天消息共用）
  Future<void> _recordProactive(
    String agentId,
    Map<String, dynamic> stats,
    AlivenessConfig config,
    int countToday,
    DateTime now,
  ) async {
    stats['proactiveDateKey'] = '${now.year}-${now.month}-${now.day}';
    stats['proactiveCountToday'] = countToday + 1;
    stats['cooldownUntil'] = now
        .add(Duration(minutes: config.proactiveCooldownMin))
        .toIso8601String();
    await _store.saveStats(agentId, stats);
  }

  /// 闲置思念分流：自主发一条朋友圈（纯文字即可，零成本配图=随机引用已有资产图）
  Future<void> _postProactiveMoment(AIAgent agent, AgentState state) async {
    final basePrompt = await RequestService.getEffectiveSystemPrompt(agent);
    final tagKeys = MomentTags.all.map((t) => t.key).join('/');
    final system = '$basePrompt\n\n【你的当前状态】${state.describe()}。\n'
        '【任务】你现在想发一条朋友圈动态，分享此刻的心情、见闻或生活琐事。\n'
        '输出两行：\n'
        '第一行：动态文案（1~2句话，像真人发朋友圈的语气，不要引号）\n'
        '第二行：标签，必须是 $tagKeys 之一（生活/美食/设计/萌宠/心情/旅行，按内容选最贴切的）\n'
        '不要输出其他任何内容。';

    final content = await RequestService.chat(
      '（朋友圈）',
      agent,
      contextMessages: [ChatCompletionMessage.system(content: system)],
    );
    if (content.trim().isEmpty || content.trim().startsWith('Error:')) return;

    // 宽松解析：末行命中标签枚举则视为标签，否则整段都当文案（纯文本）
    var text = content.trim();
    var tag = MomentTags.defaultKey;
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length >= 2) {
      final matched = MomentTags.matchKey(lines.last);
      if (matched != null) {
        tag = matched;
        text = lines.sublist(0, lines.length - 1).join('\n');
      }
    }
    if (text.isEmpty) return;

    // 零成本配图：若已有生成好的资产图，一半概率随机引用一张
    var images = const <String>[];
    try {
      final ready =
          (await AgentAssetsService.instance.getAssets(agent.id))
              .where((a) => a.hasImage)
              .toList();
      if (ready.isNotEmpty && _rng.nextBool()) {
        images = [ready[_rng.nextInt(ready.length)].path!];
      }
    } catch (_) {}

    await MomentsService.instance.addPost(
      agentId: agent.id,
      text: text,
      images: images,
      source: 'agent',
      tag: tag,
    );
    final preview = text.length > 30 ? '${text.substring(0, 30)}…' : text;
    debugPrint('[Aliveness][主动] 已发朋友圈 | agent=${agent.name} '
        '配图=${images.isEmpty ? "无" : "资产图"} 标签=$tag 内容="$preview"');
  }

  /// 免打扰：支持跨午夜区间（如 [23, 8]）
  bool _inQuietHours(DateTime now, List<int> hours) {
    if (hours.length != 2) return false;
    final start = hours[0], end = hours[1];
    final h = now.hour;
    return start <= end ? (h >= start && h < end) : (h >= start || h < end);
  }

  Future<void> _sendProactive(
    AIAgent agent,
    String channelId,
    AgentState state,
    String triggerInstruction,
  ) async {
    // 记忆联想：按触发内容激活相关记忆碎片（记忆管理关闭时跳过）
    final memorySummary = agent.alivenessConfig?.memoryEnabled != true
        ? ''
        : await _memory.buildMemorySummary(
            agent.id,
            triggerInstruction,
            halfLifeDays: agent.alivenessConfig?.forgettingHalfLifeDays ?? 14,
          );

    final basePrompt = await RequestService.getEffectiveSystemPrompt(agent);
    final system = '$basePrompt\n\n【你的当前状态】${state.describe()}。\n'
        '${memorySummary.isEmpty ? '' : '你想起关于用户的这些事：\n$memorySummary\n'}'
        '【任务】$triggerInstruction\n'
        '只输出消息内容本身（1~2句话），不要任何前缀、引号或解释。';

    final content = await RequestService.chat(
      '（主动消息）',
      agent,
      contextMessages: [ChatCompletionMessage.system(content: system)],
    );
    final text = content.trim();
    if (text.isEmpty || text.startsWith('Error:')) return;

    // 分条写入频道
    final aiUser = User(
      id: agent.id,
      username: agent.name,
      iconPath: await ImageUtils.getAbsolutePath(agent.avatarUrl),
    );
    final bubbles = _executor.splitIntoBubbles(
      text,
      agent.alivenessConfig?.maxBubbles ?? 3,
    );
    for (var i = 0; i < bubbles.length; i++) {
      if (i > 0) {
        await Future.delayed(
          Duration(
            milliseconds:
                (agent.alivenessConfig?.bubbleDelayMinMs ?? 800) +
                _rng.nextInt(1500),
          ),
        );
      }
      final message = await Message.create(
        id:
            'ai_proactive_${agent.id}_${DateTime.now().millisecondsSinceEpoch}_$i',
        content: bubbles[i],
        channelId: channelId,
        user: aiUser,
        type: MessageType.received,
        metadata: {
          'isAI': true,
          'agentId': agent.id,
          'isProactive': true,
          'isCompleted': true,
        },
      );
      await _plugin.channelService.addMessage(channelId, message);
      _plugin.refresh();
      EventManager.instance.broadcast(
        'chat_message_updated',
        Value<Message>(message),
      );
    }

    _notify(agent, bubbles.first);
    final preview = bubbles.first.length > 30
        ? '${bubbles.first.substring(0, 30)}…'
        : bubbles.first;
    debugPrint('[Aliveness][主动] 已发送 | agent=${agent.name} 频道=$channelId '
        '共${bubbles.length}条 内容="$preview"');
  }

  void _notify(AIAgent agent, String preview) {
    // 通知失败不影响主流程（桌面端可能不支持）
    try {
      unawaited(
        AboutmeNotifications.instance.showNotification(
          id: agent.id.hashCode & 0x7fffffff,
          title: agent.name,
          body: preview,
          payload: {'type': 'aliveness_proactive', 'agentId': agent.id},
        ),
      );
    } catch (_) {}
  }
}
