import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

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
    developer.log('主动消息调度器已启动', name: 'ProactiveService');
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
      developer.log('主动消息 tick 失败: $e', name: 'ProactiveService');
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
    stats['proactiveDateKey'] = todayKey;
    stats['proactiveCountToday'] = countToday + 1;
    stats['cooldownUntil'] = now
        .add(Duration(minutes: config.proactiveCooldownMin))
        .toIso8601String();
    await _store.saveStats(agent.id, stats);
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
    // 记忆联想：按触发内容激活相关记忆碎片
    final memorySummary = await _memory.buildMemorySummary(
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
    developer.log(
      '已发送主动消息到频道 $channelId: ${bubbles.first}',
      name: 'ProactiveService',
    );
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
