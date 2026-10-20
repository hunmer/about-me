import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:aboutme/plugins/openai/aliveness/models/memory_fragment.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';
import 'package:uuid/uuid.dart';

/// 类神经元记忆系统（PRD 5.3）：
/// - 写入：互动后后台用 LLM 提取碎片（含开环事件）
/// - 激活扩散：当前消息命中碎片 tags → 一级激活；已激活碎片的其余 tags → 二级加权
/// - 遗忘：importance × 遗忘曲线，权重过低归档（不删除）
class MemoryService {
  MemoryService._();
  static final MemoryService instance = MemoryService._();

  /// 当前活跃 agent 上下文（工具调用时无法携带会话信息，
  /// 由编排器/hook 在每次回复前设置）
  String? currentAgentId;

  final _store = AlivenessStore.instance;
  final _uuid = const Uuid();

  // ---------- 存储 ----------

  Future<List<MemoryFragment>> loadFragments(String agentId) async {
    final data = await _store.loadMemory(agentId);
    return (data['fragments'] as List<dynamic>? ?? [])
        .map((e) => MemoryFragment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveFragments(String agentId, List<MemoryFragment> fragments) =>
      _store.saveMemory(agentId, {
        'fragments': fragments.map((f) => f.toJson()).toList(),
      });

  Future<List<OpenLoop>> loadOpenLoops(String agentId) async {
    final data = await _store.loadOpenLoops(agentId);
    return (data['loops'] as List<dynamic>? ?? [])
        .map((e) => OpenLoop.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveOpenLoops(String agentId, List<OpenLoop> loops) =>
      _store.saveOpenLoops(agentId, {
        'loops': loops.map((l) => l.toJson()).toList(),
      });

  // ---------- 激活扩散（纯逻辑，可单测） ----------

  /// 从 [fragments] 中按 [queryText] 激活 Top-K 条记忆。
  /// 一级：tag 子串命中当前文本（中文无需分词）；
  /// 二级：一级命中碎片的其余 tags 再匹配（权重 ×0.5），模拟联想。
  static List<MemoryFragment> activate(
    List<MemoryFragment> fragments,
    String queryText, {
    int k = 5,
    int halfLifeDays = 14,
  }) {
    if (queryText.trim().isEmpty || fragments.isEmpty) return const [];
    final text = queryText.toLowerCase();

    final scores = <String, double>{};
    final byId = <String, MemoryFragment>{};
    final available =
        fragments.where((f) => !f.archived).where((f) => f.weight(halfLifeDays: halfLifeDays) > 0.05);

    // 一级激活
    final firstLevel = <MemoryFragment>[];
    for (final f in available) {
      byId[f.id] = f;
      final hit = f.tags.any((tag) => tag.isNotEmpty && text.contains(tag.toLowerCase()));
      if (hit) {
        final score = 1.0 * f.weight(halfLifeDays: halfLifeDays);
        scores[f.id] = (scores[f.id] ?? 0) + score;
        firstLevel.add(f);
      }
    }

    // 二级扩散：一级碎片的其余 tags 作为联想线索
    for (final f in firstLevel) {
      for (final other in available) {
        if (other.id == f.id || scores.containsKey(other.id)) continue;
        final linked = other.tags.any(
          (tag) => tag.isNotEmpty && f.tags.contains(tag),
        );
        if (linked) {
          scores[other.id] =
              0.5 * other.weight(halfLifeDays: halfLifeDays);
        }
      }
    }

    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked.take(k).map((e) => byId[e.key]!).toList();
  }

  /// 给决策层/prompt 用的记忆摘要（激活碎片的自然语言拼接）。
  /// 自我碎片加 [自己] 前缀，与用户记忆区分。
  Future<String> buildMemorySummary(
    String agentId,
    String queryText, {
    int k = 5,
    int halfLifeDays = 14,
  }) async {
    final fragments = await loadFragments(agentId);
    final activated = activate(
      fragments,
      queryText,
      k: k,
      halfLifeDays: halfLifeDays,
    );
    if (activated.isEmpty) return '';
    // 记录激活（供巩固统计）
    for (final f in activated) {
      f.activateCount++;
      f.lastActivatedAt = DateTime.now();
    }
    await saveFragments(agentId, fragments);
    return activated
        .map((f) => '· ${f.isSelf ? '[自己] ' : ''}${f.content}')
        .join('\n');
  }

  /// 核心记忆（常驻注入）：按权重取 Top-N（含手动标记，永不淡忘）。
  /// 解决"问我的兴趣/喜好"这类元问题——激活扩散依赖话题命中，
  /// 元问题不会命中任何 tag，必须常驻一份高权重记忆。
  Future<String> buildCoreMemorySummary(
    String agentId, {
    int k = 3,
    int halfLifeDays = 14,
  }) async {
    final fragments = await loadFragments(agentId);
    final available = fragments.where((f) => !f.archived && !f.isSelf).toList()
      ..sort(
        (a, b) => b
            .weight(halfLifeDays: halfLifeDays)
            .compareTo(a.weight(halfLifeDays: halfLifeDays)),
      );
    if (available.isEmpty) return '';
    return available.take(k).map((f) => '· ${f.content}').join('\n');
  }

  /// 自我记忆摘要（常驻注入）：AI 从自己发言中沉淀的近况/习惯/承诺，
  /// 让"我最近在干嘛"这类问题有真实答案而不是编造。
  Future<String> buildSelfSummary(
    String agentId, {
    int k = 3,
    int halfLifeDays = 14,
  }) async {
    final fragments = await loadFragments(agentId);
    final self = fragments.where((f) => !f.archived && f.isSelf).toList()
      ..sort(
        (a, b) => b
            .weight(halfLifeDays: halfLifeDays)
            .compareTo(a.weight(halfLifeDays: halfLifeDays)),
      );
    if (self.isEmpty) return '';
    return self.take(k).map((f) => '· ${f.content}').join('\n');
  }

  /// 记忆独立注入段（仅开启记忆管理、未走活人感编排时拼到 system 提示词后）。
  /// 内容与活人感注入段中的记忆块一致：核心常驻 + 话题激活 + 自我近况。
  Future<String> buildInjectionSuffix(
    String agentId,
    String queryText, {
    int halfLifeDays = 14,
  }) async {
    final core = await buildCoreMemorySummary(
      agentId,
      halfLifeDays: halfLifeDays,
    );
    final self = await buildSelfSummary(agentId, halfLifeDays: halfLifeDays);
    final activated = await buildMemorySummary(
      agentId,
      queryText,
      halfLifeDays: halfLifeDays,
    );
    final buffer = StringBuffer();
    if (core.isNotEmpty) {
      buffer.write(
        '\n【关于用户你一直记得的事】（用户问起你的了解时，'
        '基于这些内容自然地回答，不要说不知道）\n$core',
      );
    }
    if (activated.isNotEmpty) {
      buffer.write('\n【当前话题让你想起的往事】\n$activated');
    }
    if (self.isNotEmpty) {
      buffer.write(
        '\n【你自己的近况】（你亲自说过/做过的事，'
        '聊到相关话题时自然带出，不要刻意汇报）\n$self',
      );
    }
    return buffer.toString();
  }

  // ---------- 遗忘 ----------

  /// 归档权重低于阈值的碎片（未激活的低重要性记忆随时间淡忘）
  Future<int> applyForgetting(String agentId, {int halfLifeDays = 14}) async {
    final fragments = await loadFragments(agentId);
    var archived = 0;
    for (final f in fragments) {
      if (!f.archived && f.weight(halfLifeDays: halfLifeDays) < 0.05) {
        f.archived = true;
        archived++;
      }
    }
    if (archived > 0) {
      debugPrint('[Aliveness][记忆] 遗忘整理 | 归档 $archived 条低权重碎片');
      await saveFragments(agentId, fragments);
    }
    return archived;
  }

  // ---------- 写入（LLM 提取） ----------

  /// 互动完成后后台调用：让 LLM 从这段对话提取记忆碎片与开环事件。
  /// 同时提取两类碎片：关于用户（userMemories）与关于 AI 自己（selfMemories，
  /// 来自 AI 的发言：自己的经历/计划/习惯/承诺）。
  /// 输出受限（JSON、限条数），失败静默跳过（记忆提取不阻塞主流程）。
  Future<void> extractFromConversation(
    AIAgent agent, {
    required String userText,
    required String assistantText,
  }) async {
    try {
      if (userText.trim().isEmpty) return;
      final prompt = '从下面这轮对话中提取值得长期记住的信息。\n'
          '只输出 JSON，格式：\n'
          '{"userMemories":[{"content":"一句话事实","tags":["关键词"],"emotion":"neutral|positive|negative","importance":0.0到1.0}],'
          '"selfMemories":[{"content":"一句话事实","tags":["关键词"],"importance":0.0到1.0}],'
          '"openLoops":[{"description":"待跟进事件","days":跟进天数}]}\n'
          '规则：\n'
          '- userMemories 只记关于用户的事实/偏好/计划，最多3条\n'
          '- selfMemories 只记"你（AI角色）"在这轮对话里透露的自己的事：正在做/计划做/完成了什么、'
          '习惯爱好、对用户的承诺（如"我周末要去爬山""我答应明天提醒她"），最多2条；用户没问、你也没提自己就留空\n'
          '- 没有值得记的输出 {"userMemories":[],"selfMemories":[],"openLoops":[]}\n'
          '- openLoops 只收未来1~7天内可跟进的事（如面试、约会、出行），最多1条\n'
          '对话：\n用户：$userText\n你：$assistantText';

      final result = await RequestService.chat(
        prompt,
        agent,
        // 推理模型 reasoning 吃 token，小上限会导致输出为空
        maxTokens: 8000,
      );
      final jsonStr = _extractJson(result);
      if (jsonStr == null) return;
      final data = json.decode(jsonStr) as Map<String, dynamic>;

      // 去重写入碎片（兼容旧字段名 memories = 用户记忆）
      final fragments = await loadFragments(agent.id);
      final existing = fragments.map((f) => f.content).toSet();
      final userMemories = data['userMemories'] as List<dynamic>? ??
          data['memories'] as List<dynamic>? ??
          [];
      var added = 0;
      for (final m in userMemories.take(3)) {
        added += _appendFragment(fragments, m, existing, isSelf: false);
      }
      final selfMemories = data['selfMemories'] as List<dynamic>? ?? [];
      var selfAdded = 0;
      for (final m in selfMemories.take(2)) {
        selfAdded += _appendFragment(fragments, m, existing, isSelf: true);
      }
      // 只保留最近 200 条未归档 + 全部归档的，防膨胀
      await saveFragments(agent.id, fragments);
      debugPrint('[Aliveness][记忆] LLM 提取完成 | 用户碎片=+$added/${userMemories.length} '
          '自我碎片=+$selfAdded/${selfMemories.length} 总碎片=${fragments.length}');

      // 开环事件
      final loops = await loadOpenLoops(agent.id);
      loops.removeWhere((l) => l.isStale);
      final newLoops = data['openLoops'] as List<dynamic>? ?? [];
      var loopsAdded = 0;
      for (final l in newLoops.take(1)) {
        final map = Map<String, dynamic>.from(l as Map);
        final desc = (map['description'] as String?)?.trim();
        if (desc == null || desc.isEmpty) continue;
        final days = (map['days'] as num?)?.toInt() ?? 1;
        loops.add(
          OpenLoop(
            id: _uuid.v4(),
            description: desc,
            followUpBy: DateTime.now().add(Duration(days: days.clamp(1, 7))),
          ),
        );
        loopsAdded++;
        debugPrint('[Aliveness][记忆] 新开环事件 | "$desc" '
            '${days.clamp(1, 7)}天后跟进');
      }
      await saveOpenLoops(agent.id, loops);
      if (loopsAdded == 0 && newLoops.isEmpty) {
        debugPrint('[Aliveness][记忆] 本轮无新开环事件');
      }
    } catch (e) {
      // 记忆提取失败不影响主流程
      debugPrint('[Aliveness][记忆] 提取失败（已忽略）: $e');
    }
  }

  /// 从 LLM 回复中截取第一段 JSON 对象（容忍 markdown 代码块包裹）
  static String? _extractJson(String text) {
    final start = text.indexOf('{');
    if (start < 0) return null;
    final end = text.lastIndexOf('}');
    if (end <= start) return null;
    return text.substring(start, end + 1);
  }

  /// 解析一条 LLM 输出的记忆并去重写入；返回 1=写入 0=跳过
  int _appendFragment(
    List<MemoryFragment> fragments,
    dynamic raw,
    Set<String> existing, {
    required bool isSelf,
  }) {
    final map = Map<String, dynamic>.from(raw as Map);
    final content = (map['content'] as String?)?.trim();
    if (content == null || content.isEmpty || existing.contains(content)) {
      return 0;
    }
    existing.add(content);
    fragments.add(
      MemoryFragment(
        id: _uuid.v4(),
        content: content,
        isSelf: isSelf,
        tags:
            (map['tags'] as List<dynamic>?)
                ?.map((t) => t.toString())
                .where((t) => t.isNotEmpty)
                .toList() ??
            const [],
        emotionTag: map['emotion'] as String?,
        importance:
            ((map['importance'] as num?)?.toDouble() ?? 0.5).clamp(0.0, 1.0),
      ),
    );
    return 1;
  }

  /// 记忆查询工具（LLM 按需调用）：关键词激活检索，无命中回退核心记忆。
  /// 返回可直接 JSON 化的列表。
  Future<List<Map<String, dynamic>>> searchForTool(
    String agentId,
    String? query,
  ) async {
    final fragments = await loadFragments(agentId);
    final q = query?.trim() ?? '';
    List<MemoryFragment> hits;
    if (q.isEmpty) {
      hits = fragments.where((f) => !f.archived).toList()
        ..sort(
          (a, b) => b
              .weight()
              .compareTo(a.weight()),
        );
    } else {
      hits = activate(fragments, q, k: 8);
      if (hits.isEmpty) {
        // 关键词未命中时回退核心记忆，保证工具总有产出
        hits = fragments.where((f) => !f.archived).toList()
          ..sort(
            (a, b) => b
                .weight()
                .compareTo(a.weight()),
          );
      }
    }
    return hits.take(8).map((f) {
      return {
        'content': f.content,
        // subject = self 表示这是 AI 自己的记忆（而非关于用户的）
        if (f.isSelf) 'subject': 'self',
        'tags': f.tags,
        'importance': f.weight().toStringAsFixed(2),
        'userMarked': f.userMarked,
        'createdAt': '${f.createdAt.month}/${f.createdAt.day}',
      };
    }).toList();
  }

  /// 用户手动标记消息重要（消息长按菜单可挂）
  Future<void> addManual(String agentId, String content, List<String> tags) async {
    final fragments = await loadFragments(agentId);
    fragments.add(
      MemoryFragment(
        id: _uuid.v4(),
        content: content,
        tags: tags,
        importance: 1.0,
        userMarked: true,
      ),
    );
    await saveFragments(agentId, fragments);
  }

  // ---------- 管理页操作 ----------

  Future<void> markFragmentImportant(String agentId, String fragmentId) async {
    final fragments = await loadFragments(agentId);
    for (final f in fragments) {
      if (f.id == fragmentId) {
        f.userMarked = true;
        f.importance = 1.0;
        f.archived = false; // 标记重要自动从淡忘中恢复
      }
    }
    await saveFragments(agentId, fragments);
  }

  Future<void> unmarkFragment(String agentId, String fragmentId) async {
    final fragments = await loadFragments(agentId);
    for (final f in fragments) {
      if (f.id == fragmentId) f.userMarked = false;
    }
    await saveFragments(agentId, fragments);
  }

  Future<void> deleteFragment(String agentId, String fragmentId) async {
    final fragments = await loadFragments(agentId);
    fragments.removeWhere((f) => f.id == fragmentId);
    await saveFragments(agentId, fragments);
  }

  /// 手动添加开环事件（记忆管理页录入，AI 到期会主动跟进）
  Future<void> addOpenLoop(
    String agentId,
    String description, {
    int followUpDays = 1,
  }) async {
    final loops = await loadOpenLoops(agentId);
    loops.add(
      OpenLoop(
        id: _uuid.v4(),
        description: description,
        followUpBy: DateTime.now().add(
          Duration(days: followUpDays.clamp(1, 7)),
        ),
      ),
    );
    await saveOpenLoops(agentId, loops);
  }
}
