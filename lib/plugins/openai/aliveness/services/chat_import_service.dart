import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import 'package:aboutme/plugins/openai/aliveness/models/memory_fragment.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
import 'package:aboutme/plugins/openai/aliveness/services/memory_service.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';
import 'package:uuid/uuid.dart';

/// 一份导入的聊天文本（一个 txt/md 文件，或 zip 内的一个条目）
class ImportedChatText {
  final String name;
  final String content;
  const ImportedChatText({required this.name, required this.content});
}

/// 提取出的碎片草稿（解析 LLM 输出得到的中间结构，尚未写入）
class FragmentDraft {
  final String content;
  final List<String> tags;
  final String? emotion;
  final double importance;
  const FragmentDraft({
    required this.content,
    required this.tags,
    this.emotion,
    this.importance = 0.5,
  });
}

/// 单块双提取结果：关于用户的碎片 + 关于对方（TA）的观察
class ChunkExtraction {
  final List<FragmentDraft> memories; // 关于用户
  final List<String> observations; // 关于 TA
  const ChunkExtraction({required this.memories, required this.observations});
}

/// 分析阶段（进度 UI 用）
enum ChatImportPhase { extracting, generatingPersona }

/// 一次导入分析的汇总结果
class ChatImportResult {
  final int totalChunks; // 总块数
  final int processedChunks; // 成功调 LLM 的块数
  final int failedChunks; // 调用/解析失败的块数
  final int addedFragments; // 实际写入的碎片数（去重后）
  final bool cancelled;
  final String? createdAgentId; // 新建模式：创建的 agent id
  final String? createdAgentName; // 新建模式：创建的 agent 名字
  final String? persona; // 新建模式：生成的 system prompt
  const ChatImportResult({
    required this.totalChunks,
    required this.processedChunks,
    required this.failedChunks,
    required this.addedFragments,
    this.cancelled = false,
    this.createdAgentId,
    this.createdAgentName,
    this.persona,
  });
}

/// 聊天记录导入分析（活人感·记忆初始化 / TA 人格克隆）：
/// 参考 KnowMe 的理念——"真实对话会留下我做过"，把用户的历史聊天记录
/// 分段喂给 LLM 做两种提取：
/// - memories：关于用户本人的关键信息碎片（写入记忆库，让 AI 认识用户）
/// - observations：关于聊天对方（TA）的稳定特征观察
/// 两种用法：
/// 1. 只提取 memories，追加到用户显式选择的已有记忆库
/// 2. observations 汇总生成 TA 的人设 → 克隆模板 agent 配置创建新 AI，
///    memories 仍追加到所选库，新 AI 默认不绑定任何记忆库
/// 入口在 agent 编辑页活人感分组。
class ChatImportService {
  ChatImportService._();
  static final ChatImportService instance = ChatImportService._();

  static const textExtensions = {'txt', 'md', 'log', 'json', 'csv'};
  static const maxFileBytes = 10 * 1024 * 1024; // 单文本文件 10MB 上限
  static const maxZipBytes = 50 * 1024 * 1024; // zip 上限（压缩比高，放宽）
  static const chunkChars = 6000; // 每块字符数（DeepSeek 输入安全值）
  static const maxFragmentsPerChunk = 8;
  static const maxObservationsPerChunk = 5;
  static const maxObservationsTotal = 80; // reduce 输入上限（超出截断）

  /// 提取任务的输出上限：实测 deepseek-flash 的 reasoning 单独吃 8k+ token，
  /// 上限太小会导致 content 为空（RequestService.chat 默认 1000/agent.maxLength 不够）
  static const llmMaxOutputTokens = 12000;

  /// 块提取并发数：DeepSeek 个人 key 并发友好值，3 并发把全量 24 块
  /// 从约 14 分钟压到约 5 分钟
  static const extractConcurrency = 3;

  /// 微信导出工具的元数据文件（无对话内容，跳过免得污染提取）
  static const _metaFileNames = {'manifest.json', 'report.json', 'meta.json'};

  final _uuid = const Uuid();

  // ---------- 文件读取 ----------

  /// 从用户选中的文件列表读取聊天文本：
  /// txt/md/log/json/csv 直接读；zip 遍历内部文本条目。跳过其余类型。
  /// json 会先尝试按微信导出格式（messages.json）转换成干净对话文本。
  Future<List<ImportedChatText>> loadFromFiles(List<File> files) async {
    final texts = <ImportedChatText>[];
    for (final file in files) {
      final ext = _ext(file.path);
      try {
        if (ext == 'zip') {
          if (await file.length() > maxZipBytes) {
            debugPrint('[Aliveness][导入] 跳过超大 zip ${file.path}');
            continue;
          }
          final bytes = await file.readAsBytes();
          for (final entry in ZipDecoder().decodeBytes(bytes).files) {
            if (!entry.isFile || !textExtensions.contains(_ext(entry.name))) {
              continue;
            }
            if (_metaFileNames.contains(_baseName(entry.name))) continue;
            // archive 4.x：content 固定为 Uint8List
            final String raw = utf8.decode(entry.content);
            final content = _normalize(raw);
            if (content.trim().isEmpty) continue;
            texts.add(
              ImportedChatText(name: entry.name, content: _clip(content)),
            );
          }
        } else if (textExtensions.contains(ext)) {
          if (await file.length() > maxFileBytes) {
            debugPrint('[Aliveness][导入] 跳过超大文件 ${file.path}');
            continue;
          }
          final content = _normalize(await file.readAsString());
          if (content.trim().isNotEmpty) {
            texts.add(
              ImportedChatText(name: _baseName(file.path), content: _clip(content)),
            );
          }
        }
      } catch (e) {
        debugPrint('[Aliveness][导入] 读取失败 ${file.path}: $e');
      }
    }
    return texts;
  }

  /// 文本规范化：识别已知聊天导出格式转为干净对话文本，其余原样返回。
  /// 微信导出 messages.json 的每条消息 90% 是无关字段（md5/url 等），
  /// 不转换的话等于把结构噪声喂给 LLM。
  static String _normalize(String raw) {
    final wechat = tryFormatWeChatExport(raw);
    return wechat ?? raw;
  }

  /// 单条目字符数上限（防超大 txt 撑爆内存），超出截断
  static String _clip(String s) =>
      s.length > 200000 ? s.substring(0, 200000) : s;

  // ---------- 分块（纯逻辑，可单测） ----------

  /// 按约 [chunkChars] 字符分块，优先在换行处切开，避免把一条消息劈成两半。
  static List<String> splitChunks(String text, {int chunkChars = chunkChars}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.length <= chunkChars) return [trimmed];

    final chunks = <String>[];
    var start = 0;
    while (start < trimmed.length) {
      var end = (start + chunkChars).clamp(0, trimmed.length);
      if (end < trimmed.length) {
        // 在块尾往前找换行，找得到就在行边界切（不超过块上限）
        final lastBreak = trimmed.lastIndexOf('\n', end);
        if (lastBreak > start + chunkChars ~/ 2) {
          end = (lastBreak + 1).clamp(start + 1, start + chunkChars);
        }
      }
      final chunk = trimmed.substring(start, end).trim();
      if (chunk.isNotEmpty) chunks.add(chunk);
      start = end;
    }
    return chunks;
  }

  // ---------- 微信导出格式适配（纯逻辑，可单测） ----------

  /// 微信聊天导出工具的 messages.json → 干净对话文本。
  /// 识别特征：顶层 JSON 对象含非空 messages 数组，且消息带 renderType 字段。
  /// 不是该格式返回 null（调用方按普通文本处理）。
  ///
  /// 输出形如：
  /// ```
  /// 与「嘘」的聊天记录（"我" = 用户本人，其余名字 = 聊天对象）
  /// —— 2026-01-31 ——
  /// 23:04 我：所以你是不是已经本能的说不要香菜哈哈
  /// 23:07 嘘：我连煎饼果子都不吃了
  /// ```
  /// - text 消息取 content；voice 取 voiceTranscript（无转写标记 [语音]）
  /// - 无内容的消息（图片/视频等未导出类型）跳过
  /// - isSent=true 标注为「我」（导出账号本人），false 用 senderDisplayName
  static String? tryFormatWeChatExport(String raw) {
    dynamic data;
    try {
      data = json.decode(raw.trim());
    } catch (_) {
      return null;
    }
    if (data is! Map) return null;
    final messages = data['messages'];
    if (messages is! List || messages.isEmpty) return null;
    final first = messages.first;
    if (first is! Map || first['renderType'] == null) return null;

    final conversation = data['conversation'];
    final peerName =
        (conversation is Map ? conversation['displayName'] as String? : null) ??
        '';

    final lines = <String>[
      if (peerName.isNotEmpty) '与「$peerName」的聊天记录（"我" = 用户本人，其余名字 = 聊天对象）',
    ];
    String? lastDate;
    for (final m in messages) {
      if (m is! Map) continue;
      final time = (m['createTimeText'] as String?) ?? '';
      final date = time.length >= 10 ? time.substring(0, 10) : '';
      final hhmm = time.length >= 16 ? time.substring(11, 16) : '';
      if (date.isNotEmpty && date != lastDate) {
        lines.add('—— $date ——');
        lastDate = date;
      }
      final isSent = m['isSent'] as bool? ?? false;
      final name = isSent
          ? '我'
          : ((m['senderDisplayName'] as String?)?.trim().isNotEmpty == true
                ? m['senderDisplayName'] as String
                : (peerName.isNotEmpty ? peerName : '对方'));
      final renderType = m['renderType'] as String? ?? '';
      String content;
      if (renderType == 'voice') {
        final t = (m['voiceTranscript'] as String?)?.trim() ?? '';
        content = t.isNotEmpty ? t : '[语音]';
      } else {
        content = (m['content'] as String?)?.trim() ?? '';
      }
      if (content.isEmpty) continue;
      lines.add('$hhmm $name：$content');
    }
    // 首条日期行之前没有任何消息行 → 只有元信息，视为无效
    if (lines.length <= 1) return null;
    return lines.join('\n');
  }

  // ---------- 分析主流程 ----------

  /// 逐块调 agent 的 LLM 双提取（用户碎片 + TA 观察），跨块去重。
  /// [memoryId] 必须是用户显式选择的已有库，不从 agent 配置推导或自动创建。
  /// [createAgent] = true 时：观察汇总生成 TA 人设 → 克隆 [agent] 配置
  /// 创建无库的新 agent，两种模式的碎片均追加到 [memoryId]。
  /// [onProgress] 每块/每阶段回调；[shouldCancel] 返回 true 时中止
  /// （已有 agent 模式保留已提取碎片，新建模式取消不产生半成品 agent）。
  Future<ChatImportResult> analyze({
    required AIAgent agent,
    required List<ImportedChatText> texts,
    String? memoryId,
    bool createAgent = false,
    void Function(ChatImportPhase phase, int processed, int total, int added)?
      onProgress,
    bool Function()? shouldCancel,
  }) async {
    if (memoryId == null || memoryId.trim().isEmpty) {
      throw const ChatImportException('请先选择目标记忆库；没有记忆库时请先去记忆管理创建');
    }
    final libraries = await AlivenessStore.instance.loadMemoryLibraries();
    if (!libraries.any((library) => library.id == memoryId)) {
      throw const ChatImportException('目标记忆库不存在，请先去记忆管理创建或重新选择');
    }

    // 所有文件按顺序拼接成块（块前标注来源文件名）
    final chunks = <String>[];
    for (final t in texts) {
      for (final c in splitChunks(t.content)) {
        chunks.add('【记录：${t.name}】\n$c');
      }
    }
    if (chunks.isEmpty) {
      return const ChatImportResult(
        totalChunks: 0,
        processedChunks: 0,
        failedChunks: 0,
        addedFragments: 0,
      );
    }

    // 提取专用 agent 视图：
    // - 清掉人设（system prompt / 预设）——角色人设会诱导模型用角色口吻
    //   回答而不是输出 JSON，提取任务只需要纯任务指令
    // - 推理模型 reasoning 单独吃 token，显式给大输出上限
    //   （只影响本次请求，不改 agent 本身配置）
    final llmAgent = agent.copyWith(
      promptPresetId: '',
      messages: [],
    );

    final fragments = <MemoryFragment>[];
    final existing = <String>{};
    final observations = <String>[];
    var processed = 0, failed = 0, added = 0;

    // 分批并发提取（批内并发、批间保序）：块间结果互不依赖，
    // 保序处理保证去重顺序稳定（重复信息归属到更早的块）
    for (var start = 0; start < chunks.length; start += extractConcurrency) {
      if (shouldCancel?.call() ?? false) {
        // 取消：已有 agent 模式保留已提取的；新建模式不落任何东西
        if (!createAgent) {
          await _mergeIntoMemory(memoryId, fragments);
        }
        return ChatImportResult(
          totalChunks: chunks.length,
          processedChunks: processed,
          failedChunks: failed,
          addedFragments: added,
          cancelled: true,
        );
      }
      final batch = [for (var i = start; i < chunks.length && i < start + extractConcurrency; i++) i];
      final extractions = await Future.wait(
        batch.map((i) async {
          try {
            return await _extractChunk(llmAgent, chunks[i]);
          } catch (e) {
            failed++;
            debugPrint('[Aliveness][导入] 第${i + 1}块提取失败（继续）: $e');
            return null;
          }
        }),
      );
      for (final extraction in extractions) {
        if (extraction == null) continue;
        processed++;
        for (final d in extraction.memories) {
          if (existing.contains(d.content)) continue;
          existing.add(d.content);
          fragments.add(
            MemoryFragment(
              id: _uuid.v4(),
              content: d.content,
              tags: d.tags,
              emotionTag: d.emotion,
              importance: d.importance,
            ),
          );
          added++;
        }
        for (final o in extraction.observations) {
          if (!observations.contains(o)) observations.add(o);
        }
      }
      onProgress?.call(
        ChatImportPhase.extracting,
        processed + failed,
        chunks.length,
        added,
      );
    }

    // ---------- 新建 agent 模式：观察 → 人设 → 创建 ----------
    if (createAgent) {
      if (observations.isEmpty) {
        throw const ChatImportException('没有从记录里提取到 TA 的特征，请确认记录里包含 TA 的发言');
      }
      onProgress?.call(ChatImportPhase.generatingPersona, processed, chunks.length, added);
      final persona = await _generatePersona(llmAgent, observations);
      final newAgent = buildAgentFromPersona(agent, persona);
      await _saveNewAgent(newAgent);
      await _mergeIntoMemory(memoryId, fragments);
      debugPrint('[Aliveness][导入] 已创建 agent「${persona.name}」| '
          '碎片=$added 观察=${observations.length}');
      return ChatImportResult(
        totalChunks: chunks.length,
        processedChunks: processed,
        failedChunks: failed,
        addedFragments: added,
        createdAgentId: newAgent.id,
        createdAgentName: persona.name,
        persona: persona.persona,
      );
    }

    await _mergeIntoMemory(memoryId, fragments);
    debugPrint('[Aliveness][导入] 分析完成 | 块=$processed/${chunks.length} '
        '失败=$failed 新增碎片=$added');
    return ChatImportResult(
      totalChunks: chunks.length,
      processedChunks: processed,
      failedChunks: failed,
      addedFragments: added,
    );
  }

  /// 碎片追加到显式选择的独立记忆库，保留库中的已有数据。
  Future<void> _mergeIntoMemory(
    String memoryId,
    List<MemoryFragment> fragments,
  ) async {
    if (fragments.isEmpty) return;
    await MemoryService.instance.mergeFragments(memoryId, fragments);
  }

  Future<void> _saveNewAgent(AIAgent agent) async {
    await OpenAIPlugin.instance.controller.saveAgent(agent);
  }

  // ---------- 单块双提取（LLM） ----------

  /// 单块 LLM 双提取（提取失败/无 JSON 抛给上层计失败块）。
  /// deepseek-flash 等推理模型的 reasoning 单独计 token，agent 常配的
  /// maxLength=2000 会被思考吃光导致 content 为空，这里临时提高上限
  /// （只影响本次请求，不改 agent 配置）。
  Future<ChunkExtraction> _extractChunk(AIAgent agent, String chunk) async {
    final prompt = '下面是用户的一段真实聊天记录片段（用户与 TA 的对话）。请提取两类信息。\n'
        '只输出 JSON，格式：\n'
        '{"memories":[{"content":"一句话事实","tags":["关键词","关键词"],"emotion":"neutral|positive|negative","importance":0.0到1.0}],'
        '"observations":["关于TA的观察"]}\n'
        '规则：\n'
        '- memories：只提取能确定属于「用户本人」的信息，按这些类目：身份背景（职业/学校/居所）、'
        '兴趣偏好、习惯作息、性格特点、人际关系、近期计划与待办、重要的情绪事件；'
        'content 一句话不超过30字，不写猜测；最多 $maxFragmentsPerChunk 条\n'
        '- tags 2~4 个激活关键词：聊天中再提到相关话题时能命中；'
        'importance：日常闲聊 0.3，稳定偏好/背景 0.7，重大事件/关系 0.9\n'
        '- observations：TA（与用户聊天的那个人）在这段对话里表现出的稳定特征：说话风格（语气/句式长短/'
        '标点emoji习惯/口头禅）、性格、兴趣话题、价值观、对用户的态度；一条一句不超过30字，'
        '只写记录能支持的；最多 $maxObservationsPerChunk 条\n'
        '- 没有可提取的输出 {"memories":[],"observations":[]}\n'
        '聊天记录：\n$chunk';
    final result = await RequestService.chat(
      prompt,
      agent,
      maxTokens: llmMaxOutputTokens,
    );
    if (result.startsWith('Error:')) {
      debugPrint('[Aliveness][导入] LLM 请求失败: $result');
      throw FormatException(result);
    }
    final extraction = parseChunkResponse(result);
    if (extraction == null) {
      debugPrint(
        '[Aliveness][导入] LLM 输出无 JSON，前300字符: '
        '${result.length > 300 ? result.substring(0, 300) : result}',
      );
      throw const FormatException('LLM 输出无 JSON');
    }
    return extraction;
  }

  /// 观察汇总 → TA 人设（reduce）
  Future<PersonaDraft> _generatePersona(
    AIAgent agent,
    List<String> observations,
  ) async {
    final obs = observations.take(maxObservationsTotal).toList();
    final prompt = '以下是对某个人（TA）在与用户长期聊天中表现的观察记录。'
        '请基于这些观察为 TA 生成一个 AI 角色扮演人设，用于创建一个"就是 TA"的 AI。\n'
        '只输出 JSON，格式：\n'
        '{"name":"名字","persona":"完整人设"}\n'
        '规则：\n'
        '- name：TA 在聊天中的称呼/名字/昵称（5字内，观察里没有就根据风格起一个贴合的）\n'
        '- persona：写给人设 AI 的 system prompt，用第二人称"你是"开头，300字内，包含：\n'
        '  性格底色、说话风格（语气、句式长短、标点/emoji 习惯、口头禅——从观察里提炼，要具体到能模仿）、'
        '兴趣话题、与用户的关系和相处态度\n'
        '- 只依据观察提炼风格与关系，不虚构观察之外的具体事实（如职业、经历）\n'
        '观察记录：\n${obs.map((o) => '- $o').join('\n')}';
    final result = await RequestService.chat(
      prompt,
      agent,
      maxTokens: llmMaxOutputTokens,
    );
    final draft = parsePersona(result);
    if (draft == null) {
      throw const ChatImportException('生成 TA 人设失败（模型未返回有效 JSON），请重试');
    }
    return draft;
  }

  /// 解析单块 LLM 双提取输出（纯逻辑，可单测）。
  /// 截取首段 JSON 对象，容忍 markdown 代码块与前置思考文本；返回 null = 无 JSON。
  static ChunkExtraction? parseChunkResponse(String text) {
    final map = _firstJsonObject(text);
    if (map == null) return null;
    try {
      final memories = (map['memories'] as List<dynamic>? ?? const [])
          .map((raw) {
            final m = Map<String, dynamic>.from(raw as Map);
            return FragmentDraft(
              content: (m['content'] as String?)?.trim() ?? '',
              tags:
                  (m['tags'] as List<dynamic>?)
                      ?.map((t) => t.toString().trim())
                      .where((t) => t.isNotEmpty)
                      .toList() ??
                  const [],
              emotion: m['emotion'] as String?,
              importance:
                  ((m['importance'] as num?)?.toDouble() ?? 0.5).clamp(0.0, 1.0),
            );
          })
          .where((d) => d.content.isNotEmpty)
          .take(maxFragmentsPerChunk)
          .toList();
      final observations =
          (map['observations'] as List<dynamic>? ?? const [])
              .map((o) => o.toString().trim())
              .where((o) => o.isNotEmpty)
              .take(maxObservationsPerChunk)
              .toList();
      return ChunkExtraction(memories: memories, observations: observations);
    } catch (_) {
      return null;
    }
  }

  /// 解析人设生成输出（纯逻辑，可单测）
  static PersonaDraft? parsePersona(String text) {
    final map = _firstJsonObject(text);
    if (map == null) return null;
    final name = (map['name'] as String?)?.trim() ?? '';
    final persona = (map['persona'] as String?)?.trim() ?? '';
    if (name.isEmpty || persona.isEmpty) return null;
    return PersonaDraft(name: name, persona: persona);
  }

  static Map<String, dynamic>? _firstJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      return Map<String, dynamic>.from(
        json.decode(text.substring(start, end + 1)) as Map,
      );
    } catch (_) {
      return null;
    }
  }

  /// 由模板 agent + 人设构造新 agent（纯逻辑，可单测）：
  /// 克隆模型/活人感等配置，替换 id/名字/人设，清空记忆库绑定。
  static AIAgent buildAgentFromPersona(AIAgent template, PersonaDraft draft) =>
      template.copyWith(
        id: const Uuid().v4(),
        name: draft.name,
        description: '从聊天记录提取 TA 的人格生成',
        messages: [Prompt(type: 'system', content: draft.persona)],
        alivenessConfig: template.alivenessConfig?.copyWith(memoryIds: const []),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  static String _ext(String path) => path.split('.').last.toLowerCase();

  static String _baseName(String path) =>
      path.split('/').last.split('\\').last;
}

/// 生成的人设草稿
class PersonaDraft {
  final String name;
  final String persona;
  const PersonaDraft({required this.name, required this.persona});
}

/// 导入分析业务异常（UI 可直接展示 message）
class ChatImportException implements Exception {
  final String message;
  const ChatImportException(this.message);
  @override
  String toString() => message;
}
