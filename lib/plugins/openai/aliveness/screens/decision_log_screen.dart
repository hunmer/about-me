import 'package:flutter/material.dart';

import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';

/// 决策日志查看页（可观测性）：展示某 agent 最近的 Jev/规则决策记录，
/// 回答"为什么这样回"（PRD 7 可观测性需求）。
class DecisionLogScreen extends StatefulWidget {
  final String agentId;
  final String agentName;

  const DecisionLogScreen({
    super.key,
    required this.agentId,
    required this.agentName,
  });

  @override
  State<DecisionLogScreen> createState() => _DecisionLogScreenState();
}

class _DecisionLogScreenState extends State<DecisionLogScreen> {
  List<dynamic> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await AlivenessStore.instance.loadDecisions(widget.agentId);
    if (!mounted) return;
    setState(() {
      // 最新在前
      _logs = logs.reversed.toList();
      _loading = false;
    });
  }

  String _strategyLabel(String? name) => switch (name) {
    'minimal' => '极简',
    'detailed' => '详细',
    'shiftTopic' => '主动转移',
    _ => '正常',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('决策日志 · ${widget.agentName}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
          ? Center(
              child: Text(
                '暂无决策记录\n开启活人感并聊天后这里会显示每次的决策过程',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.disabledColor,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = Map<String, dynamic>.from(
                  _logs[index] as Map<dynamic, dynamic>,
                );
                final ts = log['ts'] as String? ?? '';
                final source = log['source'] as String? ?? '';
                final time = ts.length >= 16 ? ts.substring(5, 16) : ts;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              time,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.disabledColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: source == 'jev'
                                    ? theme.colorScheme.primaryContainer
                                    : theme.disabledColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                source == 'jev' ? 'Jev' : '规则',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '策略：${_strategyLabel(log['strategy'] as String?)} · '
                          '延迟：${log['delaySeconds'] ?? 0}s · '
                          '${log['shouldReplyNow'] == true ? '立即回复' : '已读不回'}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if ((log['exploreQuestion'] as String?) != null)
                          Text(
                            '探索问题：${log['exploreQuestion']}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        if (log['memoryActivated'] == true)
                          Text(
                            '已激活相关记忆',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.tertiary,
                            ),
                          ),
                        Text(
                          '用户情绪：${(((log['userEmotion'] as num?) ?? 0) as double).toStringAsFixed(2)} · '
                          '缓冲消息：${log['bufferedCount'] ?? 0} 条',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.disabledColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
