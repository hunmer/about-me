/// 行为执行器：把生成完成的内容按真人节奏拆为多条消息（PRD 5.1.1 分条发送）。
/// 拆分规则纯通用（chat / agent_chat 共用），落库方式由各活人感通道实现。
class BehaviorExecutor {
  BehaviorExecutor._();
  static final BehaviorExecutor instance = BehaviorExecutor._();

  /// 按换行拆为多条消息（提示词已要求 AI 用换行分隔多条消息）。
  /// 保护：清理 markdown 列表符号；过短行（语气词/单字）并入前一条，
  /// 避免 AI 把一句话拆成碎行导致消息破碎。超 [maxBubbles] 行时合并尾部；
  /// 完全没有换行时按句末标点兜底拆分。
  List<String> splitIntoBubbles(String content, int maxBubbles) {
    final normalized = content.trim();
    if (normalized.isEmpty) return [normalized];

    var target = maxBubbles.clamp(1, 5);

    // 优先：每行一条（AI 主动分条），并清理行首列表符号
    var lines = normalized
        .split(RegExp(r'\n+'))
        .map((l) => l.trim())
        .map((l) => l.replaceFirst(RegExp(r'^([-*•]|\d+[.、)])\s*'), ''))
        .where((l) => l.isNotEmpty)
        .toList();

    // 兜底：完全没有换行时按句末标点拆
    if (lines.length <= 1) {
      lines = normalized
          .split(RegExp(r'(?<=[。！？!?~…])\s*'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
    }
    if (lines.length <= 1) return [normalized];

    // 短行保护：单字语气碎片（"嗯""哈"）并入前一条，正常短句仍独立成条
    final merged = <String>[lines.first];
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].length < 2) {
        merged[merged.length - 1] = '${merged.last}${lines[i]}';
      } else {
        merged.add(lines[i]);
      }
    }
    lines = merged;

    // 超过目标条数：尾部行并入最后一条，不丢内容
    if (lines.length > target) {
      final head = lines.sublist(0, target - 1);
      head.add(lines.sublist(target - 1).join(''));
      return head;
    }
    return lines;
  }
}
