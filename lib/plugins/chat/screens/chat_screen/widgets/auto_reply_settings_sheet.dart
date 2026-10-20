import 'package:flutter/material.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';
import 'package:aboutme/plugins/openai/widgets/agent_list_drawer.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 读取频道自动回复配置（channel.metadata['autoReply']）
Map<String, dynamic> readAutoReplyConfig(Channel channel) {
  final raw = channel.metadata?['autoReply'];
  return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
}

/// 配置中的 agent（未配置返回 null）
Map<String, String>? autoReplyAgentOf(Map<String, dynamic> config) {
  final raw = config['agent'];
  if (raw is Map && raw['id'] is String && (raw['id'] as String).isNotEmpty) {
    return {'id': raw['id'] as String, 'name': (raw['name'] ?? '') as String};
  }
  return null;
}

/// 频道自动回复设置弹层（频道菜单「自动回复」与输入框智能体入口共用）：
/// - 总开关
/// - 指定的 agent（单选）
/// - 新建会话附带的上下文长度（默认 0，代表只传入当前这句话）
/// - 只传入当前的消息（默认开，开启时上下文长度不生效）
Future<void> showAutoReplySettingsSheet({
  required BuildContext context,
  required String channelId,
}) {
  final channelService = ChatPlugin.instance.channelService;
  final channel = channelService.channels
      .where((c) => c.id == channelId)
      .firstOrNull;
  if (channel == null) return Future.value();

  final config = ValueNotifier<Map<String, dynamic>>(
    Map<String, dynamic>.from(readAutoReplyConfig(channel)),
  );

  return SmoothBottomSheet.showForm<void>(
    context: context,
    title: '自动回复设置',
    onSave: () async {
      await channelService.updateChannelMetadata(channelId, {
        'autoReply': config.value,
      });
      if (context.mounted) Navigator.of(context).pop();
    },
    child: ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: config,
      builder: (builderContext, cfg, _) {
        final theme = DSThemeBridge.resolve(builderContext);
        final enabled = cfg['enabled'] == true;
        // currentOnly 默认开；contextCount 默认 0
        final currentOnly = cfg['currentOnly'] != false;
        final contextCount = (cfg['contextCount'] as num?)?.toInt() ?? 0;
        final agent = autoReplyAgentOf(cfg);

        void update(Map<String, dynamic> patch) =>
            config.value = {...config.value, ...patch};

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 总开关
              DSListItem(
                title: '开启自动回复',
                subtitle: '开启后频道内每条消息都会由指定 agent 评论',
                trailing: DSSwitch(
                  value: enabled,
                  onChanged: (v) => update({'enabled': v}),
                ),
              ),
              SizedBox(height: theme.spacing.sm),

              // 指定 agent
              DSListItem(
                leading: DsIcon(DsIconKind.bot, size: 20, color: theme.primary),
                title: '指定的 agent',
                subtitle: agent?['name'] ?? '未选择，点击选择',
                trailing: DsIcon(
                  DsIconKind.chevronRight,
                  size: 18,
                  color: theme.textSub,
                ),
                onTap: () => _pickAgent(builderContext, config, update),
              ),
              SizedBox(height: theme.spacing.sm),

              // 只传入当前的消息
              DSListItem(
                title: '只传入当前的消息',
                subtitle: '开启时不附带频道历史，仅把当前这句话发给 agent',
                trailing: DSSwitch(
                  value: currentOnly,
                  onChanged: (v) => update({'currentOnly': v}),
                ),
              ),
              SizedBox(height: theme.spacing.md),

              // 上下文长度（currentOnly 开时禁用）
              Opacity(
                opacity: currentOnly ? 0.45 : 1,
                child: IgnorePointer(
                  ignoring: currentOnly,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '新建会话附带的上下文长度',
                              style: DsTypography.body.copyWith(
                                color: theme.text,
                              ),
                            ),
                          ),
                          Text(
                            '$contextCount 条',
                            style: DsTypography.body.copyWith(
                              color: theme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      DSSlider(
                        value: (contextCount / 50).clamp(0.0, 1.0),
                        onChanged: (v) =>
                            update({'contextCount': (v * 50).round()}),
                      ),
                      Text(
                        '每次自动评论时附带频道最近 N 条消息作为上下文；'
                        '0 代表只传入当前这句话',
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// 在设置弹层之上再开一层 agent 单选抽屉，选中后写回配置
Future<void> _pickAgent(
  BuildContext sheetContext,
  ValueNotifier<Map<String, dynamic>> config,
  void Function(Map<String, dynamic>) update,
) async {
  final current = autoReplyAgentOf(config.value);
  await SmoothBottomSheet.show<List<Map<String, String>>>(
    context: sheetContext,
    builder: (context) => AgentListDrawer(
      selectedAgents: current == null ? const [] : [current],
      allowMultipleSelection: false,
      onAgentSelected: (agents) =>
          update({'agent': agents.isEmpty ? null : agents.first}),
    ),
  );
}
