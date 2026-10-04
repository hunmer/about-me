/// 「活人感」增强配置：挂在每个 AIAgent 上，随 agent 持久化于 agents.json。
/// null / enabled=false 时 ChatEventHandler 走原有直接生成路径。
class AlivenessConfig {
  /// 总开关
  final bool enabled;

  /// 消息缓冲窗口（秒）：收到用户消息后先"看完再回"的等待区间，
  /// 实际时长按亲密度与惰性在 [bufferMinSec, bufferMaxSec] 内插值。
  final int bufferMinSec;
  final int bufferMaxSec;

  /// 单次回复最大分条数（1~5，PRD 5.1.1）
  final int maxBubbles;

  /// 相邻分条消息之间的延迟区间（毫秒）
  final int bubbleDelayMinMs;
  final int bubbleDelayMaxMs;

  /// 惰性程度 0~1：越高越倾向短回复、延迟、省力
  final double laziness;

  /// 记忆遗忘半衰期（天），Phase 2 使用，先随配置持久化
  final int forgettingHalfLifeDays;

  /// 主动消息（Phase 3）：开关 / 冷却分钟 / 每日上限 / 免打扰时段 [start, end]（24h 制）
  final bool proactiveEnabled;
  final int proactiveCooldownMin;
  final int proactiveDailyLimit;
  final List<int> quietHours;

  /// 主动语音决策开关（Phase 4）
  final bool voiceEnabled;

  const AlivenessConfig({
    this.enabled = false,
    this.bufferMinSec = 8,
    this.bufferMaxSec = 45,
    this.maxBubbles = 5,
    this.bubbleDelayMinMs = 800,
    this.bubbleDelayMaxMs = 3000,
    this.laziness = 0.5,
    this.forgettingHalfLifeDays = 14,
    this.proactiveEnabled = false,
    this.proactiveCooldownMin = 60,
    this.proactiveDailyLimit = 3,
    this.quietHours = const [23, 8],
    this.voiceEnabled = false,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'bufferMinSec': bufferMinSec,
    'bufferMaxSec': bufferMaxSec,
    'maxBubbles': maxBubbles,
    'bubbleDelayMinMs': bubbleDelayMinMs,
    'bubbleDelayMaxMs': bubbleDelayMaxMs,
    'laziness': laziness,
    'forgettingHalfLifeDays': forgettingHalfLifeDays,
    'proactive': {
      'enabled': proactiveEnabled,
      'cooldownMin': proactiveCooldownMin,
      'dailyLimit': proactiveDailyLimit,
      'quietHours': quietHours,
    },
    'voice': {'enabled': voiceEnabled},
  };

  factory AlivenessConfig.fromJson(Map<String, dynamic> json) {
    final proactive = json['proactive'] as Map<String, dynamic>?;
    final voice = json['voice'] as Map<String, dynamic>?;
    return AlivenessConfig(
      enabled: json['enabled'] as bool? ?? false,
      bufferMinSec: json['bufferMinSec'] as int? ?? 8,
      bufferMaxSec: json['bufferMaxSec'] as int? ?? 45,
      maxBubbles: (json['maxBubbles'] as int? ?? 5).clamp(1, 5),
      bubbleDelayMinMs: json['bubbleDelayMinMs'] as int? ?? 800,
      bubbleDelayMaxMs: json['bubbleDelayMaxMs'] as int? ?? 3000,
      laziness: ((json['laziness'] as num?)?.toDouble() ?? 0.5).clamp(0.0, 1.0),
      forgettingHalfLifeDays: json['forgettingHalfLifeDays'] as int? ?? 14,
      proactiveEnabled: proactive?['enabled'] as bool? ?? false,
      proactiveCooldownMin: proactive?['cooldownMin'] as int? ?? 60,
      proactiveDailyLimit: proactive?['dailyLimit'] as int? ?? 3,
      quietHours:
          (proactive?['quietHours'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [23, 8],
      voiceEnabled: voice?['enabled'] as bool? ?? false,
    );
  }

  AlivenessConfig copyWith({
    bool? enabled,
    int? bufferMinSec,
    int? bufferMaxSec,
    int? maxBubbles,
    int? bubbleDelayMinMs,
    int? bubbleDelayMaxMs,
    double? laziness,
    int? forgettingHalfLifeDays,
    bool? proactiveEnabled,
    int? proactiveCooldownMin,
    int? proactiveDailyLimit,
    List<int>? quietHours,
    bool? voiceEnabled,
  }) {
    return AlivenessConfig(
      enabled: enabled ?? this.enabled,
      bufferMinSec: bufferMinSec ?? this.bufferMinSec,
      bufferMaxSec: bufferMaxSec ?? this.bufferMaxSec,
      maxBubbles: maxBubbles ?? this.maxBubbles,
      bubbleDelayMinMs: bubbleDelayMinMs ?? this.bubbleDelayMinMs,
      bubbleDelayMaxMs: bubbleDelayMaxMs ?? this.bubbleDelayMaxMs,
      laziness: laziness ?? this.laziness,
      forgettingHalfLifeDays: forgettingHalfLifeDays ?? this.forgettingHalfLifeDays,
      proactiveEnabled: proactiveEnabled ?? this.proactiveEnabled,
      proactiveCooldownMin: proactiveCooldownMin ?? this.proactiveCooldownMin,
      proactiveDailyLimit: proactiveDailyLimit ?? this.proactiveDailyLimit,
      quietHours: quietHours ?? this.quietHours,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
    );
  }
}
