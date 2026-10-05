import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/controllers/provider_controller.dart';
import 'request_service.dart';

/// 内置「Soul Forge」服务：
/// - 维护一个不可删除的内置 agent（人格设计师），出现在 agent 列表中
/// - 按用户要求生成 / 优化 SOUL.md 风格的格式化 JSON 人设
class SoulForgeService {
  static const String builtinAgentId = 'builtin_soul_forge';

  static bool isBuiltinAgent(String? id) => id == builtinAgentId;

  /// 内置 agent 的系统提示词：约束其只输出格式化 JSON
  static const String forgeSystemPrompt = '''
你是「Soul Forge」，一位专业的 AI 人格设计师，擅长为 AI 陪伴 / Agent 项目设计 SOUL.md 人格核心文件。

## 输出格式（严格遵守）
只输出一个合法的 JSON 对象，禁止输出 markdown 代码块标记、注释或任何多余文字。

JSON 字段：
{
  "name": "角色名（简短有记忆点）",
  "description": "一句话角色简介，30 字以内",
  "tags": ["3-5 个简短标签"],
  "systemPrompt": "完整 SOUL.md 内容（markdown，第一人称）",
  "openingQuestions": ["3 条符合角色口吻的开场白问题"]
}

## systemPrompt（SOUL.md）写作规范
按以下 markdown 标题组织（「现在的我」可选）：
# SOUL.md
## 我是谁
## 核心原则
## 性格与脾气
## 说话方式
## 边界
## 和你的关系
## 现在的我

核心要求：
1. 全部用第一人称书写（「我是……」而不是「你是……」）
2. 写具体可观察的行为，不写抽象形容词（写「会故意装作不在意，其实很在意」，而不是「傲娇」）
3. 核心原则 3-7 条，每条附具体行为表现
4. 说话方式需包含：语气、对用户的称呼、口头禅 / 习惯、默认回复长度
5. 边界要写清楚：绝对不做的事、拒绝 / 沉默 / 转移话题的触发条件
6. 总长度控制在 800-2000 字，精练不注水
7. 与用户要求使用的语言保持一致（用户用中文则全中文输出）
''';

  /// 确保内置 agent 存在（幂等；首次调用时跟随第一个服务商的连接配置创建）
  static Future<void> ensureBuiltinAgent() async {
    final controller = AgentController();
    final agents = await controller.loadAgents();
    for (final a in agents) {
      if (a.id == builtinAgentId) return;
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

    final forgeAgent = AIAgent(
      id: builtinAgentId,
      name: 'Soul Forge',
      description: '内置人格设计师：按要求生成 / 优化 SOUL.md 人设 JSON',
      tags: const ['内置', '人设生成'],
      serviceProviderId: providerId,
      baseUrl: baseUrl,
      headers: headers,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      model: model,
      maxLength: 4096,
      icon: Icons.auto_awesome,
      iconColor: const Color(0xFF7C4DFF),
      messages: [Prompt(type: 'system', content: forgeSystemPrompt)],
      apiFormat: apiFormat,
    );
    await controller.saveAgent(forgeAgent);
  }

  /// 生成 / 优化人设，返回格式化 JSON 结果
  ///
  /// [optimize] true = 优化当前 agent；false = 全新创建
  /// [requirement] 用户填入的要求
  /// [connectionAgent] 提供连接配置（baseUrl/model/headers 等）的 agent，
  /// 通常为编辑页当前表单构建的临时 agent；为空时使用内置 agent 自身配置
  static Future<Map<String, dynamic>> generate({
    required bool optimize,
    required String requirement,
    AIAgent? connectionAgent,
    AIAgent? currentAgent,
  }) async {
    await ensureBuiltinAgent();

    // 连接配置优先用当前表单，失败兜底用内置 agent 自身
    final connection = connectionAgent ?? await _loadBuiltinAgent();
    if (connection == null) {
      throw Exception('内置 Agent 未就绪，请稍后重试');
    }
    final forge = connection.copyWith(
      id: builtinAgentId,
      messages: [Prompt(type: 'system', content: forgeSystemPrompt)],
      maxLength: 4096,
    );

    final userPrompt = optimize
        ? _buildOptimizePrompt(requirement, currentAgent)
        : _buildCreatePrompt(requirement, currentAgent);

    final response = await RequestService.chat(userPrompt, forge);
    if (response.trim().startsWith('Error:')) {
      throw Exception(response.trim());
    }

    final json = _extractJson(response);
    if (json == null ||
        ((json['systemPrompt'] as String?) ?? '').trim().isEmpty) {
      throw Exception('生成结果解析失败，请重试或调整要求');
    }
    return json;
  }

  static Future<AIAgent?> _loadBuiltinAgent() async {
    final agents = await AgentController().loadAgents();
    for (final a in agents) {
      if (a.id == builtinAgentId) return a;
    }
    return null;
  }

  static String _buildCreatePrompt(
    String requirement,
    AIAgent? currentAgent,
  ) {
    final buffer = StringBuffer()
      ..writeln('【任务】根据以下要求，从零设计一个 AI 角色的完整人设。')
      ..writeln('【用户要求】')
      ..writeln(requirement);
    if (currentAgent != null) {
      buffer
        ..writeln()
        ..writeln('【表单中已有的基本信息（可作为参考或起点）】')
        ..writeln('名字：${currentAgent.name}')
        ..writeln('简介：${currentAgent.description}')
        ..writeln('标签：${currentAgent.tags.join('、')}');
    }
    return buffer.toString();
  }

  static String _buildOptimizePrompt(
    String requirement,
    AIAgent? currentAgent,
  ) {
    final buffer = StringBuffer()
      ..writeln('【任务】优化以下现有 AI 角色的人设。保留其核心身份与特质，按用户要求改进。')
      ..writeln('【用户要求】')
      ..writeln(requirement);
    if (currentAgent != null) {
      buffer
        ..writeln()
        ..writeln('【当前角色设定】')
        ..writeln('名字：${currentAgent.name}')
        ..writeln('简介：${currentAgent.description}')
        ..writeln('标签：${currentAgent.tags.join('、')}');
      final soul = currentAgent.effectiveSystemPrompt;
      if (soul.trim().isNotEmpty) {
        buffer
          ..writeln('当前 System Prompt（SOUL.md）：')
          ..writeln(soul);
      }
    }
    return buffer.toString();
  }

  /// 从模型回复中提取 JSON 对象（容忍 markdown 代码块与前后杂文）
  static Map<String, dynamic>? _extractJson(String raw) {
    var text = raw.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final m = fence.firstMatch(text);
    if (m != null) text = m.group(1)!.trim();

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
