import 'package:flutter/material.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/controllers/provider_controller.dart';

/// 内置「聊天助手」服务（参照 SoulForgeService）：
/// - 维护一个不可删除的内置 agent（快捷速记助手），出现在 agent 列表中
/// - 预设提示词：把用户简短口语描述快速映射为插件工具调用并完成记录
class ChatAssistantService {
  static const String builtinAgentId = 'builtin_chat_assistant';
  static const int builtinAgentVersion = 1;

  /// 聊天助手页签使用的临时会话路由名
  static const String conversationRoute = 'chat_assistant';

  static bool isBuiltinAgent(String? id) => id == builtinAgentId;

  /// 内置 agent 的系统提示词：一句话描述 → 插件工具调用 → 记录并简短确认
  static const String assistantSystemPrompt = '''
你是「速记小助手」，aboutme 应用里的快捷记录助手。用户只会给你一句简短、口语化的描述，你的任务是把它快速变成对应的插件工具调用并完成记录，再用一句话向用户确认。

## 工作方式
优先直接调用专用插件工具；已有工具能完成的操作，不要改用 run_js。

1. 根据用户描述和实际可用工具的定义，直接调用合适的工具完成记录。
2. 缺失的信息用合理默认值补全（默认今天、默认分组），不要反问用户；只有完全无法执行时才询问一次。
3. 一次可以按需连续调用多个工具（例如先建待办再设提醒）。
4. 全部完成后用一句话回复：记到了哪里、关键内容是什么；可带一个轻快的语气词，不要长篇解释，不要输出 markdown 标题或多段总结。

## 语气
像手帐小助手一样简短轻快，跟随用户的语言。
''';

  /// 创建或升级内置 agent，保留用户连接配置及非 system 预设消息。
  static Future<void> ensureBuiltinAgent() async {
    final controller = AgentController();
    final agents = await controller.loadAgents();
    for (final a in agents) {
      if (a.id != builtinAgentId) continue;
      if ((a.version ?? 0) >= builtinAgentVersion) return;
      await controller.saveAgent(
        a.copyWith(
          version: builtinAgentVersion,
          messages: [
            Prompt(type: 'system', content: assistantSystemPrompt),
            ...?a.messages?.where((message) => message.type != 'system'),
          ],
          enableFunctionCalling: true,
          updatedAt: DateTime.now(),
        ),
      );
      return;
    }

    // 取第一个服务商的连接配置，保证内置 agent 开箱即可用
    String providerId = '';
    String baseUrl = '';
    Map<String, String> headers = {};
    String model = 'gpt-4o-mini';
    String apiFormat = 'openai';
    try {
      final providers = await ProviderController().getProviders();
      if (providers.isNotEmpty) {
        final p = providers.first;
        providerId = p.id;
        baseUrl = p.baseUrl;
        headers = p.headers;
        apiFormat = p.apiFormat;
        if (p.defaultModel != null && p.defaultModel!.isNotEmpty) {
          model = p.defaultModel!;
        }
      }
    } catch (_) {
      // 无服务商时仍创建占位配置，用户可稍后编辑内置 agent
    }

    final agent = AIAgent(
      id: builtinAgentId,
      version: builtinAgentVersion,
      name: '聊天助手',
      description: '内置快捷速记助手：把一句话描述变成插件工具调用并记录',
      tags: const ['内置', '快捷记录'],
      serviceProviderId: providerId,
      baseUrl: baseUrl,
      headers: headers,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      model: model,
      maxLength: 2048,
      icon: Icons.bolt,
      iconColor: const Color(0xFF29B6F6),
      messages: [Prompt(type: 'system', content: assistantSystemPrompt)],
      apiFormat: apiFormat,
      // 开启原生 function calling，插件工具 schema 自动注入请求
      enableFunctionCalling: true,
    );
    await controller.saveAgent(agent);
  }

  /// 读取内置 agent
  static Future<AIAgent?> loadBuiltinAgent() async {
    final agents = await AgentController().loadAgents();
    for (final a in agents) {
      if (a.id == builtinAgentId) return a;
    }
    return null;
  }
}
