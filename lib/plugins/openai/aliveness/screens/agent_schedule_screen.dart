import 'package:flutter/material.dart';

import 'package:aboutme/plugins/activity/widgets/activity_timeline.dart';
import 'package:aboutme/plugins/openai/aliveness/services/schedule_service.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';

/// AI 日程表：展示活人感 agent 今日的 24 小时真实生活安排，
/// 时间线复用 activity 插件的 ActivityTimeline。
/// 今日首次聊天时自动生成，也可在此手动生成/重新生成。
class AgentScheduleScreen extends StatefulWidget {
  final String agentId;
  final String agentName;

  const AgentScheduleScreen({
    super.key,
    required this.agentId,
    required this.agentName,
  });

  @override
  State<AgentScheduleScreen> createState() => _AgentScheduleScreenState();
}

class _AgentScheduleScreenState extends State<AgentScheduleScreen> {
  AgentSchedule? _schedule;
  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final schedule = await ScheduleService.instance.loadToday(widget.agentId);
    if (!mounted) return;
    setState(() {
      _schedule = schedule;
      _loading = false;
    });
  }

  Future<void> _generate({bool force = false}) async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final agent =
          await OpenAIPlugin.instance.controller.getAgent(widget.agentId);
      if (agent == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('未找到该 AI 的配置')));
        }
        return;
      }
      final schedule = await ScheduleService.instance.ensureTodaySchedule(
        agent,
        force: force,
      );
      if (!mounted) return;
      if (schedule == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('生成失败，请稍后重试（需要该 AI 的模型可用）')),
        );
        return;
      }
      setState(() => _schedule = schedule);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _confirmRegenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重新生成今日日程？'),
        content: Text(
          '将丢弃「${widget.agentName}」今天的安排，按人物设定重新生成一份。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('重新生成'),
          ),
        ],
      ),
    );
    if (confirmed == true) _generate(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = _schedule;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.agentName} 的一天'),
        actions: [
          if (schedule != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重新生成',
              onPressed: _generating ? null : _confirmRegenerate,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : schedule == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wb_sunny_outlined,
                        size: 48,
                        color: theme.disabledColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _generating ? '正在按人物设定生成今日安排…' : '今日还没有日程',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.disabledColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!_generating)
                        FilledButton.icon(
                          onPressed: () => _generate(force: true),
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text('生成今日日程'),
                        ),
                    ],
                  ),
                )
              : _generating
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '这是 ${widget.agentName} 今天真实的生活安排，'
                            '聊天时会据此回答"你在干嘛"而不是编造。'
                            '今日首次聊天时会自动生成。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.disabledColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ActivityTimeline(
                            activities: ScheduleService.instance
                                .toActivityRecords(schedule),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
