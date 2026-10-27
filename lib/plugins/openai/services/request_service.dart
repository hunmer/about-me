import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:agentlib/openai_compat.dart';
import 'package:agentlib/agentlib.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/models/api_format.dart';
import 'prompt_preset_service.dart';
import 'anthropic_request_service.dart';
import 'thinking_config.dart';
import 'dart:developer' as developer;

/// 统一的错误消息提取和修复方法
///
/// 从异常对象中提取错误消息，并修复可能的UTF-8编码问题
/// 提取 AgentLib 请求错误消息。
String _extractErrorMessage(dynamic error) {
  String errorDetails = error.toString();

  if (error is AgentLibException) {
    try {
      final body = error.body;
      if (body != null && body is Map) {
        final errorObj = body['error'];
        if (errorObj != null && errorObj is Map) {
          final message = errorObj['message'];
          if (message != null && message is String) {
            // 修复可能的UTF-8编码问题
            final fixedMessage = _fixUTF8Encoding(message);
            final code = errorObj['code'];
            errorDetails = code != null
                ? '错误码 $code: $fixedMessage'
                : fixedMessage;
          }
        }
      }
    } catch (parseError) {
      // 如果解析失败，使用原始错误消息
      developer.log('解析错误消息失败', name: 'RequestService', error: parseError);
    }
  }

  return errorDetails;
}

/// 修复UTF-8编码的字符串
///
/// 尝试将错误编码的字符串（如Latin1/GBK误编码为UTF-8）转换为正确的UTF-8字符串
String _fixUTF8Encoding(String message) {
  try {
    // 方案1：尝试将字符串按 Latin1 编码转换为字节，再按 UTF-8 解码
    final bytes1 = latin1.encode(message);
    final decodedMessage1 = utf8.decode(bytes1, allowMalformed: false);
    if (decodedMessage1 != message && decodedMessage1.isNotEmpty) {
      // 检查解码结果是否包含中文或常见字符
      if (_containsValidCharacters(decodedMessage1)) {
        return decodedMessage1;
      }
    }
  } catch (e) {
    // Latin1方案失败，继续尝试其他方案
  }

  try {
    // 方案2：尝试将字符串按 UTF-8 编码重新解释为字节，再按 GBK 解码
    // 这适用于GBK/GB2312编码被误当作UTF-8的情况
    final bytes2 = utf8.encode(message);
    // 尝试将字节当作 GBK 编码处理（使用latin1作为近似）
    // 注意：Dart标准库不直接支持GBK，这里使用一个近似方法
    final gbkApprox = latin1.decode(bytes2);
    if (gbkApprox != message && gbkApprox.isNotEmpty) {
      // 检查解码结果是否包含中文或常见字符
      if (_containsValidCharacters(gbkApprox)) {
        return gbkApprox;
      }
    }
  } catch (e) {
    // GBK方案失败
  }

  // 如果所有方案都失败，返回原始消息
  return message;
}

/// 检查字符串是否包含有效的字符（中文、英文字母、数字等）
bool _containsValidCharacters(String text) {
  // 如果包含常见的中文字符，说明解码成功
  if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) {
    return true;
  }
  // 如果包含常见的英文字母和数字，且不是乱码符号
  if (RegExp(r'[a-zA-Z0-9]').hasMatch(text) &&
      !text.contains('�') &&
      text.length > 3) {
    return true;
  }
  return false;
}

/// 格式化消息列表用于日志输出
String _formatMessagesForLog(List<ChatCompletionMessage> messages) {
  final buffer = StringBuffer();
  for (int i = 0; i < messages.length; i++) {
    final msg = messages[i];
    final role = msg.role.name;
    String content;

    // 提取消息内容
    final rawContent = msg.content;
    if (rawContent is String) {
      content = rawContent;
    } else if (rawContent is ChatCompletionUserMessageContent) {
      // 处理 user 消息的特殊类型
      content = rawContent.map(
        parts: (parts) => parts.value
            .map(
              (p) => p.map(
                text: (t) => t.text,
                image: (i) => '[图片]',
                audio: (a) => '[音频]',
                refusal: (r) => '[拒绝]',
              ),
            )
            .join(' '),
        string: (s) => s.value,
      );
    } else {
      content = rawContent?.toString() ?? '';
    }

    // 截断过长内容
    final truncated = content.length > 200
        ? '${content.substring(0, 200)}... (${content.length}字符)'
        : content;
    buffer.writeln('  [$i] $role: $truncated');
  }
  return buffer.toString();
}

class RequestService {
  static Map<String, dynamic>? _thinkingBody(AIAgent agent) {
    return ThinkingConfig.openAI(agent);
  }

  static AgentLibClient _agentLibClient(AIAgent agent) {
    final apiKey =
        agent.headers['Authorization']?.replaceAll('Bearer ', '') ??
        agent.headers['api-key'] ??
        '';
    final headers = Map<String, String>.from(agent.headers);
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
      headers['api-key'] = apiKey;
    }
    return AgentLibClient(baseUrl: agent.baseUrl, headers: headers);
  }

  static Map<String, dynamic> _agentLibMessage(ChatCompletionMessage message) {
    final content = message.content;
    dynamic normalized = content;
    if (content is ChatCompletionUserMessageContent) {
      normalized = content.map(
        parts: (parts) => parts.value
            .map(
              (part) => part.map(
                text: (text) => <String, dynamic>{
                  'type': 'text',
                  'text': text.text,
                },
                image: (image) => <String, dynamic>{
                  'type': 'image_url',
                  'image_url': {'url': image.imageUrl.url},
                },
                audio: (_) => <String, dynamic>{
                  'type': 'text',
                  'text': '[audio]',
                },
                refusal: (_) => <String, dynamic>{
                  'type': 'text',
                  'text': '[refusal]',
                },
              ),
            )
            .toList(),
        string: (string) => string.value,
      );
    }
    return {'role': message.role.name, 'content': normalized};
  }

  /// 获取有效的系统提示词
  /// 如果 agent 设置了 promptPresetId，则返回预设的内容
  /// 否则返回 agent 的 effectiveSystemPrompt（从 messages 中获取 system 类型的消息）
  static Future<String> getEffectiveSystemPrompt(AIAgent agent) async {
    developer.log(
      '检查 Agent ${agent.name} 的 Prompt 预设: promptPresetId=${agent.promptPresetId}',
      name: 'RequestService',
    );

    if (agent.promptPresetId != null && agent.promptPresetId!.isNotEmpty) {
      developer.log(
        '正在获取预设 Prompt: ${agent.promptPresetId}',
        name: 'RequestService',
      );
      final presetContent = await PromptPresetService().getPresetContent(
        agent.promptPresetId,
      );
      if (presetContent != null && presetContent.isNotEmpty) {
        developer.log(
          '✓ 使用预设 Prompt (${agent.promptPresetId}), 长度: ${presetContent.length}字符',
          name: 'RequestService',
        );
        return presetContent;
      } else {
        developer.log(
          '⚠ 预设 ${agent.promptPresetId} 未找到或为空，使用 agent 的 effectiveSystemPrompt',
          name: 'RequestService',
        );
      }
    }
    // 使用 effectiveSystemPrompt，它会从 messages 中获取 system 类型的消息
    final effectivePrompt = agent.effectiveSystemPrompt;
    developer.log(
      '使用 agent 的 effectiveSystemPrompt (长度: ${effectivePrompt.length}字符)',
      name: 'RequestService',
    );
    return effectivePrompt;
  }

  /// 处理思考内容，将 `<think>` 标签转换为Markdown格式
  static String processThinkingContent(String content) {
    // 使用正则表达式匹配 `<think>` 标签内的内容
    final thinkPattern = RegExp(r'<think>(.*?)</think>', dotAll: true);

    // 创建一个StringBuffer来构建最终的内容
    final StringBuffer result = StringBuffer();
    int lastMatchEnd = 0;

    // 查找所有匹配项
    for (final match in thinkPattern.allMatches(content)) {
      // 添加标签之前的内容（不在think标签内的内容）
      result.write(content.substring(lastMatchEnd, match.start));

      // 获取标签内的文本
      String thinkContent = match.group(1) ?? '';

      // 如果内容不为空，则格式化并添加
      if (thinkContent.trim().isNotEmpty) {
        // 分割成行，为每行添加前缀 ">"
        String formattedContent = thinkContent
            .split('\n')
            .map((line) => line.trim().isEmpty ? '>' : '> $line')
            .join('\n');

        // 添加格式化后的内容
        result.write(formattedContent);
      }

      // 更新lastMatchEnd为当前匹配的结束位置
      lastMatchEnd = match.end;
    }

    // 添加最后一个标签之后的内容
    result.write(content.substring(lastMatchEnd));

    return result.toString();
  }

  /// 发送聊天请求
  /// [maxTokens] 覆盖输出上限；默认用 agent.maxLength（与流式路径一致）。
  /// 推理模型（deepseek-flash 等）的 reasoning 单独计 token，需要更大上限。
  static Future<String> chat(
    String input,
    AIAgent agent, {
    File? imageFile,
    List<ChatCompletionMessage>? contextMessages,
    int? maxTokens,
  }) async {
    final effectiveMaxTokens =
        maxTokens ?? (agent.maxLength > 0 ? agent.maxLength : 1000);
    // 根据 apiFormat 分发到不同的实现
    final apiFormat = ApiFormat.fromString(agent.apiFormat);
    developer.log('chat: apiFormat=${apiFormat.value}', name: 'RequestService');

    if (apiFormat == ApiFormat.anthropic) {
      return await _chatAnthropic(
        input,
        agent,
        imageFile: imageFile,
        contextMessages: contextMessages,
      );
    }

    // OpenAI 格式（默认）
    try {
      developer.log('开始聊天请求: ${agent.id}', name: 'RequestService');
      developer.log('用户输入: $input', name: 'RequestService');

      // 获取有效的系统提示词（可能是预设）
      final effectiveSystemPrompt = await getEffectiveSystemPrompt(agent);

      late final CreateChatCompletionRequest request;
      late final List<ChatCompletionMessage> messages;

      if (imageFile != null) {
        // 读取图片文件并转换为base64
        final bytes = await imageFile.readAsBytes();
        final base64Image = base64Encode(bytes);

        messages = [
          ChatCompletionMessage.system(content: effectiveSystemPrompt),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.parts([
              ChatCompletionMessageContentPart.text(text: input),
              ChatCompletionMessageContentPart.image(
                imageUrl: ChatCompletionMessageImageUrl(
                  url: 'data:image/jpeg;base64,$base64Image',
                ),
              ),
            ]),
          ),
        ];
        request = CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId(agent.model),
          messages: messages,
          temperature: agent.temperature,
          maxTokens: 4096,
        );
      } else {
        // 构建消息列表
        messages = [
          ChatCompletionMessage.system(content: effectiveSystemPrompt),
        ];

        // 添加上下文消息（如果有）
        if (contextMessages != null && contextMessages.isNotEmpty) {
          messages.addAll(contextMessages);
        }

        // 添加当前用户消息
        messages.add(
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(input),
          ),
        );

        request = CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId(agent.model),
          messages: messages,
          temperature: agent.temperature,
          maxTokens: effectiveMaxTokens,
        );
      }

      developer.log('发送请求: ${request.model}', name: 'RequestService');
      developer.log(
        '系统提示词长度: ${effectiveSystemPrompt.length}字符',
        name: 'RequestService',
      );

      final stopwatch = Stopwatch()..start();
      final usesReasoning = ThinkingConfig.usesOpenAIReasoning(agent);
      final responseContent = await _agentLibClient(agent).complete(
        model: agent.model,
        messages: messages.map(_agentLibMessage).toList(),
        temperature: usesReasoning ? null : agent.temperature,
        maxTokens: usesReasoning ? null : effectiveMaxTokens,
        extraBody: {
          ...?_thinkingBody(agent),
          if (usesReasoning && effectiveMaxTokens != null)
            'max_completion_tokens': effectiveMaxTokens,
        },
      );
      stopwatch.stop();

      final content = responseContent.isEmpty
          ? 'No response content'
          : responseContent;
      final preview = content.length > 200
          ? '${content.substring(0, 200)}... (${content.length}字符)'
          : content;
      developer.log(
        '收到响应: ${content.length}字符, 耗时: ${stopwatch.elapsedMilliseconds}ms, 预览: $preview',
        name: 'RequestService',
      );

      return content;
    } catch (e) {
      final errorDetails = _extractErrorMessage(e);
      developer.log('聊天请求错误: $errorDetails', name: 'RequestService', error: e);
      return 'Error: $errorDetails';
    }
  }

  /// Anthropic 聊天请求（非流式）
  static Future<String> _chatAnthropic(
    String input,
    AIAgent agent, {
    File? imageFile,
    List<ChatCompletionMessage>? contextMessages,
  }) async {
    try {
      developer.log('开始 Anthropic 聊天请求: ${agent.id}', name: 'RequestService');
      developer.log('用户输入: $input', name: 'RequestService');

      // 获取有效的系统提示词
      final effectiveSystemPrompt = await getEffectiveSystemPrompt(agent);

      // 构建消息列表
      final List<Map<String, dynamic>> messages = [];

      if (contextMessages != null && contextMessages.isNotEmpty) {
        for (final msg in contextMessages) {
          final role = msg.role.name;
          String content = '';

          final rawContent = msg.content;
          if (rawContent is String) {
            content = rawContent;
          } else if (rawContent is ChatCompletionUserMessageContent) {
            content = rawContent.map(
              parts: (parts) => parts.value
                  .map(
                    (p) => p.map(
                      text: (t) => t.text,
                      image: (i) => '[图片]',
                      audio: (a) => '[音频]',
                      refusal: (r) => '',
                    ),
                  )
                  .where((s) => s.isNotEmpty)
                  .join(' '),
              string: (s) => s.value,
            );
          }

          if (content.isNotEmpty && role != 'system') {
            messages.add({'role': role, 'content': content});
          }
        }
      }

      // 添加当前用户消息
      messages.add({'role': 'user', 'content': input});

      // 使用流式 API 收集完整响应
      final StringBuffer fullResponse = StringBuffer();
      String? errorMessage;

      await AnthropicRequestService.streamResponse(
        agent: agent,
        systemPrompt: effectiveSystemPrompt,
        messages: messages,
        filePath: imageFile?.path,
        onToken: (token) {
          fullResponse.write(token);
        },
        onError: (error) {
          errorMessage = error;
        },
        onComplete: () {
          // 流式响应完成
        },
      );

      if (errorMessage != null) {
        return 'Error: $errorMessage';
      }

      final content = fullResponse.toString();
      developer.log(
        '收到 Anthropic 响应: ${content.length}字符',
        name: 'RequestService',
      );

      return content.isNotEmpty ? content : 'No response content';
    } catch (e) {
      final errorMessage = e.toString();
      developer.log(
        'Anthropic 聊天请求错误: $errorMessage',
        name: 'RequestService',
        error: e,
      );
      return 'Error: $errorMessage';
    }
  }

  /// 流式处理AI响应
  ///
  /// [agent] - AI助手配置
  /// [prompt] - 用户输入的提示，如果为null，则从contextMessages中获取
  /// [onToken] - 每接收到一个完整响应时的回调
  /// [onError] - 发生错误时的回调
  /// [onComplete] - 完成时的回调
  /// [vision] - 是否启用vision模式
  /// [filePath] - 图片文件路径（vision模式下使用）
  /// [contextMessages] - 上下文消息列表，包含system消息和历史消息，按时间从旧到新排序
  /// [responseFormat] - 响应格式（用于 Structured Outputs）
  /// [shouldCancel] - 检查是否应该取消的函数
  /// [additionalPrompts] - 额外的 prompt 部分，使用占位符替换（如 {tool_templates}, {tool_brief}）
  /// [onThinking] - 思考内容回调（reasoning_content / Claude thinking block）
  static Future<void> streamResponse({
    required AIAgent agent,
    String? prompt,
    required Function(String) onToken,
    Function(String)? onThinking,
    required Function(String) onError,
    required Function() onComplete,
    bool vision = true,
    String? filePath,
    List<ChatCompletionMessage>? contextMessages,
    ResponseFormat? responseFormat,
    bool Function()? shouldCancel,
    Map<String, String>? additionalPrompts,
  }) async {
    // 根据 apiFormat 分发到不同的实现
    final apiFormat = ApiFormat.fromString(agent.apiFormat);
    developer.log(
      'streamResponse: apiFormat=${apiFormat.value}',
      name: 'RequestService',
    );

    if (apiFormat == ApiFormat.anthropic) {
      await _streamResponseAnthropic(
        agent: agent,
        prompt: prompt,
        onToken: onToken,
        onThinking: onThinking,
        onError: onError,
        onComplete: onComplete,
        filePath: filePath,
        contextMessages: contextMessages,
        shouldCancel: shouldCancel,
        additionalPrompts: additionalPrompts,
      );
      return;
    }

    // OpenAI 格式（默认）
    try {
      // 获取有效的系统提示词（可能是预设）
      var effectiveSystemPrompt = await getEffectiveSystemPrompt(agent);

      // 处理占位符替换
      if (additionalPrompts != null && additionalPrompts.isNotEmpty) {
        // 保存原始的 agent prompt
        final originalAgentPrompt = effectiveSystemPrompt;

        // 如果 effectiveSystemPrompt 中没有任何占位符，使用默认模板
        if (!effectiveSystemPrompt.contains('{agent_prompt}') &&
            !effectiveSystemPrompt.contains('{tool_templates}') &&
            !effectiveSystemPrompt.contains('{tool_brief}') &&
            !effectiveSystemPrompt.contains('{tool_detail}')) {
          // 构建默认模板：原始prompt + 工具相关占位符
          effectiveSystemPrompt =
              '{agent_prompt}\n{tool_templates}{tool_brief}{tool_detail}';
        }

        // 替换 {agent_prompt} 占位符为原始 agent prompt
        effectiveSystemPrompt = effectiveSystemPrompt.replaceAll(
          '{agent_prompt}',
          originalAgentPrompt,
        );

        // 替换 additionalPrompts 中提供的占位符
        additionalPrompts.forEach((placeholder, content) {
          final fullPlaceholder = '{$placeholder}';
          if (content.isNotEmpty) {
            effectiveSystemPrompt = effectiveSystemPrompt.replaceAll(
              fullPlaceholder,
              content,
            );
            developer.log(
              '替换占位符 $fullPlaceholder (长度: ${content.length})',
              name: 'RequestService',
            );
          } else {
            // 如果内容为空，移除占位符
            effectiveSystemPrompt = effectiveSystemPrompt.replaceAll(
              fullPlaceholder,
              '',
            );
            developer.log(
              '替换占位符 $fullPlaceholder (内容为空)',
              name: 'RequestService',
            );
          }
        });

        // 定义所有标准工具占位符
        final standardToolPlaceholders = [
          'tool_templates',
          'tool_brief',
          'tool_detail',
        ];

        // 替换所有未在 additionalPrompts 中提供的标准占位符为空字符串
        for (final placeholder in standardToolPlaceholders) {
          if (!additionalPrompts.containsKey(placeholder)) {
            final fullPlaceholder = '{$placeholder}';
            if (effectiveSystemPrompt.contains(fullPlaceholder)) {
              effectiveSystemPrompt = effectiveSystemPrompt.replaceAll(
                fullPlaceholder,
                '',
              );
              developer.log(
                '替换未提供的标准占位符 $fullPlaceholder 为空字符串',
                name: 'RequestService',
              );
            }
          }
        }

        developer.log(
          '应用占位符后的 systemPrompt 长度: ${effectiveSystemPrompt.length}',
          name: 'RequestService',
        );
      }

      // 构建消息列表
      List<ChatCompletionMessage> messages = [];
      if (contextMessages != null && contextMessages.isNotEmpty) {
        messages = List<ChatCompletionMessage>.from(contextMessages);

        // 替换 contextMessages 中的 system 消息为处理后的系统提示词
        bool hasSystemMessage = false;
        for (int i = 0; i < messages.length; i++) {
          if (messages[i].role == ChatCompletionMessageRole.system) {
            messages[i] = ChatCompletionMessage.system(
              content: effectiveSystemPrompt,
            );
            hasSystemMessage = true;
            developer.log(
              '替换 contextMessages 中的 system 消息（已应用占位符）',
              name: 'RequestService',
            );
            break;
          }
        }

        // 如果没有 system 消息，在开头插入
        if (!hasSystemMessage) {
          messages.insert(
            0,
            ChatCompletionMessage.system(content: effectiveSystemPrompt),
          );
          developer.log(
            '在 contextMessages 开头插入 system 消息（已应用占位符）',
            name: 'RequestService',
          );
        }
      } else if (prompt != null) {
        // 如果没有提供contextMessages但有prompt，则创建基本的消息列表
        messages = [
          ChatCompletionMessage.system(content: effectiveSystemPrompt),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(prompt),
          ),
        ];
      } else {
        // 如果既没有contextMessages也没有prompt，则报错
        onError('错误：未提供消息内容');
        return;
      }

      // Vision模式处理
      if (vision && filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          // 读取图片文件并转换为base64
          final bytes = await file.readAsBytes();
          final base64Image = base64Encode(bytes);

          // 找到最后一个用户消息并添加图片
          for (int i = messages.length - 1; i >= 0; i--) {
            if (messages[i].role == ChatCompletionMessageRole.user) {
              final userMessage = messages[i];
              final content = userMessage.content;

              // 获取现有的文本内容
              String? textContent;
              if (content is String) {
                textContent = content;
              } else if (content is ChatCompletionUserMessageContent) {
                // 处理 ChatCompletionUserMessageContent 类型
                textContent = content.map(
                  parts: (parts) => parts.value
                      .map(
                        (p) => p.map(
                          text: (t) => t.text,
                          image: (i) => '', // 跳过已有的图片
                          audio: (a) => '',
                          refusal: (r) => '',
                        ),
                      )
                      .where((s) => s.isNotEmpty)
                      .join(' '),
                  string: (s) => s.value,
                );
              }

              // 创建新的消息，包含文本（如果有）和图片
              messages[i] = ChatCompletionMessage.user(
                content: ChatCompletionUserMessageContent.parts([
                  if (textContent != null && textContent.isNotEmpty)
                    ChatCompletionMessageContentPart.text(text: textContent),
                  ChatCompletionMessageContentPart.image(
                    imageUrl: ChatCompletionMessageImageUrl(
                      url: 'data:image/jpeg;base64,$base64Image',
                    ),
                  ),
                ]),
              );
              break;
            }
          }
        } else {
          onError('图片文件不存在: $filePath');
          return;
        }
      }

      // 获取OpenAI客户端
      final request = CreateChatCompletionRequest(
        model: ChatCompletionModel.modelId(agent.model),
        messages: messages,
        temperature: agent.temperature,
        responseFormat: responseFormat,
      );

      developer.log('发送流式请求: ${request.model}', name: 'RequestService');
      developer.log(
        '发送消息列表 (${messages.length}条):\n${_formatMessagesForLog(messages)}',
        name: 'RequestService',
      );

      final stopwatch = Stopwatch()..start();
      int thinkingChars = 0;
      final usesReasoning = ThinkingConfig.usesOpenAIReasoning(agent);
      final stream = _agentLibClient(agent).stream(
        model: agent.model,
        messages: messages.map(_agentLibMessage).toList(),
        temperature: usesReasoning ? null : agent.temperature,
        maxTokens: !usesReasoning && agent.maxLength > 0
            ? agent.maxLength
            : null,
        responseFormat: responseFormat?.toJson(),
        extraBody: {
          ...?_thinkingBody(agent),
          if (usesReasoning && agent.maxLength > 0)
            'max_completion_tokens': agent.maxLength,
        },
        onThinking: (thinking) {
          if (shouldCancel?.call() == true) return;
          thinkingChars += thinking.length;
          if (thinkingChars == thinking.length) {
            developer.log(
              '收到 reasoning_content: ${thinking.length}字符',
              name: 'RequestService',
            );
          }
          onThinking?.call(thinking);
        },
      );

      int totalChars = 0;
      int chunkCount = 0;
      String finalResponse = '';
      bool wasCancelled = false;

      // 使用 StreamSubscription 以便能够主动取消
      StreamSubscription? subscription;
      Timer? cancelCheckTimer;

      final completer = Completer<void>();

      // 定期检查是否需要取消（每100ms检查一次）
      if (shouldCancel != null) {
        cancelCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (
          timer,
        ) {
          if (shouldCancel() && !wasCancelled) {
            developer.log('🛑 定时检查发现取消请求', name: 'RequestService');
            wasCancelled = true;
            timer.cancel();
            subscription?.cancel();
            onError('已取消发送');
            if (!completer.isCompleted) {
              completer.complete();
            }
          }
        });
      }

      subscription = stream.listen(
        (res) {
          // 检查是否应该取消（双重保险）
          if (shouldCancel != null && shouldCancel() && !wasCancelled) {
            developer.log('🛑 流数据处理中检测到取消请求', name: 'RequestService');
            wasCancelled = true;
            cancelCheckTimer?.cancel();
            subscription?.cancel();
            onError('已取消发送');
            if (!completer.isCompleted) {
              completer.complete();
            }
            return;
          }

          final content = res;
          if (content.isNotEmpty) {
            totalChars += content.length;
            chunkCount++;
            finalResponse += content;

            // 每10个块记录一次进度
            if (chunkCount % 10 == 0) {
              developer.log(
                '流式响应进度: $totalChars字符, $chunkCount个块, 已耗时: ${stopwatch.elapsedMilliseconds}ms',
                name: 'RequestService',
              );
            }

            onToken(content);
          }
        },
        onError: (error) {
          cancelCheckTimer?.cancel();
          if (!wasCancelled) {
            final errorDetails = _extractErrorMessage(error);
            developer.log(
              '流式响应错误: $errorDetails',
              name: 'RequestService',
              error: error,
            );
            onError('处理AI响应时出错: $errorDetails');
          }
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onDone: () {
          cancelCheckTimer?.cancel();
          if (!wasCancelled) {
            stopwatch.stop();
            developer.log('返回文本完成: $finalResponse', name: 'RequestService');
            developer.log(
              '流式响应完成: thinking=$thinkingChars, output=$totalChars, $chunkCount个正文块, 总耗时: ${stopwatch.elapsedMilliseconds}ms',
              name: 'RequestService',
            );
            onComplete();
          }
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        cancelOnError: true,
      );

      // 等待流处理完成
      await completer.future;

      // 确保资源被清理
      cancelCheckTimer?.cancel();
      final cancellation = subscription.cancel();
      if (wasCancelled) {
        // async* 传输可能仍在等待下一帧；取消终态不能等待服务端继续输出。
        unawaited(
          cancellation.catchError((Object error, StackTrace stack) {
            developer.log(
              '取消流清理失败',
              name: 'RequestService',
              error: error,
              stackTrace: stack,
            );
          }),
        );
      } else {
        await cancellation;
      }
    } catch (e, stackTrace) {
      final errorDetails = _extractErrorMessage(e);
      final errorMessage = '处理AI响应时出错: $errorDetails';
      developer.log(
        errorMessage,
        name: 'RequestService',
        error: e,
        stackTrace: stackTrace,
      );
      onError(errorMessage);
    }
  }

  /// 流式处理AI响应（带重试机制）
  ///
  /// 最多重试 10 次，每次失败后等待 1 秒再重试
  ///
  /// [agent] - AI助手配置
  /// [prompt] - 用户输入的提示，如果为null，则从contextMessages中获取
  /// [onToken] - 每接收到一个完整响应时的回调
  /// [onError] - 发生错误时的回调（仅在所有重试都失败后调用）
  /// [onComplete] - 完成时的回调
  /// [vision] - 是否启用vision模式
  /// [filePath] - 图片文件路径（vision模式下使用）
  /// [contextMessages] - 上下文消息列表，包含system消息和历史消息，按时间从旧到新排序
  /// [responseFormat] - 响应格式（用于 Structured Outputs）
  /// [shouldCancel] - 检查是否应该取消的函数
  /// [additionalPrompts] - 额外的 prompt 部分，使用占位符替换（如 {tool_templates}, {tool_brief}）
  /// [onThinking] - 思考内容回调（Claude thinking block）
  /// [maxRetries] - 最大重试次数，默认为 10
  /// [retryDelay] - 每次重试之间的延迟（毫秒），默认为 1000ms
  static Future<void> streamResponseWithRetry({
    required AIAgent agent,
    String? prompt,
    required Function(String) onToken,
    Function(String)? onThinking,
    required Function(String) onError,
    required Function() onComplete,
    bool vision = true,
    String? filePath,
    List<ChatCompletionMessage>? contextMessages,
    ResponseFormat? responseFormat,
    bool Function()? shouldCancel,
    Map<String, String>? additionalPrompts,
    int maxRetries = 10,
    int retryDelay = 1000,
  }) async {
    int attempt = 0;
    String? lastError;
    var terminalNotified = false;

    void finishError(String error) {
      if (terminalNotified) return;
      terminalNotified = true;
      onError(error);
    }

    bool cancelIfNeeded([String? error]) {
      if (shouldCancel?.call() != true && error != '已取消发送') return false;
      finishError('已取消发送');
      return true;
    }

    while (attempt < maxRetries) {
      if (cancelIfNeeded()) return;
      attempt++;
      if (attempt > 1) {
        await Future<void>.delayed(Duration(milliseconds: retryDelay));
        if (cancelIfNeeded()) return;
      }

      bool succeeded = false;
      int totalChars = 0;
      String? currentError;
      try {
        await streamResponse(
          agent: agent,
          prompt: prompt,
          onToken: (token) {
            if (currentError != null || succeeded || terminalNotified) return;
            totalChars += token.length;
            onToken(token);
          },
          onThinking: onThinking,
          onError: (error) {
            if (!succeeded) currentError ??= error;
          },
          onComplete: () {
            if (currentError != null || succeeded) return;
            if (totalChars == 0) {
              currentError = 'AI响应为空（0字符）';
              return;
            }
            succeeded = true;
          },
          vision: vision,
          filePath: filePath,
          contextMessages: contextMessages,
          responseFormat: responseFormat,
          shouldCancel: shouldCancel,
          additionalPrompts: additionalPrompts,
        );
      } catch (e, stackTrace) {
        currentError ??= '处理AI响应时出错: ${_extractErrorMessage(e)}';
        developer.log(
          '第 $attempt 次尝试异常',
          name: 'RequestService',
          error: e,
          stackTrace: stackTrace,
        );
      }

      // 无论取消发生在请求前、流内或重试间隔，都必须通知一次终态。
      if (cancelIfNeeded(currentError)) return;
      if (succeeded && currentError == null) {
        if (!terminalNotified) {
          terminalNotified = true;
          onComplete();
        }
        return;
      }
      lastError = currentError ?? 'AI响应未正常结束';
    }
    finishError(lastError ?? '未知错误');
  }

  /// 生成图片
  static Future<List<String>> generateImages(
    String prompt,
    AIAgent agent, {
    int n = 1,
    String size = '1024x1024',
    String model = 'dall-e-3',
    String quality = 'standard',
    String style = 'natural',
  }) async {
    try {
      developer.log('开始图像生成请求: ${agent.id}', name: 'RequestService');
      developer.log('提示词: $prompt', name: 'RequestService');
      developer.log(
        '参数: model=$model, size=$size, quality=$quality, style=$style, n=$n',
        name: 'RequestService',
      );

      final stopwatch = Stopwatch()..start();
      final response = await _agentLibClient(agent).requestJson(
        'images/generations',
        body: {
          'model': model,
          'prompt': prompt,
          'n': n,
          'size': size,
          'quality': quality,
          'style': style,
        },
      );
      stopwatch.stop();

      final urls = (response['data'] as List<dynamic>? ?? const [])
          .map(
            (image) => (image as Map<String, dynamic>)['url'] as String? ?? '',
          )
          .toList();
      developer.log(
        '图像生成完成: ${urls.length}张图片, 耗时: ${stopwatch.elapsedMilliseconds}ms',
        name: 'RequestService',
      );

      return urls;
    } catch (e) {
      final errorDetails = _extractErrorMessage(e);
      developer.log('图像生成错误: $errorDetails', name: 'RequestService', error: e);
      return ['Error: $errorDetails'];
    }
  }

  /// 创建嵌入向量
  static Future<List<double>> createEmbedding(
    String input,
    AIAgent agent, {
    String model = 'text-embedding-3-small',
  }) async {
    try {
      developer.log('开始创建嵌入向量: ${agent.id}', name: 'RequestService');
      developer.log('输入文本长度: ${input.length}字符', name: 'RequestService');
      developer.log('使用模型: $model', name: 'RequestService');

      final stopwatch = Stopwatch()..start();
      final response = await _agentLibClient(
        agent,
      ).requestJson('embeddings', body: {'model': model, 'input': input});
      stopwatch.stop();

      final vector =
          ((response['data'] as List<dynamic>).first
                  as Map<String, dynamic>)['embedding']
              as List<dynamic>;
      developer.log(
        '嵌入向量生成完成: ${vector.length}维, 耗时: ${stopwatch.elapsedMilliseconds}ms',
        name: 'RequestService',
      );

      return vector.map((value) => (value as num).toDouble()).toList();
    } catch (e) {
      final errorDetails = _extractErrorMessage(e);
      developer.log(
        '嵌入向量生成错误: $errorDetails',
        name: 'RequestService',
        error: e,
      );
      return [];
    }
  }

  /// 清理客户端资源
  static void dispose() {
    AnthropicRequestService.dispose();
  }

  /// Anthropic API 流式响应处理
  ///
  /// 将 OpenAI 格式的消息转换为 Anthropic 格式并调用 AnthropicRequestService
  static Future<void> _streamResponseAnthropic({
    required AIAgent agent,
    String? prompt,
    required Function(String) onToken,
    Function(String)? onThinking,
    required Function(String) onError,
    required Function() onComplete,
    String? filePath,
    List<ChatCompletionMessage>? contextMessages,
    bool Function()? shouldCancel,
    Map<String, String>? additionalPrompts,
  }) async {
    try {
      // 获取有效的系统提示词（可能是预设）
      var effectiveSystemPrompt = await getEffectiveSystemPrompt(agent);

      // 处理占位符替换（与 OpenAI 版本相同）
      if (additionalPrompts != null && additionalPrompts.isNotEmpty) {
        final originalAgentPrompt = effectiveSystemPrompt;

        if (!effectiveSystemPrompt.contains('{agent_prompt}') &&
            !effectiveSystemPrompt.contains('{tool_templates}') &&
            !effectiveSystemPrompt.contains('{tool_brief}') &&
            !effectiveSystemPrompt.contains('{tool_detail}')) {
          effectiveSystemPrompt =
              '{agent_prompt}\n{tool_templates}{tool_brief}{tool_detail}';
        }

        effectiveSystemPrompt = effectiveSystemPrompt.replaceAll(
          '{agent_prompt}',
          originalAgentPrompt,
        );

        additionalPrompts.forEach((placeholder, content) {
          final fullPlaceholder = '{$placeholder}';
          if (content.isNotEmpty) {
            effectiveSystemPrompt = effectiveSystemPrompt.replaceAll(
              fullPlaceholder,
              content,
            );
          } else {
            effectiveSystemPrompt = effectiveSystemPrompt.replaceAll(
              fullPlaceholder,
              '',
            );
          }
        });

        final standardToolPlaceholders = [
          'tool_templates',
          'tool_brief',
          'tool_detail',
        ];

        for (final placeholder in standardToolPlaceholders) {
          if (!additionalPrompts.containsKey(placeholder)) {
            final fullPlaceholder = '{$placeholder}';
            if (effectiveSystemPrompt.contains(fullPlaceholder)) {
              effectiveSystemPrompt = effectiveSystemPrompt.replaceAll(
                fullPlaceholder,
                '',
              );
            }
          }
        }
      }

      // 将 OpenAI 格式的消息转换为通用格式
      final List<Map<String, dynamic>> messages = [];

      if (contextMessages != null && contextMessages.isNotEmpty) {
        for (final msg in contextMessages) {
          final role = msg.role.name;
          String content = '';

          // 提取消息内容
          final rawContent = msg.content;
          if (rawContent is String) {
            content = rawContent;
          } else if (rawContent is ChatCompletionUserMessageContent) {
            content = rawContent.map(
              parts: (parts) => parts.value
                  .map(
                    (p) => p.map(
                      text: (t) => t.text,
                      image: (i) => '[图片]',
                      audio: (a) => '[音频]',
                      refusal: (r) => '',
                    ),
                  )
                  .where((s) => s.isNotEmpty)
                  .join(' '),
              string: (s) => s.value,
            );
          }

          if (content.isNotEmpty) {
            messages.add({'role': role, 'content': content});
          }
        }
      } else if (prompt != null) {
        messages.add({'role': 'user', 'content': prompt});
      } else {
        onError('错误：未提供消息内容');
        return;
      }

      developer.log(
        '发送 Anthropic 流式请求: ${agent.model}',
        name: 'RequestService',
      );
      developer.log(
        '系统提示词长度: ${effectiveSystemPrompt.length}字符',
        name: 'RequestService',
      );
      developer.log('消息数量: ${messages.length}条', name: 'RequestService');

      // 调用 AnthropicRequestService
      await AnthropicRequestService.streamResponse(
        agent: agent,
        systemPrompt: effectiveSystemPrompt,
        messages: messages,
        onToken: onToken,
        onThinking: onThinking,
        onError: onError,
        onComplete: onComplete,
        filePath: filePath,
        shouldCancel: shouldCancel,
      );
    } catch (e, stackTrace) {
      final errorMessage = '处理 Anthropic 响应时出错: $e';
      developer.log(
        errorMessage,
        name: 'RequestService',
        error: e,
        stackTrace: stackTrace,
      );
      onError(errorMessage);
    }
  }
}
