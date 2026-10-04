/// 亲密度分层问题池（PRD 5.2.4 / 附录 B）：
/// 按当前亲密度解锁不同深度的探索问题，由决策层选择恰当时机抛出。
class QuestionPool {
  QuestionPool._();

  /// 低亲密度（0.0–0.3）：基础安全偏好
  static const List<String> low = [
    '你平时喜欢听什么类型的音乐？',
    '更喜欢晴天还是下雨天？',
    '有没有特别喜欢的季节？',
  ];

  /// 中亲密度（0.3–0.7）：生活习惯与轻度喜好
  static const List<String> mid = [
    '最近有没有想尝试的新事物？',
    '周末一般怎么过比较开心？',
    '工作/学习中最让你有成就感的是什么？',
    '有没有一直想去但还没去成的地方？',
  ];

  /// 高亲密度（0.7–1.0）：深层价值观与情感偏好
  static const List<String> high = [
    '什么样的事情会让你特别有安全感？',
    '对一段关系，你最看重的是什么？',
    '最近有没有什么事让你心里有点不安，但又不方便跟别人说？',
    '如果可以回到过去改变一件事，你会选什么？',
  ];

  /// 按亲密度返回已解锁的问题池
  static List<String> unlocked(double intimacy) {
    if (intimacy >= 0.7) return [...low, ...mid, ...high];
    if (intimacy >= 0.3) return [...low, ...mid];
    return [...low];
  }

  /// 过滤已问过的问题；全部问完则返回 null
  static String? pickUnasked(
    double intimacy,
    List<String> askedQuestions, {
    String Function()? random,
  }) {
    final pool = unlocked(intimacy);
    final candidates =
        pool.where((q) => !askedQuestions.contains(q)).toList();
    if (candidates.isEmpty) return null;
    if (random != null) {
      final picked = random();
      if (candidates.contains(picked)) return picked;
    }
    return candidates.first;
  }
}
