import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:flutter/foundation.dart';
import 'package:agentlib/openai_compat.dart';
import '../../models/saved_tool_template.dart';
import '../../models/tool_call_step.dart';
import '../../models/chat_message.dart';
import '../../services/tool_service.dart';
import '../../services/tool_config_manager.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';
import 'shared/manager_context.dart';

/// 工具模板执行管理器
///
/// 负责工具模板的匹配、分析和执行
/// 支持智能参数替换和代码重写
/// 遵循单一职责原则 (SRP)
class TemplateExecutor {
  final ManagerContext context;

  /// 当前 Agent getter
  final AIAgent? Function() getCurrentAgent;

  /// 工具步骤执行器
  final Future<void> Function(String messageId, List<ToolCallStep> steps)?
  executeToolSteps;

  TemplateExecutor({
    required this.context,
    required this.getCurrentAgent,
    this.executeToolSteps,
  });

  // ========== 核心方法 ==========

  /// 执行 AI 匹配的模板（自动匹配路径）
  Future<void> executeMatched(String aiMessageId, String templateId) async {
    if (context.templateService == null) {
      debugPrint('⚠️ ToolTemplateService 不可用');
      return;
    }

    try {
      // 加载模板
      final template = context.templateService!.getTemplateById(templateId);
      if (template == null) {
        debugPrint('⚠️ 模板 $templateId 不存在');
        final message = context.messageService.getMessage(
          context.conversationId,
          aiMessageId,
        );
        if (message != null) {
          await context.messageService.updateMessage(
            message.copyWith(content: '错误：选择的模板不存在', isGenerating: false),
          );
        }
        return;
      }

      debugPrint('✅ 执行匹配的模板: ${template.name}');

      // 从消息元数据中读取 AI 预先分析的策略和数据
      TemplateStrategy strategy = TemplateStrategy.replace;
      List<ReplacementRule>? replacements;
      List<ToolCallStep>? rewrittenSteps;

      final message = context.messageService.getMessage(
        context.conversationId,
        aiMessageId,
      );
      if (message?.metadata != null) {
        final templateMatches =
            message!.metadata!['templateMatches'] as List<dynamic>?;
        if (templateMatches != null) {
          final matchData = templateMatches.firstWhere(
            (m) => m['id'] == templateId,
            orElse: () => null,
          );

          if (matchData != null) {
            // 解析策略
            final strategyStr = matchData['strategy'] as String? ?? 'replace';
            strategy =
                strategyStr == 'rewrite'
                    ? TemplateStrategy.rewrite
                    : TemplateStrategy.replace;

            // 解析 replace 策略的替换规则
            if (strategy == TemplateStrategy.replace &&
                matchData['replacements'] != null) {
              final replacementsList =
                  matchData['replacements'] as List<dynamic>;
              replacements =
                  replacementsList
                      .map(
                        (r) => ReplacementRule(
                          from: r['from'] as String,
                          to: r['to'] as String,
                        ),
                      )
                      .toList();
            }

            // 解析 rewrite 策略的重写代码
            if (strategy == TemplateStrategy.rewrite &&
                matchData['rewritten_steps'] != null) {
              final stepsList = matchData['rewritten_steps'] as List<dynamic>;
              rewrittenSteps =
                  stepsList
                      .map(
                        (s) => ToolCallStep(
                          method: s['method'] as String,
                          title: s['title'] as String,
                          desc: s['desc'] as String,
                          data: s['data'] as String,
                        ),
                      )
                      .toList();
            }
          }
        }
      }

      // ✅ 使用统一的执行入口
      final resultSummary = await executeWithSmartReplacement(
        messageId: aiMessageId,
        template: template,
        strategy: strategy,
        replacements: replacements,
        rewrittenSteps: rewrittenSteps,
      );

      // 返回结果摘要供后续处理
      debugPrint('🤖 工具模板执行完成，结果摘要长度: ${resultSummary.length}');
    } catch (e) {
      debugPrint('❌ 执行匹配模板失败: $e');
      final message = context.messageService.getMessage(
        context.conversationId,
        aiMessageId,
      );
      if (message != null) {
        await context.messageService.updateMessage(
          message.copyWith(content: '执行模板时出错: $e', isGenerating: false),
        );
      }
    }
  }

  /// 🔄 统一的模板执行入口（带智能参数替换/重写）
  ///
  /// 参数：
  /// - messageId: 消息 ID（用于更新执行状态）
  /// - template: 要执行的模板
  /// - strategy: 修改策略（replace 或 rewrite）
  /// - userInput: 用户输入（可选，用于参数分析）
  /// - replacements: 预先分析的替换规则（strategy=replace 时使用）
  /// - rewrittenSteps: 重写后的代码步骤（strategy=rewrite 时使用）
  Future<String> executeWithSmartReplacement({
    required String messageId,
    required SavedToolTemplate template,
    TemplateStrategy strategy = TemplateStrategy.replace,
    String? userInput,
    List<ReplacementRule>? replacements,
    List<ToolCallStep>? rewrittenSteps,
  }) async {
    List<ToolCallStep> steps;

    // 根据策略选择执行路径
    if (strategy == TemplateStrategy.rewrite &&
        rewrittenSteps != null &&
        rewrittenSteps.isNotEmpty) {
      // 🔄 重写策略：直接使用 AI 生成的新代码
      debugPrint('📝 使用 rewrite 策略，执行 AI 重写的代码');
      debugPrint('  重写步骤数: ${rewrittenSteps.length}');
      steps = rewrittenSteps;
    } else {
      // 🔄 替换策略：克隆模板步骤并应用替换规则
      debugPrint('🔄 使用 replace 策略');
      steps = _cloneTemplateSteps(template);

      // 获取参数替换规则（按优先级）
      List<ReplacementRule>? finalReplacements = replacements;

      // 如果没有预先提供替换规则，且有用户输入，则实时分析
      if (finalReplacements == null &&
          userInput != null &&
          userInput.isNotEmpty &&
          userInput.toLowerCase() != template.name.toLowerCase() &&
          getCurrentAgent() != null &&
          getCurrentAgent()!.enableFunctionCalling) {
        debugPrint('🔄 实时分析模板修改策略');
        debugPrint('  用户输入: "$userInput"');
        debugPrint('  模板名称: "${template.name}"');

        final analysisResult = await analyzeModification(userInput, template);

        if (analysisResult != null) {
          if (analysisResult.strategy == TemplateStrategy.rewrite &&
              analysisResult.rewrittenSteps != null &&
              analysisResult.rewrittenSteps!.isNotEmpty) {
            // 切换到 rewrite 策略
            debugPrint('📝 切换到 rewrite 策略');
            steps =
                analysisResult.rewrittenSteps!
                    .map(
                      (s) => ToolCallStep(
                        method: s['method'] as String,
                        title: s['title'] as String,
                        desc: s['desc'] as String,
                        data: s['data'] as String,
                      ),
                    )
                    .toList();
          } else {
            finalReplacements = analysisResult.replacements;
          }
        }
      }

      // 应用参数替换（仅 replace 策略）
      if (finalReplacements != null && finalReplacements.isNotEmpty) {
        debugPrint('✅ 应用 ${finalReplacements.length} 个参数替换规则');
        for (var rule in finalReplacements) {
          debugPrint('  - "${rule.from}" → "${rule.to}"');
        }
        steps = ToolService.applyReplacements(steps, finalReplacements);
      }
    }

    // 3. 标记模板使用
    if (context.templateService != null) {
      await context.templateService!.markTemplateAsUsed(template.id);
    }

    // 4. 更新消息，显示正在执行
    final message = context.messageService.getMessage(
      context.conversationId,
      messageId,
    );
    if (message != null) {
      await context.messageService.updateMessage(
        message.copyWith(
          content: '正在执行工具模板: ${template.name}',
          isGenerating: true,
          toolCall: ToolCallResponse(steps: steps),
          matchedTemplateIds: [], // 清除匹配列表（必须用空列表，null 不会清除）
        ),
      );
    }

    // 5. 执行工具步骤
    if (executeToolSteps != null) {
      await executeToolSteps!(messageId, steps);
    }

    // 6. 构建执行结果摘要
    final resultSummary = _buildToolResultMessage(steps);

    // 7. 更新消息内容（保留 toolCall 数据，确保包含最新的步骤状态）
    final finalMessage = context.messageService.getMessage(
      context.conversationId,
      messageId,
    );
    if (finalMessage != null) {
      final updatedMessage = finalMessage.copyWith(
        content: '已执行工具模板: ${template.name}\n\n执行结果：\n$resultSummary',
        // 保留 toolCall，确保包含最新的步骤执行状态
        toolCall: ToolCallResponse(steps: steps),
        // 清除 matchedTemplateIds，否则 UI 会优先显示模板选择而不是工具调用步骤
        matchedTemplateIds: [],
        // 保持 isGenerating = true，等待 AI 回复完成后再设置为 false
        // isGenerating 会在续写完成后由 completeAIMessage 设置
      );
      await context.messageService.updateMessage(updatedMessage);

      // 8. 保存消息详情（用于后续查看工具调用详情）
      await _saveToolTemplateDetail(
        messageId: messageId,
        aiMessage: updatedMessage,
        template: template,
        steps: steps,
        resultSummary: resultSummary,
        userInput: userInput,
      );
    }

    return resultSummary;
  }

  /// 让 AI 分析用户输入和模板之间的差异，返回修改策略
  Future<TemplateMatch?> analyzeModification(
    String userInput,
    SavedToolTemplate template,
  ) async {
    final currentAgent = getCurrentAgent();
    if (currentAgent == null) return null;

    try {
      // 获取模板的完整代码用于分析（支持 rewrite 场景）
      final steps = _cloneTemplateSteps(template);
      final fullCodePreview = steps
          .map((step) {
            return '### ${step.title}\n```javascript\n${step.data}\n```';
          })
          .join('\n\n');

      // 一次提供可用 API，直接返回替换规则或完整重写代码。
      final toolDetailPrompt = await ToolService.getToolDetailPrompt(
        ToolConfigManager.instance
            .getToolIndex(enabledOnly: true)
            .map((tool) => tool.first)
            .toList(),
        includeCallFormat: false,
      );

      final prompt = '''
分析用户输入和工具模板的差异，选择合适的修改策略。

**模板名称**: ${template.name}
${template.description != null ? '**模板描述**: ${template.description}\n' : ''}
**用户输入**: $userInput

**模板完整代码**:
$fullCodePreview

## 🎯 双策略选择

**策略1: `replace` - 关键词替换**（优先选择）
- 适用：功能相同，只是参数/名称不同
- 示例：模板"签到早起"→用户"签到早睡"，只需替换字符串

**策略2: `rewrite` - 重写代码**
- 适用：逻辑需要修改，简单替换无法满足
- 示例：原记录"个数"，改成记录"时长"（单位和逻辑都变了）
- 直接返回完整的 rewritten_steps，不要先选择工具或等待后续请求。

## 📝 返回格式

使用 replace 策略：
```json
{
  "strategy": "replace",
  "replacements": [{"from": "代码中实际字符串", "to": "新字符串"}]
}
```

使用 rewrite 策略：
```json
{
  "strategy": "rewrite",
  "rewritten_steps": [
    {"method": "run_js", "title": "步骤标题", "desc": "步骤描述", "data": "完整 JavaScript 代码"}
  ]
}
```

无需修改：
```json
{"strategy": "replace", "replacements": []}
```

⚠️ 注意：
- `strategy` 必填，必须是 "replace" 或 "rewrite"
- 优先使用 replace（能替换解决就不重写）
- replacements 的 `from` 必须是代码中**实际存在**的精确字符串
- rewrite 时必须返回非空的 rewritten_steps，代码必须实现用户需求，并参考原模板结构。
- 仅使用下方文档中的 API；禁止硬编码日期时间，使用 Aboutme.system.getCustomDate()。
- 禁止使用占位符，先查询获取真实数据；用 setResult(value); return value; 返回结果。

---
## 📋 可用工具 API 文档

$toolDetailPrompt
''';

      final buffer = StringBuffer();
      await RequestService.streamResponseWithRetry(
        agent: currentAgent,
        prompt: prompt,
        contextMessages: [],
        responseFormat: ResponseFormat.jsonSchema(
          jsonSchema: JsonSchemaObject(
            name: 'TemplateModification',
            description: '模板修改策略分析结果',
            strict: true,
            schema: {
              'type': 'object',
              'properties': {
                'strategy': {
                  'type': 'string',
                  'enum': ['replace', 'rewrite'],
                  'description': '修改策略',
                },
                'replacements': {
                  'type': 'array',
                  'description': 'replace策略时的替换规则',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'from': {'type': 'string'},
                      'to': {'type': 'string'},
                    },
                    'required': ['from', 'to'],
                    'additionalProperties': false,
                  },
                },
                'rewritten_steps': {
                  'type': 'array',
                  'description': 'rewrite策略时完整的代码步骤',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'method': {'type': 'string', 'enum': ['run_js']},
                      'title': {'type': 'string'},
                      'desc': {'type': 'string'},
                      'data': {'type': 'string'},
                    },
                    'required': ['method', 'title', 'desc', 'data'],
                    'additionalProperties': false,
                  },
                },
              },
              'required': ['strategy'],
              'additionalProperties': false,
            },
          ),
        ),
        onToken: (token) => buffer.write(token),
        onComplete: () {},
        onError: (error) => debugPrint('AI 参数分析错误: $error'),
        maxRetries: 10,
        retryDelay: 1000,
      );

      final response = buffer.toString();
      debugPrint('AI 参数分析响应: $response');

      // 使用统一的 JSON 解析方法
      final json = ToolService.parseJsonFromResponse(
        response,
        requiredField: 'strategy',
      );

      if (json == null) {
        debugPrint('⚠️ 解析模板修改策略失败：JSON解析失败');
        return null;
      }
      final strategyStr = json['strategy'] as String? ?? 'replace';
      final strategy =
          strategyStr == 'rewrite'
              ? TemplateStrategy.rewrite
              : TemplateStrategy.replace;

      debugPrint('AI 分析结果：策略=$strategyStr');

      if (strategy == TemplateStrategy.rewrite) {
        final rewrittenSteps = (json['rewritten_steps'] as List<dynamic>?)
            ?.map((step) => Map<String, dynamic>.from(step as Map))
            .toList();
        if (rewrittenSteps == null || rewrittenSteps.isEmpty) {
          debugPrint('rewrite 策略未返回代码步骤');
          return null;
        }
        debugPrint('模板重写完成：${rewrittenSteps.length} 个步骤');
        return TemplateMatch(
          id: template.id,
          strategy: TemplateStrategy.rewrite,
          rewrittenSteps: rewrittenSteps,
        );
      } else {
        // 解析替换规则
        final replacementsList = json['replacements'] as List<dynamic>? ?? [];
        if (replacementsList.isEmpty) {
          debugPrint('AI 分析结果：无需修改');
          return TemplateMatch(
            id: template.id,
            strategy: TemplateStrategy.replace,
          );
        }
        final rules =
            replacementsList
                .map(
                  (r) => ReplacementRule(
                    from: r['from'] as String,
                    to: r['to'] as String,
                  ),
                )
                .toList();
        debugPrint('AI 分析结果：找到 ${rules.length} 个替换规则');
        return TemplateMatch(
          id: template.id,
          strategy: TemplateStrategy.replace,
          replacements: rules,
        );
      }
    } catch (e) {
      debugPrint('AI 模板修改分析失败: $e');
      return null;
    }
  }

  // ========== 私有方法 ==========

  /// 克隆模板步骤（清除运行时状态）
  List<ToolCallStep> _cloneTemplateSteps(SavedToolTemplate template) {
    if (context.templateService != null) {
      return context.templateService!.cloneTemplateSteps(template);
    }
    return template.steps.map((s) => s.withoutRuntimeState()).toList();
  }

  /// 构建工具结果消息
  String _buildToolResultMessage(List<ToolCallStep> steps) {
    final buffer = StringBuffer();
    buffer.writeln('工具执行结果:\n');

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      buffer.writeln('步骤 ${i + 1}: ${step.title}');
      if (step.result != null) {
        buffer.writeln('结果: ${step.result}');
      } else if (step.error != null) {
        buffer.writeln('错误: ${step.error}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// 保存工具模板执行的详细数据
  Future<void> _saveToolTemplateDetail({
    required String messageId,
    required ChatMessage aiMessage,
    required SavedToolTemplate template,
    required List<ToolCallStep> steps,
    required String resultSummary,
    String? userInput,
  }) async {
    try {
      // 查找对应的用户消息（往前查找最近的用户消息）
      final allMessages = context.messageService.currentMessages;
      final aiIndex = allMessages.indexWhere((m) => m.id == messageId);

      String userPrompt = userInput ?? '';
      if (userPrompt.isEmpty && aiIndex > 0) {
        // 从 AI 消息往前查找最近的用户消息
        for (int i = aiIndex - 1; i >= 0; i--) {
          if (allMessages[i].isUser && allMessages[i].parentId == null) {
            userPrompt = allMessages[i].content;
            break;
          }
        }
      }

      // 构建思考过程（说明工具模板的选择和执行）
      final thinkingProcess = '''
# 工具模板执行

**模板名称**: ${template.name}
${template.description != null && template.description!.isNotEmpty ? '**模板描述**: ${template.description}\n' : ''}
**执行步骤数**: ${steps.length}

## 执行策略

基于用户输入「$userPrompt」，选择执行工具模板「${template.name}」。

## 步骤详情

${steps.asMap().entries.map((entry) {
        final idx = entry.key + 1;
        final step = entry.value;
        return '''
### 步骤 $idx: ${step.title}
- **方法**: ${step.method}
- **描述**: ${step.desc}
- **状态**: ${step.status.name}
${step.result != null ? '- **结果**: ${step.result}\n' : ''}${step.error != null ? '- **错误**: ${step.error}\n' : ''}
''';
      }).join('\n')}
''';

      // 构建 AI 输入上下文（简化版）
      final fullAIInput = '''
# 工具模板执行上下文

**用户请求**: $userPrompt
**选择的模板**: ${template.name}
**执行时间**: ${DateTime.now().toIso8601String()}
''';

      // 保存详细数据
      await context.messageDetailService.saveDetail(
        messageId: messageId,
        conversationId: context.conversationId,
        userPrompt: userPrompt,
        fullAIInput: fullAIInput,
        thinkingProcess: thinkingProcess,
        toolCallData: aiMessage.toolCall?.toJson(),
        finalReply: resultSummary,
      );

      debugPrint('💾 工具模板详细数据已保存: ${messageId.substring(0, 8)}');
    } catch (e) {
      debugPrint('❌ 保存工具模板详细数据失败: $e');
    }
  }
}
