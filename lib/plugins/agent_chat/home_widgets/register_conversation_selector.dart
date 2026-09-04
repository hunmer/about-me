/// Agent Chat - 会话选择器组件注册
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/services/plugin_data_selector/models/selector_result.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/home_screen/widgets/generic_selector_widget.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/widgets/event_listener_container.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import '../agent_chat_plugin.dart';
import 'providers.dart';
import 'utils.dart' as utils;

/// 注册选择器小组件 - 快速进入指定频道
void registerConversationSelector(HomeWidgetRegistry registry) {
  registry.register(
    HomeWidget(
      id: 'agent_chat_conversation_selector',
      pluginId: 'agent_chat',
      name: 'agent_chat_conversationQuickAccess'.tr,
      description: 'agent_chat_conversationQuickAccessDesc'.tr,
      icon: Icons.chat,
      color: const Color(0xFF2196F3),
      defaultSize: const MediumSize(),
      supportedSizes: [const MediumSize(), const LargeSize()],
      category: 'home_categoryTools'.tr,

      selectorId: 'agent_chat.conversation',
      dataRenderer: _renderConversationData,
      navigationHandler: _navigateToConversation,
      dataSelector: extractConversationData,

      builder: (context, config) {
        return GenericSelectorWidget(
          widgetDefinition:
              registry.getWidget('agent_chat_conversation_selector')!,
          config: config,
        );
      },
    ),
  );
}

/// 渲染选中的会话数据
Widget _renderConversationData(
  BuildContext context,
  SelectorResult result,
  Map<String, dynamic> config,
) {
  // 从初始化数据中获取会话ID
  final convData = result.data as Map<String, dynamic>;
  final conversationId = convData['id'] as String?;

  if (conversationId == null) {
    return HomeWidget.buildErrorWidget(
      context,
      'agent_chat_conversationNotFound'.tr,
    );
  }

  // 使用 StatefulBuilder 和 EventListenerContainer 实现动态更新
  return StatefulBuilder(
    builder: (context, setState) {
      return EventListenerContainer(
        events: const [
          'agent_chat_conversation_added',
          'agent_chat_conversation_updated',
          'agent_chat_conversation_deleted',
        ],
        onEvent: () => setState(() {}),
        child: _buildConversationWidget(context, conversationId),
      );
    },
  );
}

/// 构建会话小组件内容（获取最新数据）
Widget _buildConversationWidget(BuildContext context, String conversationId) {
  // 从 PluginManager 获取最新的会话数据
  final plugin =
      PluginManager.instance.getPlugin('agent_chat') as AgentChatPlugin?;
  if (plugin == null) {
    return HomeWidget.buildErrorWidget(
      context,
      'agent_chat_pluginNotAvailable'.tr,
    );
  }

  // 查找对应会话
  final conversation = plugin.conversationController!.conversations.firstWhere(
    (c) => c.id == conversationId,
    orElse: () => throw Exception('会话不存在'),
  );

  // 使用最新的会话数据
  final title = conversation.title;
  final lastMessagePreview = conversation.lastMessagePreview ?? '';
  final lastMessageAt = conversation.lastMessageAt;
  final agentId = conversation.agentId;

  return DSThemeBridge(
    child: Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  DsIcon(DsIconKind.chat, size: 20, color: theme.text),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: DsTypography.heading.copyWith(color: theme.text),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 最后一条消息预览
              if (lastMessagePreview.isNotEmpty)
                Expanded(
                  child: Text(
                    lastMessagePreview,
                    style: DsTypography.body.copyWith(color: theme.textSub),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Text(
                      '暂无消息',
                      style: DsTypography.body.copyWith(color: theme.textSub),
                    ),
                  ),
                ),

              // 时间和 Agent 信息
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    utils.formatDateTime(lastMessageAt),
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                  // Agent 信息（异步加载）
                  if (agentId != null)
                    FutureBuilder<AIAgent?>(
                      future: _getAgentById(agentId),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DsIcon(
                                DsIconKind.bot,
                                size: 12,
                                color: theme.textSub,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                snapshot.data!.name,
                                style: DsTypography.caption.copyWith(
                                  color: theme.textSub,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// 根据 ID 获取 Agent
Future<AIAgent?> _getAgentById(String agentId) async {
  try {
    final openAIPlugin =
        PluginManager.instance.getPlugin('openai') as OpenAIPlugin?;
    if (openAIPlugin != null) {
      return await openAIPlugin.controller.getAgent(agentId);
    }
  } catch (e) {
    debugPrint('获取 Agent 失败: $e');
  }
  return null;
}

/// 导航到选中的会话
void _navigateToConversation(BuildContext context, SelectorResult result) {
  final convData = result.data as Map<String, dynamic>;
  final conversationId = convData['id'] as String;

  NavigationHelper.pushNamed(
    context,
    '/agent_chat/chat',
    arguments: {'conversationId': conversationId},
  );
}
