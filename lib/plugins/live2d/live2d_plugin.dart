import 'dart:io';

import 'package:flutter/material.dart';
import 'package:aboutme/plugins/base_plugin.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/config_manager.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_models.dart';
import 'package:aboutme/screens/jelly_home/live2d_zip_import.dart';
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
  static const defaultBubbleAsset = 'assets/bubbles/可拉伸兔子聊天气泡素材.webp';
  static const defaultBackgroundBlur = 0.0;
  static const defaultBackgroundOpacity = 1.0;

  /// 选中档案变化时广播的事件名（状态面板等据此同步头像）
  static const archiveSelectedEvent = 'live2d_archive_selected';

  Duration get bubbleTypingInterval => Duration(
    milliseconds:
        settings['typingIntervalMs'] as int? ?? defaultTypingIntervalMs,
  );

  bool get autoReadEnabled =>
      settings['autoReadEnabled'] as bool? ?? defaultAutoReadEnabled;

  String get bubbleAsset =>
      settings['bubbleAsset'] as String? ?? defaultBubbleAsset;

  Future<void> setBubbleAsset(String asset) async {
    await updateSettings({'bubbleAsset': asset});
  }

  /// 小屋背景图；null 表示不显示背景
  String? get backgroundAsset => settings['backgroundAsset'] as String?;

  Future<void> setBackgroundAsset(String? asset) async {
    await updateSettings({'backgroundAsset': asset});
  }

  /// 背景高斯模糊 sigma（0 = 不模糊）
  double get backgroundBlur =>
      (settings['backgroundBlur'] as num?)?.toDouble() ??
      defaultBackgroundBlur;

  Future<void> setBackgroundBlur(double value) async {
    await updateSettings({'backgroundBlur': value});
  }

  /// 背景不透明度（0.0 ~ 1.0）
  double get backgroundOpacity =>
      (settings['backgroundOpacity'] as num?)?.toDouble() ??
      defaultBackgroundOpacity;

  Future<void> setBackgroundOpacity(double value) async {
    await updateSettings({'backgroundOpacity': value});
  }

  List<String> get customBackgroundAssets =>
      (settings['customBackgroundAssets'] as List?)
          ?.whereType<String>()
          .toList() ??
      const [];

  Future<void> addCustomBackgroundAsset(String asset) async {
    final next = [...customBackgroundAssets];
    if (!next.contains(asset)) next.add(asset);
    await updateSettings({
      'customBackgroundAssets': next,
      'backgroundAsset': asset,
    });
  }

  List<String> get customBubbleAssets =>
      (settings['customBubbleAssets'] as List?)?.whereType<String>().toList() ??
      const [];

  /// 本地导入（zip）的模型库，经 settings.importedModels 持久化；
  /// 存档选中导入模型时据此找回完整定义（含动作列表）
  List<Live2DModelDefinition> get importedModels => [
    for (final item in (settings['importedModels'] as List? ?? const []))
      if (item is Map)
        importedModelFromJson(Map<String, dynamic>.from(item)),
  ];

  /// 新增/更新导入记录：同目录+同入口文件视为同一模型，覆盖旧记录
  Future<void> addImportedModel(Live2DModelDefinition model) async {
    final next = <Map<String, dynamic>>[
      ..._rawImportedModels()
          .where(
            (item) =>
                item['modelDir'] != model.modelDir ||
                item['modelFile'] != model.modelFile,
          )
          .map((item) => Map<String, dynamic>.from(item)),
      importedModelToJson(model),
    ];
    await updateSettings({'importedModels': next});
  }

  /// 删除导入记录；模型文件目录位于应用 live2d_models 目录内时一并清理磁盘
  Future<void> removeImportedModel(Live2DModelDefinition model) async {
    final next = _rawImportedModels()
        .where(
          (item) =>
              item['modelDir'] != model.modelDir ||
              item['modelFile'] != model.modelFile,
        )
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    await updateSettings({'importedModels': next});
    final dir = model.modelDir;
    if (dir.isEmpty ||
        !(dir.startsWith('/') || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(dir))) {
      return;
    }
    try {
      final modelsRoot = Directory(
        p.join((await getApplicationSupportDirectory()).path, 'live2d_models'),
      );
      // 只清理 live2d_models 目录内的子目录，避免误删任意路径
      if (p.isWithin(modelsRoot.path, p.normalize(dir))) {
        await Directory(p.normalize(dir)).delete(recursive: true);
      }
    } catch (error) {
      debugPrint('[Live2D] remove imported model files failed: $error');
    }
  }

  /// 引用指定导入模型的存档数量（删除前提示用）
  int archivesUsingModel(Live2DModelDefinition model) => archives
      .where((a) => a.modelDir == model.modelDir && a.modelFile == model.modelFile)
      .length;

  List<Map<String, dynamic>> _rawImportedModels() => [
    for (final item in (settings['importedModels'] as List? ?? const []))
      if (item is Map) Map<String, dynamic>.from(item),
  ];

  Future<void> addCustomBubbleAsset(String asset) async {
    final next = [...customBubbleAssets];
    if (!next.contains(asset)) next.add(asset);
    await updateSettings({'customBubbleAssets': next, 'bubbleAsset': asset});
  }

  Map<String, dynamic> get bubbleRegions {
    final value = settings['bubbleRegions'];
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  Future<void> setBubbleRegions(
    String asset,
    Map<String, double> regions,
  ) async {
    final next = bubbleRegions;
    next[asset] = regions;
    await updateSettings({'bubbleRegions': next});
  }

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
      // 成就系统计数（A13 播报员）
      EventManager.instance.broadcast(
        'live2d_tts_spoken',
        EventArgs('live2d_tts_spoken'),
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
      'bubbleAsset': defaultBubbleAsset,
      'backgroundAsset': null,
      'backgroundBlur': defaultBackgroundBlur,
      'backgroundOpacity': defaultBackgroundOpacity,
      'customBackgroundAssets': <String>[],
      'bubbleRegions': <String, dynamic>{},
      'customBubbleAssets': <String>[],
      'importedModels': <Map<String, dynamic>>[],
    });
    final res = await AboutmeDataService.instance
        .call('live2d', 'getSnapshot', {});
    final data = res['success'] == true ? res['data'] : null;
    final rawArchives = data is Map ? data['archives'] : null;
    archives
      ..clear()
      ..addAll(
        (rawArchives is List ? rawArchives : const []).map(
          (e) => Live2DArchive.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    selectedId = data is Map ? data['selectedId'] as String? : null;
  }

  Future<void> save() async =>
      AboutmeDataService.instance.call('live2d', 'saveSnapshot', {
        'snapshot': {
          'selectedId': selectedId,
          'archives': archives.map((a) => a.toJson()).toList(),
        },
      });
  Live2DArchive? get selected =>
      archives.where((a) => a.id == selectedId).firstOrNull;
  Future<void> upsert(Live2DArchive archive) async {
    final i = archives.indexWhere((a) => a.id == archive.id);
    if (i < 0) {
      archives.add(archive);
      // 成就系统计数（A12 伙伴收藏家，仅新增模型时）
      EventManager.instance.broadcast(
        'live2d_model_added',
        EventArgs('live2d_model_added'),
      );
    } else {
      archives[i] = archive;
    }
    selectedId = archive.id;
    await save();
    _notifyArchiveSelected();
  }

  Future<void> deleteArchive(String id) async {
    archives.removeWhere((item) => item.id == id);
    if (selectedId == id) {
      selectedId = archives.isEmpty ? null : archives.first.id;
    }
    final controller = AgentChatPlugin.instance.conversationController;
    final conversation = controller?.conversationService
        .getTemporaryConversationForRoute('live2d:$id');
    if (conversation != null) {
      await controller!.conversationService.deleteConversation(conversation.id);
    }
    await save();
    _notifyArchiveSelected();
  }

  void _notifyArchiveSelected() {
    EventManager.instance.broadcast(
      archiveSelectedEvent,
      EventArgs(archiveSelectedEvent),
    );
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
