import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:aboutme/plugins/agent_chat/services/markdown_tool_call_parser.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_js_executor.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_prompt_builder.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_response_json_parser.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_template_match.dart';

import 'native_tool_agent_service.dart';
import 'tool_config_manager.dart';

// 兼容旧引用：这些符号原先定义在本文件，已按功能拆分到独立文件
export 'markdown_tool_call_parser.dart' show MarkdownToolCallParser;
export 'tool_template_match.dart'
    show TemplateStrategy, TemplateMatch, ReplacementRule;

/// 工具服务 - 统一入口，按功能委托到各实现类：
/// - [MarkdownToolCallParser]: Markdown 工具调用解析
/// - [ToolJsExecutor]: JS / 工具步骤执行
/// - [ToolPromptBuilder]: 工具 Prompt 生成
/// - [ToolTemplateMatcher]: 工具模版匹配（第零阶段）
/// - [ToolResponseJsonParser]: AI 响应 JSON 提取与修复
class ToolService {
  static String? _cachedToolListPrompt;
  static String? _cachedToolBriefPrompt;
  static bool _initialized = false;

  /// 第零阶段 JSON Schema - 工具模版匹配
  static const Map<String, dynamic> toolTemplateMatchSchema =
      ToolTemplateMatcher.schema;

  /// 初始化工具服务（加载所有工具配置）
  static Future<void> initialize({StorageManager? storage}) async {
    if (_initialized) return;

    try {
      // 初始化 ToolConfigManager
      await ToolConfigManager.instance.initialize(storage: storage);

      // 生成并缓存两种 Prompt
      _cachedToolBriefPrompt = ToolPromptBuilder.generateToolBriefPrompt();
      _cachedToolListPrompt = await ToolPromptBuilder.generateToolListPrompt();

      _initialized = true;
    } catch (e) {
      print('[ToolService] 初始化失败: $e');
      _cachedToolBriefPrompt = ToolPromptBuilder.fallbackBriefPrompt();
      _cachedToolListPrompt = ToolPromptBuilder.fallbackToolPrompt();
    }
  }

  /// 刷新工具缓存（当有新工具注册时调用）
  ///
  /// 此方法用于在 JS 工具动态注册后更新缓存，确保工具列表保持最新
  static Future<void> refreshCache() async {
    if (!_initialized) {
      print('[ToolService] 警告：工具服务未初始化，跳过刷新');
      return;
    }

    try {
      // 重新生成并缓存两种 Prompt
      _cachedToolBriefPrompt = ToolPromptBuilder.generateToolBriefPrompt();
      _cachedToolListPrompt = await ToolPromptBuilder.generateToolListPrompt();
      // 原生 FC 工具集缓存同步失效
      NativeToolAgentService.instance.invalidateCache();
    } catch (e) {
      print('[ToolService] 刷新缓存失败: $e');
    }
  }

  // ==================== 工具调用解析 ====================

  /// 检查内容是否包含工具调用（Markdown 格式）
  static bool containsToolCall(String content) {
    return MarkdownToolCallParser.containsMarkdownToolCall(content);
  }

  /// 从 AI 回复中解析工具调用（Markdown 格式）
  static ToolCallResponse? parseToolCallFromResponse(String response) {
    try {
      final result = MarkdownToolCallParser.parse(response);
      if (result != null) {
        print('[ToolService] Markdown 解析成功，包含 ${result.steps.length} 个步骤');
        return result;
      }

      print('[ToolService] 未找到工具调用');
      return null;
    } catch (e, stack) {
      print('[ToolService] 解析工具调用失败: $e');
      print(stack);
      return null;
    }
  }

  // ==================== 工具执行 ====================

  /// 执行 JS 代码
  static Future<String> executeJsCode(String jsCode) {
    return ToolJsExecutor.executeJsCode(jsCode);
  }

  /// 执行单个工具步骤
  static Future<String> executeToolStep(ToolCallStep step) {
    return ToolJsExecutor.executeToolStep(step);
  }

  // ==================== 工具文档 Prompt ====================

  /// 获取工具列表 Prompt（用于添加到 system prompt）
  /// @deprecated 使用 getToolBriefPrompt() 和 getToolDetailPrompt() 实现两阶段调用
  static String getToolListPrompt() {
    if (!_initialized) {
      print('[ToolService] 警告：工具服务未初始化，使用后备 Prompt');
      return ToolPromptBuilder.fallbackToolPrompt();
    }
    return _cachedToolListPrompt ?? ToolPromptBuilder.fallbackToolPrompt();
  }

  /// 获取工具简要索引 Prompt
  static String getToolBriefPrompt() {
    if (!_initialized) {
      print('[ToolService] 警告：工具服务未初始化，使用后备简要 Prompt');
      return ToolPromptBuilder.fallbackBriefPrompt();
    }
    return _cachedToolBriefPrompt ?? ToolPromptBuilder.fallbackBriefPrompt();
  }

  /// 获取工具详细文档；模板修改只需要文档，不附加调用输出格式。
  static Future<String> getToolDetailPrompt(
    List<String> toolIds, {
    bool includeCallFormat = true,
  }) {
    return ToolPromptBuilder.buildToolDetailPrompt(
      toolIds,
      includeCallFormat: includeCallFormat,
    );
  }

  // ==================== 工具模版匹配（第零阶段）====================

  /// 生成工具模版列表 Prompt（第零阶段）
  static String getToolTemplatePrompt(List<dynamic> templates) {
    return ToolTemplateMatcher.buildTemplatePrompt(templates);
  }

  /// 解析 AI 返回的工具模版匹配结果
  static List<TemplateMatch>? parseToolTemplateMatch(String response) {
    return ToolTemplateMatcher.parseMatch(response);
  }

  /// 应用参数替换到模版步骤
  static List<ToolCallStep> applyReplacements(
    List<ToolCallStep> steps,
    List<ReplacementRule> replacements,
  ) {
    return ToolTemplateMatcher.applyReplacements(steps, replacements);
  }

  // ==================== 通用 JSON 解析 ====================

  /// 从AI响应中提取JSON字符串（通用方法）
  static String? extractJsonFromResponse(
    String response, {
    String? requiredField,
  }) {
    return ToolResponseJsonParser.extractJsonFromResponse(
      response,
      requiredField: requiredField,
    );
  }

  /// 通用JSON解析方法（带格式修复）
  static Map<String, dynamic>? parseJsonFromResponse(
    String response, {
    String? requiredField,
  }) {
    return ToolResponseJsonParser.parseJsonFromResponse(
      response,
      requiredField: requiredField,
    );
  }
}
