import 'dart:convert';

import 'package:aboutme/core/js_bridge/js_bridge_manager.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:aboutme/plugins/webview/services/js_tool_service.dart';

/// 工具 JS 执行器
///
/// 负责 JS 代码、JS 工具调用和工具步骤的执行
class ToolJsExecutor {
  /// 执行 JS 代码
  static Future<String> executeJsCode(String jsCode) async {
    try {
      // 检查是否是 JS 工具调用（格式：js_tool:<toolId>:<paramsJson>）
      if (jsCode.startsWith('js_tool:')) {
        return await _executeJsTool(jsCode);
      }

      final jsBridge = JSBridgeManager.instance;

      // 执行 JS 代码（生图等工具内部轮询可达数分钟，与脚本执行器同样放宽到 5 分钟）
      final result = await jsBridge.evaluate(
        jsCode,
        timeout: const Duration(minutes: 5),
      );

      if (!result.success) {
        throw Exception(result.error ?? '执行失败');
      }

      // 确保返回值是字符串
      final resultValue = result.result;
      if (resultValue == null) {
        return 'null';
      } else if (resultValue is String) {
        return resultValue;
      } else {
        // 如果是对象或数组，转为 JSON 字符串
        return json.encode(resultValue);
      }
    } catch (e) {
      print('[ToolService] JS 执行失败: $e');
      rethrow;
    }
  }

  /// 执行 JS 工具
  static Future<String> _executeJsTool(String jsCode) async {
    try {
      // 解析工具调用格式：js_tool:<toolId>:<paramsJson>
      final parts = jsCode.split(':');
      if (parts.length < 3) {
        throw Exception('无效的 JS 工具调用格式: $jsCode');
      }

      final toolId = parts[1];
      final paramsJson = parts.sublist(2).join(':'); // 重新组装剩余部分（防止 JSON 中包含冒号）
      final params = paramsJson.isNotEmpty ? json.decode(paramsJson) : {};

      // 通过 JSToolService 执行工具
      final jsToolService = JSToolService();
      final result = await jsToolService.executeTool(toolId, params);

      if (!result['success']) {
        throw Exception(result['error'] ?? '工具执行失败');
      }

      // 返回结果
      return json.encode(result['data'] ?? {});
    } catch (e) {
      print('[ToolService] JS 工具执行失败: $e');
      print('[ToolService] 调用代码: $jsCode');
      rethrow;
    }
  }

  /// 执行单个工具步骤
  static Future<String> executeToolStep(ToolCallStep step) async {
    switch (step.method) {
      case 'plugin_tool':
        final call = jsonDecode(step.data) as Map<String, dynamic>;
        final result = await JSBridgeManager.instance.pluginTools.invoke(
          call['pluginId'] as String,
          call['method'] as String,
          Map<String, dynamic>.from(call['args'] as Map),
        );
        return result is String ? result : jsonEncode(result);
      case 'run_js':
        return await executeJsCode(step.data);
      default:
        throw Exception('不支持的方法类型: ${step.method}');
    }
  }
}
