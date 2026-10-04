import 'dart:math';

/// 角色内在状态（PRD 5.4.1 多维状态机），按 agentId 独立持久化。
/// 数值域：energy/arousal/intimacy/trust ∈ [0,1]，mood ∈ [-1,1]。
class AgentState {
  final double energy;
  final double mood;
  final double arousal;
  final double intimacy;
  final double trust;
  final String? currentActivity;
  final DateTime? lastInteractionAt;
  final DateTime? updatedAt;

  const AgentState({
    this.energy = 0.8,
    this.mood = 0.1,
    this.arousal = 0.4,
    this.intimacy = 0.2,
    this.trust = 0.2,
    this.currentActivity,
    this.lastInteractionAt,
    this.updatedAt,
  });

  double _clamp01(double v) => v.clamp(0.0, 1.0);

  /// 惰性恢复：能量按每天 +0.3 线性回升；亲密度按半衰期指数衰减。
  /// 在每次读取状态时调用，保证"关掉对话角色仍在生活"。
  AgentState decayTo(DateTime now, {int intimacyHalfLifeDays = 14}) {
    final base = updatedAt;
    if (base == null) return this; // 从未持久化过，不衰减
    final idleHours = now.difference(base).inMinutes / 60.0;
    if (idleHours <= 0) return this;

    final recoveredEnergy = _clamp01(energy + idleHours * 0.3 / 24.0);
    final decayFactor = pow(0.5, idleHours / 24.0 / intimacyHalfLifeDays);
    final decayedIntimacy = intimacy * decayFactor;

    return AgentState(
      energy: recoveredEnergy,
      mood: mood * decayFactor,
      arousal: arousal * decayFactor,
      intimacy: decayedIntimacy,
      trust: trust,
      currentActivity: null,
      lastInteractionAt: lastInteractionAt,
      updatedAt: now,
    );
  }

  /// 一次互动后的状态演化：消耗能量、按用户消息量回升亲密度。
  AgentState applyAfterInteraction({
    required double generatedLength,
    required double userEmotion,
    required int userMessageCount,
  }) {
    final energyCost = (generatedLength / 400.0).clamp(0.02, 0.15);
    final intimacyGain = (0.005 + 0.003 * userMessageCount).clamp(0.005, 0.02);
    return AgentState(
      energy: _clamp01(energy - energyCost),
      // 情绪向用户情绪方向轻微靠拢（情绪感染）
      mood: (mood * 0.8 + userEmotion * 0.2).clamp(-1.0, 1.0),
      arousal: _clamp01(arousal + 0.05),
      intimacy: _clamp01(intimacy + intimacyGain),
      trust: _clamp01(trust + intimacyGain * 0.5),
      currentActivity: currentActivity,
      lastInteractionAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'energy': energy,
    'mood': mood,
    'arousal': arousal,
    'intimacy': intimacy,
    'trust': trust,
    'currentActivity': currentActivity,
    'lastInteractionAt': lastInteractionAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory AgentState.fromJson(Map<String, dynamic> json) => AgentState(
    energy: ((json['energy'] as num?)?.toDouble() ?? 0.8).clamp(0.0, 1.0),
    mood: ((json['mood'] as num?)?.toDouble() ?? 0.1).clamp(-1.0, 1.0),
    arousal: ((json['arousal'] as num?)?.toDouble() ?? 0.4).clamp(0.0, 1.0),
    intimacy: ((json['intimacy'] as num?)?.toDouble() ?? 0.2).clamp(0.0, 1.0),
    trust: ((json['trust'] as num?)?.toDouble() ?? 0.2).clamp(0.0, 1.0),
    currentActivity: json['currentActivity'] as String?,
    lastInteractionAt:
        json['lastInteractionAt'] != null
            ? DateTime.parse(json['lastInteractionAt'] as String)
            : null,
    updatedAt:
        json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime(2000),
  );

  /// 供决策层与 prompt 注入用的人类可读摘要
  String describe() {
    final moodText =
        mood > 0.3 ? '心情不错' : (mood < -0.3 ? '情绪低落' : '心情平稳');
    final energyText =
        energy > 0.6 ? '精力充沛' : (energy < 0.3 ? '很疲惫' : '有点累');
    final intimacyText =
        intimacy > 0.7
            ? '与用户关系非常亲近'
            : intimacy > 0.4
            ? '与用户关系不错'
            : '与用户还不太熟';
    return '$energyText，$moodText，$intimacyText';
  }
}
