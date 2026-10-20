/// 「活人感」增强配置：挂在每个 AIAgent 上，随 agent 持久化于 agents.json。
/// null / enabled=false 时 ChatEventHandler 走原有直接生成路径。
class AlivenessConfig {
  /// copyWith 的哨兵值：区分"未传参"与"显式传 null"
  static const _unset = Object();

  /// 总开关
  final bool enabled;

  /// 历史兼容字段。实际缓冲等待固定为 5 秒，收到新消息会重置计时。
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

  /// 语音消息使用的 TTS 服务 ID（null = 跟随全局配置的 voiceServiceId）
  final String? ttsServiceId;

  /// 生成后使用 Jev 评分拟人度，低分自动要求模型修订。
  final bool humanScoreEnabled;
  final int humanScoreThreshold;

  /// 记忆管理独立开关：不依赖总开关，单独开启时普通聊天路径
  /// 也会注入记忆并在回复后提取。旧数据无此字段时跟随 enabled。
  final bool memoryEnabled;
  /// rounds / interval 二选一，默认累计 10 轮；时间模式默认 10 分钟。
  final String memoryExtractionMode;
  final int memoryExtractionRounds;
  final int memoryExtractionIntervalMin;

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
    this.ttsServiceId,
    this.humanScoreEnabled = false,
    this.humanScoreThreshold = 2,
    this.memoryEnabled = false,
    this.memoryExtractionMode = 'rounds',
    this.memoryExtractionRounds = 10,
    this.memoryExtractionIntervalMin = 10,
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
    if (ttsServiceId != null) 'ttsServiceId': ttsServiceId,
    'humanScore': {
      'enabled': humanScoreEnabled,
      'threshold': humanScoreThreshold,
    },
    'memoryEnabled': memoryEnabled,
    'memoryExtractionMode': memoryExtractionMode,
    'memoryExtractionRounds': memoryExtractionRounds,
    'memoryExtractionIntervalMin': memoryExtractionIntervalMin,
  };

  factory AlivenessConfig.fromJson(Map<String, dynamic> json) {
    // 嵌套对象经 json 解码后可能是 _Map<dynamic, dynamic>，显式转换避免 downcast 崩溃
    Map<String, dynamic>? asMap(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;
    final proactive = asMap(json['proactive']);
    final voice = asMap(json['voice']);
    final humanScore = asMap(json['humanScore']);
    final enabled = json['enabled'] as bool? ?? false;
    return AlivenessConfig(
      enabled: enabled,
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
      ttsServiceId: json['ttsServiceId'] as String?,
      humanScoreEnabled: humanScore?['enabled'] as bool? ?? false,
      humanScoreThreshold: (humanScore?['threshold'] as int? ?? 2).clamp(0, 3),
      // 旧数据无此字段：活人感开启的老 agent 此前一直带记忆，保持开启
      memoryEnabled: json['memoryEnabled'] as bool? ?? enabled,
      memoryExtractionMode: json['memoryExtractionMode'] == 'interval' ? 'interval' : 'rounds',
      memoryExtractionRounds: (json['memoryExtractionRounds'] as int? ?? 10).clamp(1, 100),
      memoryExtractionIntervalMin: (json['memoryExtractionIntervalMin'] as int? ?? 10).clamp(1, 1440),
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
    Object? ttsServiceId = _unset,
    bool? humanScoreEnabled,
    int? humanScoreThreshold,
    bool? memoryEnabled,
    String? memoryExtractionMode,
    int? memoryExtractionRounds,
    int? memoryExtractionIntervalMin,
  }) {
    return AlivenessConfig(
      enabled: enabled ?? this.enabled,
      bufferMinSec: bufferMinSec ?? this.bufferMinSec,
      bufferMaxSec: bufferMaxSec ?? this.bufferMaxSec,
      maxBubbles: maxBubbles ?? this.maxBubbles,
      bubbleDelayMinMs: bubbleDelayMinMs ?? this.bubbleDelayMinMs,
      bubbleDelayMaxMs: bubbleDelayMaxMs ?? this.bubbleDelayMaxMs,
      laziness: laziness ?? this.laziness,
      forgettingHalfLifeDays:
          forgettingHalfLifeDays ?? this.forgettingHalfLifeDays,
      proactiveEnabled: proactiveEnabled ?? this.proactiveEnabled,
      proactiveCooldownMin: proactiveCooldownMin ?? this.proactiveCooldownMin,
      proactiveDailyLimit: proactiveDailyLimit ?? this.proactiveDailyLimit,
      quietHours: quietHours ?? this.quietHours,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      // sentinel 模式：允许显式传 null 恢复"跟随全局"
      ttsServiceId: ttsServiceId == _unset
          ? this.ttsServiceId
          : ttsServiceId as String?,
      humanScoreEnabled: humanScoreEnabled ?? this.humanScoreEnabled,
      humanScoreThreshold: humanScoreThreshold ?? this.humanScoreThreshold,
      memoryEnabled: memoryEnabled ?? this.memoryEnabled,
      memoryExtractionMode: memoryExtractionMode ?? this.memoryExtractionMode,
      memoryExtractionRounds: memoryExtractionRounds ?? this.memoryExtractionRounds,
      memoryExtractionIntervalMin: memoryExtractionIntervalMin ?? this.memoryExtractionIntervalMin,
    );
  }
}
