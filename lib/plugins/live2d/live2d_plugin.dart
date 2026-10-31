import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:aboutme/plugins/base_plugin.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/config_manager.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/services/plugin_data_selector/index.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_models.dart';
import 'package:aboutme/screens/jelly_home/live2d_zip_import.dart';
import 'package:aboutme/plugins/openai/aliveness/services/decision_service.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';
import 'live2d_voice_analyzer.dart';
import 'screens/live2d_main_screen.dart';
import 'screens/live2d_settings_screen.dart';

part 'live2d_data_selectors.dart';

class Live2DPlugin extends BasePlugin {
  static Live2DPlugin? _instance;
  static Live2DPlugin get instance =>
      _instance ??= PluginManager.instance.getPlugin('live2d') as Live2DPlugin;
  static const fixedGroup = 'live2d';
  static const defaultTypingIntervalMs = 70;
  static const defaultBubbleAsset = 'assets/bubbles/可拉伸兔子聊天气泡素材.webp';
  static const defaultBackgroundBlur = 0.0;
  static const defaultBackgroundOpacity = 1.0;

  /// 选中档案变化时广播的事件名（状态面板等据此同步头像）
  static const archiveSelectedEvent = 'live2d_archive_selected';

  /// 当前语音分析帧；JellyLive2D 订阅此值并更新 ParamMouthOpenY。
  final ValueNotifier<Live2DVoiceFrame?> voiceFrame =
      ValueNotifier<Live2DVoiceFrame?>(null);

  /// 正在准备或播报的回复；气泡等待对应语音结束后再隐藏。
  final ValueNotifier<String?> speakingReply = ValueNotifier<String?>(null);
  int _replySpeechGeneration = 0;

  final Live2DVoiceAnalyzer voiceAnalyzer = Live2DVoiceAnalyzer();
  Timer? _voiceAnalysisTimer;
  int _voiceAnalysisGeneration = 0;

  Map<String, double> get vowelConfidence =>
      voiceFrame.value?.vowels ??
      const {
        'VoiceSilence': 1,
        'VoiceA': 0,
        'VoiceI': 0,
        'VoiceU': 0,
        'VoiceE': 0,
        'VoiceO': 0,
      };

  void pushAudioPcm(List<double> samples, int sampleRate) {
    voiceFrame.value = voiceAnalyzer.processPcm(samples, sampleRate);
  }

  void pushAudioPcm16(List<int> bytes, int sampleRate) {
    voiceFrame.value = voiceAnalyzer.processPcm16(bytes, sampleRate);
  }

  void pushAudioMp3(Uint8List bytes) {
    voiceFrame.value = voiceAnalyzer.processMp3(bytes);
  }

  /// 按播放节奏切分 PCM，避免整段音频只产生一个口型帧。
  void startPcm16Analysis(List<int> bytes, int sampleRate) {
    _voiceAnalysisTimer?.cancel();
    final generation = ++_voiceAnalysisGeneration;
    var offset =
        bytes.length >= 44 &&
            String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF'
        ? 44
        : 0;
    const chunkBytes = 8192; // 4096 samples @ 32 kHz ~= 128 ms
    void processChunk() {
      if (generation != _voiceAnalysisGeneration) return;
      if (offset >= bytes.length) {
        _voiceAnalysisTimer?.cancel();
        _voiceAnalysisTimer = null;
        return;
      }
      final end = (offset + chunkBytes).clamp(offset, bytes.length);
      pushAudioPcm16(bytes.sublist(offset, end), sampleRate);
      debugPrint(
        '[Live2D][Voice] PCM frame bytes=${end - offset} '
        'mouth=${voiceFrame.value?.mouthOpenY.toStringAsFixed(3)}',
      );
      offset = end;
    }

    processChunk();
    _voiceAnalysisTimer = Timer.periodic(
      const Duration(milliseconds: 128),
      (_) => processChunk(),
    );
  }

  /// MP3 先完整解码，再按 PCM 采样块实时送入分析器。
  Future<void> startMp3Analysis(Uint8List bytes) async {
    _voiceAnalysisTimer?.cancel();
    final generation = ++_voiceAnalysisGeneration;
    if (bytes.isEmpty) {
      debugPrint('[Live2D][Voice] MP3 audio callback returned empty bytes');
      return;
    }
    debugPrint('[Live2D][Voice] MP3 analysis started: ${bytes.length} bytes');
    late final Live2DDecodedPcm decoded;
    try {
      decoded = await Future<Live2DDecodedPcm>.microtask(
        () => voiceAnalyzer.decodeMp3(bytes),
      );
    } catch (error) {
      debugPrint('[Live2D][Voice] MP3 decode failed: $error');
      return;
    }
    if (generation != _voiceAnalysisGeneration) return;
    if (decoded.samples.isEmpty ||
        decoded.channels <= 0 ||
        decoded.sampleRate <= 0) {
      debugPrint(
        '[Live2D][Voice] MP3 decode returned no usable PCM: '
        'samples=${decoded.samples.length}, channels=${decoded.channels}, '
        'sampleRate=${decoded.sampleRate}',
      );
      return;
    }
    debugPrint(
      '[Live2D][Voice] MP3 decoded: samples=${decoded.samples.length}, '
      'channels=${decoded.channels}, sampleRate=${decoded.sampleRate}',
    );
    var offset = 0;
    const samplesPerChunk = 4096;
    void processChunk() {
      if (generation != _voiceAnalysisGeneration) return;
      if (offset >= decoded.samples.length) {
        _voiceAnalysisTimer?.cancel();
        _voiceAnalysisTimer = null;
        return;
      }
      final end = (offset + samplesPerChunk * decoded.channels).clamp(
        offset,
        decoded.samples.length,
      );
      voiceFrame.value = voiceAnalyzer.processPcm(
        decoded.samples.sublist(offset, end),
        decoded.sampleRate,
        channels: decoded.channels,
      );
      debugPrint(
        '[Live2D][Voice] MP3 frame samples=${end - offset} '
        'mouth=${voiceFrame.value?.mouthOpenY.toStringAsFixed(3)}',
      );
      offset = end;
    }

    processChunk();
    final intervalMs = (samplesPerChunk * 1000 / decoded.sampleRate).round();
    _voiceAnalysisTimer = Timer.periodic(
      Duration(milliseconds: intervalMs.clamp(1, 1000)),
      (_) => processChunk(),
    );
  }

  void resetVoiceAnalysis() {
    _voiceAnalysisGeneration++;
    _voiceAnalysisTimer?.cancel();
    _voiceAnalysisTimer = null;
    voiceFrame.value = null;
  }

  /// 档案级随机走动开关（仅视频档案生效）：
  /// 修改档案字段并保存，广播 [archiveSelectedEvent] 让小屋舞台即时生效
  Future<void> setArchiveRandomWalkEnabled(
    Live2DArchive archive,
    bool enabled,
  ) async {
    archive.randomWalkEnabled = enabled;
    await save();
    _notifyArchiveSelected();
  }

  @override
  Future<void> updateSettings(Map<String, dynamic> newSettings) async {
    await super.updateSettings(newSettings);
  }

  Duration get bubbleTypingInterval => Duration(
    milliseconds:
        settings['typingIntervalMs'] as int? ?? defaultTypingIntervalMs,
  );

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
      (settings['backgroundBlur'] as num?)?.toDouble() ?? defaultBackgroundBlur;

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
      if (item is Map) importedModelFromJson(Map<String, dynamic>.from(item)),
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

  /// 更新导入记录的缩略图（本地模型库列表上传）
  Future<void> setImportedModelThumb(
    Live2DModelDefinition model,
    String? thumbPath,
  ) async {
    final next = _rawImportedModels().map((item) {
      if (item['modelDir'] == model.modelDir &&
          item['modelFile'] == model.modelFile) {
        return {...item, 'thumbPath': thumbPath};
      }
      return Map<String, dynamic>.from(item);
    }).toList();
    await updateSettings({'importedModels': next});
  }

  /// 引用指定导入模型的存档数量（删除前提示用）
  int archivesUsingModel(Live2DModelDefinition model) => archives
      .where(
        (a) => a.modelDir == model.modelDir && a.modelFile == model.modelFile,
      )
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

  /// [onSpeechStart] TTS 真正开始朗读时触发（用于同步反应动画）；
  /// 未启用/不可用 TTS、朗读文本为空或 TTS 失败时立即回退触发，保证动画不丢。
  Future<void> speakReply(String reply, {VoidCallback? onSpeechStart}) async {
    var speechStartFired = false;
    void fireSpeechStart() {
      if (onSpeechStart == null || speechStartFired) return;
      speechStartFired = true;
      onSpeechStart();
    }

    if (reply.trim().isEmpty) return fireSpeechStart();
    // 聊天请求失败（❌）或用户取消（🛑）的错误提示不朗读
    if (reply.startsWith('❌') || reply.startsWith('🛑')) {
      return fireSpeechStart();
    }

    // 语音设置统一存档绑定的 Agent 上；服务未指定时走全局默认服务
    final agentId = selected?.agentId;
    if (agentId == null) return fireSpeechStart();
    final generation = ++_replySpeechGeneration;
    speakingReply.value = reply;
    void finishSpeech() {
      if (generation != _replySpeechGeneration) return;
      speakingReply.value = null;
    }

    try {
      final agent = await AgentController().getAgent(agentId);
      if (generation != _replySpeechGeneration) return;
      if (agent == null || !agent.ttsEnabled) return fireSpeechStart();
      await TTSPlugin.instance.speak(
        reply,
        serviceId: agent.ttsServiceId,
        onStart: () {
          debugPrint('[Live2D][Voice] TTS 开始播报，触发反应动画');
          fireSpeechStart();
        },
        onAudioData: (bytes, format) {
          debugPrint(
            '[Live2D][Voice] TTS audio callback: format=$format, '
            'bytes=${bytes.length}',
          );
          // WAV/PCM 服务可直接分析；压缩音频需由服务端配置为 pcm 才能提供采样数据。
          final normalizedFormat = format
              ?.toLowerCase()
              .replaceFirst('audio/', '')
              .replaceFirst('.', '');
          final looksLikeMp3 =
              bytes.length >= 3 &&
              ((bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) ||
                  (bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0));
          if (normalizedFormat == 'wav' ||
              normalizedFormat == 'pcm' ||
              normalizedFormat == 's16le' ||
              normalizedFormat == 'pcm_s16le') {
            startPcm16Analysis(bytes, 32000);
          } else if (normalizedFormat == 'mp3' ||
              normalizedFormat == 'mpeg' ||
              normalizedFormat == 'mpeg3' ||
              (normalizedFormat == null && looksLikeMp3)) {
            unawaited(startMp3Analysis(Uint8List.fromList(bytes)));
          } else {
            debugPrint('[Live2D][Voice] unsupported TTS audio format: $format');
          }
        },
        onComplete: () {
          if (generation != _replySpeechGeneration) return;
          resetVoiceAnalysis();
          finishSpeech();
        },
        onError: (error) {
          finishSpeech();
          debugPrint('[Live2DChat] TTS failed: $error');
          // TTS 失败时回退：动画与回复完成同步。
          fireSpeechStart();
        },
      );
      // 成就系统计数（A13 播报员）
      EventManager.instance.broadcast(
        'live2d_tts_spoken',
        EventArgs('live2d_tts_spoken'),
      );
    } catch (error) {
      debugPrint('[Live2DChat] TTS unavailable: $error');
      fireSpeechStart();
    } finally {
      finishSpeech();
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
      'bubbleAsset': defaultBubbleAsset,
      'backgroundAsset': null,
      'backgroundBlur': defaultBackgroundBlur,
      'backgroundOpacity': defaultBackgroundOpacity,
      'customBackgroundAssets': <String>[],
      'bubbleRegions': <String, dynamic>{},
      'customBubbleAssets': <String>[],
      'importedModels': <Map<String, dynamic>>[],
    });
    final res = await AboutmeDataService.instance.call(
      'live2d',
      'getSnapshot',
      {},
    );
    final data = res['success'] == true ? res['data'] : null;
    final rawArchives = data is Map ? data['archives'] : null;
    // 迁移：旧全局“随机走动”设置 → 档案级字段（旧档案无该键时按旧全局值填充）
    final legacyWalkEnabled =
        settings['videoRandomWalkEnabled'] as bool? ?? false;
    archives
      ..clear()
      ..addAll(
        (rawArchives is List ? rawArchives : const []).map((e) {
          final json = Map<String, dynamic>.from(e as Map);
          if (!json.containsKey('randomWalkEnabled')) {
            json['randomWalkEnabled'] =
                json['displayMode'] == 'video' && legacyWalkEnabled;
          }
          return Live2DArchive.fromJson(json);
        }),
      );
    selectedId = data is Map ? data['selectedId'] as String? : null;

    // 注册数据选择器
    _registerDataSelectors();
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

  /// 确保当前存档有对应的聊天会话
  ///
  /// 正式会话：携带存档绑定的 agentId 保存到频道数据，不在会话列表默认
  /// 展示（仅通过 Agent 过滤显示）；旧版临时会话（7 天过期）在此迁移为
  /// 正式会话，聊天记录保留
  Future<Conversation> ensureConversation() async {
    final archive = selected;
    final agentId = archive?.agentId;
    final controller = AgentChatPlugin.instance.conversationController;
    if (archive == null || agentId == null || controller == null) {
      throw StateError('请先在 Live2D 存档中选择 Agent');
    }
    final service = controller.conversationService;
    var conversation = service.getTemporaryConversationForRoute(
      'live2d:${archive.id}',
    );
    if (conversation != null) {
      conversation = conversation.copyWith(
        metadata: {'live2dArchiveId': archive.id},
      );
      await service.updateConversation(conversation);
    }
    conversation ??= service.getConversationByMetadata(
      'live2dArchiveId',
      archive.id,
    );
    conversation ??= await controller.createConversation(
      title: archive.name,
      agentId: agentId,
      groups: [fixedGroup],
      metadata: {'live2dArchiveId': archive.id},
    );
    // 会话跟随存档当前绑定的 Agent：存档换绑后校正为新 Agent 并退出链式模式
    if (conversation.agentId != agentId || conversation.agentChain != null) {
      conversation = conversation.copyWith(
        agentId: agentId,
        clearAgentChain: true,
      );
      await service.updateConversation(conversation);
    }
    if (!conversation.groups.contains(fixedGroup)) {
      conversation = conversation.copyWith(
        groups: [...conversation.groups, fixedGroup],
      );
      await service.updateConversation(conversation);
    }
    return conversation;
  }

  Future<String> sendMessage(String text) async {
    final archive = selected;
    if (archive?.agentId == null) throw StateError('请先在 Live2D 存档中选择 Agent');
    final agent = await AgentController().getAgent(archive!.agentId!);
    if (agent == null) throw StateError('Agent 不存在');
    final controller = AgentChatPlugin.instance.conversationController;
    if (controller == null) throw StateError('Agent Chat 尚未初始化');
    final conversation = await ensureConversation();
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

  /// [videoAnimations] 非空时按视频桌宠处理：候选动作来自该列表
  /// （编辑器中启用的动画），不使用 Live2D 模型的表情/动作，
  /// 且不卡置信度门槛（choice 即采纳）。
  Future<Map<String, String>> decideAppearance(
    String reply, {
    required Live2DModelDefinition model,
    List<String>? videoAnimations,
  }) => DecisionService.instance.decideLive2D(
    reply: reply,
    note: selected?.note ?? '',
    requireConfidence: videoAnimations == null,
    expressions: videoAnimations == null
        ? model.expressions.map((item) => item.label).toList()
        : const <String>[],
    motions:
        videoAnimations ??
        model.motions
            .where((item) => item.group.toLowerCase() != 'idle')
            .map((item) => item.label)
            .toList(),
  );

  @override
  Widget buildMainView(BuildContext context) => const Live2DMainScreen();
  @override
  bool get hasSettingsView => true;

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
