import 'dart:convert';

/// AI 响应 JSON 解析器
///
/// 负责从 AI 返回的自由文本中提取、修复和解析 JSON 内容
class ToolResponseJsonParser {
  /// 从AI响应中提取JSON字符串（通用方法）
  ///
  /// 支持以下格式：
  /// 1. ```json {...}``` 代码块
  /// 2. 直接的JSON对象（需要提供必填字段名用于匹配）
  /// 3. 整个响应就是JSON（作为最后尝试）
  ///
  /// 参数：
  /// - [response]: AI的完整响应
  /// - [requiredField]: 用于匹配直接JSON的必填字段名（如 "use_tool_temps", "strategy", "steps"）
  ///
  /// 返回提取的JSON字符串，如果提取失败返回null
  static String? extractJsonFromResponse(
    String response, {
    String? requiredField,
  }) {
    // 1. 尝试从 ```json ... ``` 代码块中提取（支持缩进和多行）
    // 修复：匹配整个代码块内容，然后使用 _extractCompleteJsonObject 提取完整JSON
    final jsonBlockMatch = RegExp(
      r'```json[\s\S]*?```',
      multiLine: true,
    ).firstMatch(response);

    if (jsonBlockMatch != null) {
      // 提取代码块内的内容（去掉 ```json 和 ```）
      final blockContent = jsonBlockMatch.group(0)!;
      final jsonStart = blockContent.indexOf('{');
      final jsonEnd = blockContent.lastIndexOf('}');
      if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
        final jsonText = blockContent.substring(jsonStart, jsonEnd + 1);
        // 使用完整JSON提取方法确保提取完整的对象
        return extractCompleteJsonObject(jsonText);
      }
    }

    // 2. 如果提供了必填字段名，尝试提取直接的JSON对象
    if (requiredField != null) {
      // 构建正则表达式匹配包含必填字段的JSON对象
      final pattern =
          r'\{\s*"' + RegExp.escape(requiredField) + r'\s*:[\s\S]*?\}';
      final directJsonMatch = RegExp(
        pattern,
        multiLine: true,
      ).firstMatch(response);
      if (directJsonMatch != null) {
        return extractCompleteJsonObject(directJsonMatch.group(0)!);
      }
    }

    // 3. 尝试提取第一个JSON对象（通用匹配）
    final genericJsonMatch = RegExp(
      r'\{[\s\S]*?\}',
      multiLine: true,
    ).firstMatch(response);
    if (genericJsonMatch != null) {
      return extractCompleteJsonObject(genericJsonMatch.group(0)!);
    }

    return null;
  }

  /// 从文本中提取完整的JSON对象（处理嵌套括号）
  static String? extractCompleteJsonObject(String text) {
    int braceCount = 0;
    int bracketCount = 0;
    int startIndex = -1;
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      if (escaped) {
        escaped = false;
        continue;
      }

      if (char == '\\') {
        escaped = true;
        continue;
      }

      if (char == '"') {
        inString = !inString;
      }

      if (!inString) {
        if (char == '{') {
          if (braceCount == 0 && bracketCount == 0) {
            startIndex = i;
          }
          braceCount++;
        } else if (char == '}') {
          braceCount--;
          // 只有当大括号和方括号都平衡时，才算完整
          if (braceCount == 0 && bracketCount == 0 && startIndex != -1) {
            return text.substring(startIndex, i + 1);
          }
        } else if (char == '[') {
          bracketCount++;
        } else if (char == ']') {
          bracketCount--;
        }
      }
    }

    return null;
  }

  /// 修复常见的AI返回JSON格式错误
  static String fixInvalidJson(String jsonStr) {
    // 尝试先解析，如果成功则不需要修复
    try {
      jsonDecode(jsonStr);
      return jsonStr;
    } catch (_) {
      // 继续修复
    }

    // 修复模式：
    // 1. 将 JSON 字符串值中的原始换行符转为 \n 转义序列
    // 2. 将单引号包裹的字符串值转为双引号
    final buffer = StringBuffer();
    bool inDoubleQuote = false;
    bool inSingleQuote = false;
    bool escaped = false;

    for (int i = 0; i < jsonStr.length; i++) {
      final char = jsonStr[i];

      if (escaped) {
        // 保留转义序列（原样写入，不做额外处理）
        buffer.write('\\');
        buffer.write(char);
        escaped = false;
        continue;
      }

      if (char == '\\') {
        escaped = true;
        continue;
      }

      if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
        buffer.write(char);
      } else if (char == "'" && !inDoubleQuote) {
        // 单引号转双引号
        inSingleQuote = !inSingleQuote;
        buffer.write('"');
      } else if ((inDoubleQuote || inSingleQuote) && char == '\n') {
        // ⚠️ 关键修复：在字符串值内部，将原始换行符转为 \n 转义序列
        buffer.write('\\n');
      } else if ((inDoubleQuote || inSingleQuote) && char == '\r') {
        // 将回车符转为 \r 转义序列
        buffer.write('\\r');
      } else if ((inDoubleQuote || inSingleQuote) && char == '\t') {
        // 将制表符转为 \t 转义序列
        buffer.write('\\t');
      } else {
        buffer.write(char);
      }
    }

    return buffer.toString();
  }

  /// 通用JSON解析方法（带格式修复）
  ///
  /// 参数：
  /// - [response]: AI的完整响应
  /// - [requiredField]: 用于匹配的必填字段名
  ///
  /// 返回解析后的JSON对象，解析失败返回null
  static Map<String, dynamic>? parseJsonFromResponse(
    String response, {
    String? requiredField,
  }) {
    try {
      // 使用通用JSON提取方法
      final jsonStr = extractJsonFromResponse(
        response,
        requiredField: requiredField,
      );

      if (jsonStr == null) {
        return null;
      }

      // 修复JSON格式错误并解析
      final fixedJsonStr = fixInvalidJson(jsonStr);
      final result = jsonDecode(fixedJsonStr) as Map<String, dynamic>;
      return result;
    } catch (e) {
      final errorPreviewLength = response.length < 200 ? response.length : 200;
      print(
        '[ToolService] 响应内容前$errorPreviewLength字符: ${response.substring(0, errorPreviewLength)}',
      );
      return null;
    }
  }
}
