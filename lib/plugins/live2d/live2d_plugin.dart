import 'package:flutter/material.dart';
import 'package:aboutme/plugins/base_plugin.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/config_manager.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';
import 'screens/live2d_main_screen.dart';
import 'screens/live2d_settings_screen.dart';

class Live2DPlugin extends BasePlugin {
  static Live2DPlugin? _instance;
  static Live2DPlugin get instance =>
      _instance ??= PluginManager.instance.getPlugin('live2d') as Live2DPlugin;
  static const fixedGroup = 'live2d';
  static const defaultTypingIntervalMs = 70;
  static const defaultAutoReadEnabled = false;

  Duration get bubbleTypingInterval => Duration(
    milliseconds:
        settings['typingIntervalMs'] as int? ?? defaultTypingIntervalMs,
  );

  bool get autoReadEnabled =>
      settings['autoReadEnabled'] as bool? ?? defaultAutoReadEnabled;

  String? get ttsServiceId => settings['ttsServiceId'] as String?;

  Future<void> speakReply(String reply) async {
    if (!autoReadEnabled || reply.trim().isEmpty) return;
    // 聊天请求失败（❌）或用户取消（🛑）的错误提示不朗读
    if (reply.startsWith('❌') || reply.startsWith('🛑')) return;
    try {
      await TTSPlugin.instance.speak(
        reply,
        serviceId: ttsServiceId,
        onError: (error) => debugPrint('[Live2DChat] TTS failed: $error'),
      );
    } catch (error) {
      debugPrint('[Live2DChat] TTS unavailable: $error');
    }
  }

  /// Live2D 气泡只展示最终回答，隐藏模型返回的思考块。
  static String cleanReply(String value) {
    var result = value.replaceAll(
      RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
      '',
    );
    // 兼容流式响应中尚未闭合的思考标签。
    result = result.replaceFirst(
      RegExp(r'<think>[\s\S]*$', caseSensitive: false),
      '',
    );
    return _sanitizeUtf16(result.trim());
  }

  static String _sanitizeUtf16(String value) {
    final output = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final unit = value.codeUnitAt(i);
      if (unit >= 0xD800 && unit <= 0xDBFF) {
        if (i + 1 < value.length) {
          final next = value.codeUnitAt(i + 1);
          if (next >= 0xDC00 && next <= 0xDFFF) {
            output.writeCharCode(
              0x10000 + ((unit - 0xD800) << 10) + next - 0xDC00,
            );
            i++;
            continue;
          }
        }
        output.write('\uFFFD');
      } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
        output.write('\uFFFD');
      } else {
        output.writeCharCode(unit);
      }
    }
    return output.toString();
  }

  final List<Live2DArchive> archives = [];
  String? selectedId;

  @override
  String get id => 'live2d';
  @override
  Color get color => Colors.pink;
  @override
  IconData get icon => Icons.face_retouching_natural;

  @override
  Future<void> initialize() async {
    await loadSettings({
      'typingIntervalMs': defaultTypingIntervalMs,
      'autoReadEnabled': defaultAutoReadEnabled,
      'ttsServiceId': null,
    });
    final data = await storage.read('$storageDir/archives.json');
    final rawArchives = data is Map ? data['archives'] : null;
    archives
      ..clear()
      ..addAll(
        (rawArchives is List ? rawArchives : const []).map(
          (e) => Live2DArchive.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    selectedId = data['selectedId'] as String?;
  }

  Future<void> save() async => storage.write('$storageDir/archives.json', {
    'selectedId': selectedId,
    'archives': archives.map((a) => a.toJson()).toList(),
  });
  Live2DArchive? get selected =>
      archives.where((a) => a.id == selectedId).firstOrNull;
  Future<void> upsert(Live2DArchive archive) async {
    final i = archives.indexWhere((a) => a.id == archive.id);
    if (i < 0) {
      archives.add(archive);
    } else {
      archives[i] = archive;
    }
    selectedId = archive.id;
    await save();
  }

  Future<void> deleteArchive(String id) async {
    archives.removeWhere((item) => item.id == id);
    if (selectedId == id)
      selectedId = archives.isEmpty ? null : archives.first.id;
    final controller = AgentChatPlugin.instance.conversationController;
    final conversation = controller?.conversationService
        .getTemporaryConversationForRoute('live2d:$id');
    if (conversation != null)
      await controller!.conversationService.deleteConversation(conversation.id);
    await save();
  }

  Future<String> sendMessage(String text) async {
    final archive = selected;
    if (archive?.agentId == null) throw StateError('请先在 Live2D 存档中选择 Agent');
    final agent = await AgentController().getAgent(archive!.agentId!);
    if (agent == null) throw StateError('Agent 不存在');
    final controller = AgentChatPlugin.instance.conversationController;
    if (controller == null) throw StateError('Agent Chat 尚未初始化');
    var conversation = controller.conversationService
        .getTemporaryConversationForRoute('live2d:${archive.id}');
    conversation ??= await controller.conversationService
        .createTemporaryConversation(
          title: archive.name,
          routeName: 'live2d:${archive.id}',
          agentId: agent.id,
        );
    if (!conversation.groups.contains(fixedGroup)) {
      conversation = conversation.copyWith(
        groups: [...conversation.groups, fixedGroup],
      );
      await controller.conversationService.updateConversation(conversation);
    }
    await controller.messageService.addMessage(
      ChatMessage.user(conversationId: conversation.id, content: text),
    );
    final response = await RequestService.chat(text, agent);
    await controller.messageService.addMessage(
      ChatMessage.ai(
        conversationId: conversation.id,
        content: response,
        isGenerating: false,
        generatedByAgentId: agent.id,
      ),
    );
    await controller.conversationService.updateLastMessage(
      conversation.id,
      response,
    );
    return response;
  }

  @override
  Widget buildMainView(BuildContext context) => const Live2DMainScreen();
  @override
  Widget buildSettingsView(BuildContext context) =>
      const Live2DSettingsScreen();
  @override
  String? getPluginName(context) => 'Live2D';
  @override
  Future<void> registerToApp(
    PluginManager pluginManager,
    ConfigManager configManager,
  ) async {}
}
