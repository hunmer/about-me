import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';

/// Markdown 工具调用解析器
///
/// 将 AI 返回的 Markdown 格式工具调用解析为 ToolCallResponse 对象
/// 格式示例：
/// ```markdown
/// # 获取今日任务
/// 查询今天的所有待办任务
/// ```javascript
/// const tasks = await Aboutme.plugins.todo.getTodayTasks();
/// return tasks;
/// ```
/// ```
class MarkdownToolCallParser {
  // 正则表达式模式
  static final _titlePattern = RegExp(r'^#\s+(.+)$');
  static final _descPattern = RegExp(r'^##\s+(.+)$');
  static final _codeBlockStart = RegExp(r'^```(\w*)');
  static final _codeBlockEnd = RegExp(r'^```\s*$');

  /// 解析 Markdown 文本为工具调用响应
  ///
  /// 支持不完整的 Markdown（正在生成中的内容）
  /// 会忽略最后一个未完成闭合的步骤
  static ToolCallResponse? parse(String markdown) {
    // 预处理：移除外层的 ```markdown 包裹和前导空代码块
    String processedMarkdown = markdown;

    // 1. 检测是否被 ```markdown ... ``` 包裹
    final markdownBlockMatch = RegExp(
      r'^```\s*markdown\s*\n([\s\S]*?)\n```$',
      multiLine: true,
    ).firstMatch(markdown.trim());

    if (markdownBlockMatch != null) {
      // 提取内部内容
      processedMarkdown = markdownBlockMatch.group(1) ?? markdown;
      print('[MarkdownToolCallParser] 检测到外层 markdown 代码块包裹，已移除');
    }

    // 2. 移除前导的空代码块（如 ``` \n 或 ```\n\n）
    if (processedMarkdown.startsWith('```')) {
      final firstCodeBlockEnd = processedMarkdown.indexOf('\n', 3);
      if (firstCodeBlockEnd != -1) {
        final afterCodeBlock = processedMarkdown.substring(firstCodeBlockEnd + 1);
        // 检查下一行是否以 # 开头（工具调用标题）
        if (afterCodeBlock.trimLeft().startsWith('#')) {
          processedMarkdown = afterCodeBlock;
          print('[MarkdownToolCallParser] 检测到前导空代码块，已移除');
        }
      }
    }

    // 3. 移除开头的空白行
    processedMarkdown = processedMarkdown.replaceFirst(
      RegExp(r'^\s+\n'),
      '',
    );

    final lines = processedMarkdown.split('\n');
    final steps = <ToolCallStep>[];

    String? currentTitle;
    String? currentDesc;
    String? currentCodeLang;
    StringBuffer? currentCode;
    bool inCodeBlock = false;

    for (final line in lines) {
      // 1. 检测代码块结束
      if (inCodeBlock && _codeBlockEnd.hasMatch(line)) {
        // 只有当有标题和代码时才添加步骤
        if (currentTitle != null && currentCode != null) {
          steps.add(
            ToolCallStep(
              method: _parseMethod(currentCodeLang),
              title: currentTitle,
              desc: currentDesc ?? '',
              data: currentCode.toString().trim(),
            ),
          );
        }

        // 重置状态
        currentTitle = null;
        currentDesc = null;
        currentCodeLang = null;
        currentCode = null;
        inCodeBlock = false;
        continue;
      }

      // 2. 检测代码块开始
      final codeStartMatch = _codeBlockStart.firstMatch(line);
      if (codeStartMatch != null) {
        inCodeBlock = true;
        currentCodeLang = codeStartMatch.group(1)?.trim();
        currentCode = StringBuffer();
        continue;
      }

      // 3. 在代码块中 - 累积代码
      if (inCodeBlock) {
        currentCode?.writeln(line);
        continue;
      }

      // 4. 检测一级标题
      final titleMatch = _titlePattern.firstMatch(line);
      if (titleMatch != null) {
        currentTitle = titleMatch.group(1)!.trim();
        continue;
      }

      // 5. 检测二级标题
      final descMatch = _descPattern.firstMatch(line);
      if (descMatch != null) {
        currentDesc = descMatch.group(1)!.trim();
        continue;
      }
    }

    // 返回结果（不完整的最后一个步骤会被忽略）
    return steps.isEmpty ? null : ToolCallResponse(steps: steps);
  }

  /// 解析方法类型
  ///
  /// 从代码块语言标识解析方法类型
  static String _parseMethod(String? lang) {
    if (lang == null || lang.isEmpty) return 'run_js';

    switch (lang.toLowerCase()) {
      case 'javascript':
      case 'js':
        return 'run_js';
      default:
        return 'run_js'; // 默认方法
    }
  }

  /// 检测内容是否包含 Markdown 工具调用格式
  ///
  /// 通过检测是否包含标题和代码块来判断
  /// 支持检测被 ```markdown 包裹的内容和前导空代码块
  static bool containsMarkdownToolCall(String content) {
    // 预处理：移除外层的 ```markdown 包裹后再检测
    String processedContent = content;

    // 检测是否被 ```markdown ... ``` 包裹
    final markdownBlockMatch = RegExp(
      r'^```\s*markdown\s*\n([\s\S]*?)\n```$',
      multiLine: true,
    ).firstMatch(content.trim());

    if (markdownBlockMatch != null) {
      // 提取内部内容
      processedContent = markdownBlockMatch.group(1) ?? content;
    }

    // 移除前导的空代码块
    if (processedContent.startsWith('```')) {
      final firstCodeBlockEnd = processedContent.indexOf('\n', 3);
      if (firstCodeBlockEnd != -1) {
        final afterCodeBlock = processedContent.substring(firstCodeBlockEnd + 1);
        if (afterCodeBlock.trimLeft().startsWith('#')) {
          processedContent = afterCodeBlock;
        }
      }
    }

    final hasTitle = RegExp(r'^#\s+.+', multiLine: true).hasMatch(processedContent);
    final hasCodeBlock = RegExp(r'```').hasMatch(processedContent);
    return hasTitle && hasCodeBlock;
  }
}
