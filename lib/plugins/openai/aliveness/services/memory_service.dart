import 'dart:convert';

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

  /// 给决策层/prompt 用的记忆摘要（激活碎片的自然语言拼接）
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
    return activated.map((f) => '· ${f.content}').join('\n');
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
    if (archived > 0) await saveFragments(agentId, fragments);
    return archived;
  }

  // ---------- 写入（LLM 提取） ----------

  /// 互动完成后后台调用：让 LLM 从这段对话提取记忆碎片与开环事件。
  /// 输出受限（JSON、限条数），失败静默跳过（记忆提取不阻塞主流程）。
  Future<void> extractFromConversation(
    AIAgent agent, {
    required String userText,
    required String assistantText,
  }) async {
    try {
      if (userText.trim().isEmpty) return;
      final prompt = '从下面这轮对话中提取值得长期记住的用户信息。\n'
          '只输出 JSON，格式：\n'
          '{"memories":[{"content":"一句话事实","tags":["关键词"],"emotion":"neutral|positive|negative","importance":0.0到1.0}],"openLoops":[{"description":"待跟进事件","days":跟进天数}]}\n'
          '规则：只记关于用户的事实/偏好/计划，最多3条memories；没有值得记的输出 {"memories":[],"openLoops":[]}；'
          'openLoops 只收未来1~7天内可跟进的事（如面试、约会、出行），最多1条。\n'
          '对话：\n用户：$userText\n你：$assistantText';

      final result = await RequestService.chat(prompt, agent);
      final jsonStr = _extractJson(result);
      if (jsonStr == null) return;
      final data = json.decode(jsonStr) as Map<String, dynamic>;

      // 去重写入碎片
      final fragments = await loadFragments(agent.id);
      final existing = fragments.map((f) => f.content).toSet();
      final memories = data['memories'] as List<dynamic>? ?? [];
      for (final m in memories.take(3)) {
        final map = Map<String, dynamic>.from(m as Map);
        final content = (map['content'] as String?)?.trim();
        if (content == null || content.isEmpty || existing.contains(content)) {
          continue;
        }
        fragments.add(
          MemoryFragment(
            id: _uuid.v4(),
            content: content,
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
      }
      // 只保留最近 200 条未归档 + 全部归档的，防膨胀
      await saveFragments(agent.id, fragments);

      // 开环事件
      final loops = await loadOpenLoops(agent.id);
      loops.removeWhere((l) => l.isStale);
      final newLoops = data['openLoops'] as List<dynamic>? ?? [];
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
      }
      await saveOpenLoops(agent.id, loops);
    } catch (_) {
      // 记忆提取失败不影响主流程
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
