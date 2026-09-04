import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 情绪档位：值越高越开心，跨天回落到基线 [_CompanionDefaults.moodBaseline]
enum CompanionMoodTier {
  delighted('开心', '😊'),
  calm('平静', '😌'),
  neutral('一般', '😐'),
  gloomy('低落', '😔');

  const CompanionMoodTier(this.label, this.emoji);
  final String label;
  final String emoji;

  static CompanionMoodTier of(int mood) {
    if (mood >= 80) return delighted;
    if (mood >= 50) return calm;
    if (mood >= 30) return neutral;
    return gloomy;
  }
}

/// 精力档位：随离线时长衰减，只降到底线、不归零（不惩罚缺席）
enum CompanionEnergyTier {
  full('充沛'),
  good('良好'),
  tired('疲惫'),
  drained('没电了');

  const CompanionEnergyTier(this.label);
  final String label;

  static CompanionEnergyTier of(int energy) {
    if (energy >= 80) return full;
    if (energy >= 50) return good;
    if (energy >= 25) return tired;
    return drained;
  }
}

/// 好感度阶段：累计值只涨不跌，阶段用于解锁动作 / 对话等内容
enum CompanionAffectionTier {
  stranger('陌生', 0, 200),
  acquainted('熟悉', 200, 600),
  partner('伙伴', 600, 1200),
  bosom('挚友', 1200, 2400);

  const CompanionAffectionTier(this.label, this.min, this.max);
  final String label;
  final int min;
  final int max;

  static CompanionAffectionTier of(int affection) {
    for (final tier in CompanionAffectionTier.values.reversed) {
      if (affection >= tier.min) return tier;
    }
    return CompanionAffectionTier.stranger;
  }
}

class _CompanionDefaults {
  static const int mood = 85;
  static const int energy = 90;
  static const int affection = 240;
  static const int companionStreak = 1;
  static const int totalCompanionDays = 1;

  /// 新的一天开始时情绪回落的基线
  static const int moodBaseline = 70;

  /// 精力每小时衰减量，以及不会跌破的底线
  static const int energyDecayPerHour = 1;
  static const int energyFloor = 20;

  /// 好感度每日获取上限（防连点刷满）
  static const int affectionDailyCap = 20;
}

/// 小智的陪伴数值：情绪 / 精力 / 好感度 / 陪伴天数
///
/// 时间机制（离线结算，不跑定时器）：
/// * 精力按 [DateTime] 离线时长每小时 -1，最低 20；
/// * 跨天时情绪回落到基线、好感度每日上限重置；
/// * 陪伴天数按「当天有过互动」记：昨天有 → 连续 +1，断档 → 连续重置为 1。
///
/// 所有变化写入 SharedPreferences（键前缀 [prefsPrefix]），
/// 通过 [ChangeNotifier] 通知 UI。
class CompanionController extends ChangeNotifier {
  static const String prefsPrefix = 'companion.';

  int _mood = _CompanionDefaults.mood;
  int _energy = _CompanionDefaults.energy;
  int _affection = _CompanionDefaults.affection;
  int _affectionGainedToday = 0;
  int _companionStreak = _CompanionDefaults.companionStreak;
  int _totalCompanionDays = _CompanionDefaults.totalCompanionDays;
  DateTime _lastActiveAt = DateTime.now();
  String _stateDayKey = _dayKey(DateTime.now());
  String _lastCompanionDayKey = _dayKey(DateTime.now());
  bool _loaded = false;

  bool get isLoaded => _loaded;
  int get mood => _mood;
  int get energy => _energy;
  int get affection => _affection;
  CompanionMoodTier get moodTier => CompanionMoodTier.of(_mood);
  CompanionEnergyTier get energyTier => CompanionEnergyTier.of(_energy);
  CompanionAffectionTier get affectionTier => CompanionAffectionTier.of(
    _affection,
  );
  int get companionStreak => _companionStreak;
  int get totalCompanionDays => _totalCompanionDays;

  /// 今天剩余可获取的好感度
  int get affectionRemainingToday =>
      _CompanionDefaults.affectionDailyCap - _affectionGainedToday;

  /// 好感度在当前阶段内的进度 0.0–1.0（挚友满级后恒为 1.0）
  double get affectionTierProgress {
    final tier = affectionTier;
    final span = tier.max - tier.min;
    if (span <= 0) return 1;
    return ((_affection - tier.min) / span).clamp(0.0, 1.0);
  }

  /// 读取持久化状态并结算离线变化。在小组件挂载 / 应用回到前台时调用。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_loaded) {
      // 已加载过（应用回前台）：只重读动态字段做结算即可
      _lastActiveAt = DateTime.fromMillisecondsSinceEpoch(
        prefs.getInt('${prefsPrefix}lastActiveAt') ??
            DateTime.now().millisecondsSinceEpoch,
      );
      _settle();
      return;
    }
    _loaded = true;
    _mood = prefs.getInt('${prefsPrefix}mood') ?? _CompanionDefaults.mood;
    _energy = prefs.getInt('${prefsPrefix}energy') ?? _CompanionDefaults.energy;
    _affection =
        prefs.getInt('${prefsPrefix}affection') ??
        _CompanionDefaults.affection;
    _affectionGainedToday =
        prefs.getInt('${prefsPrefix}affectionGainedToday') ?? 0;
    _companionStreak =
        prefs.getInt('${prefsPrefix}companionStreak') ??
        _CompanionDefaults.companionStreak;
    _totalCompanionDays =
        prefs.getInt('${prefsPrefix}totalCompanionDays') ??
        _CompanionDefaults.totalCompanionDays;
    _lastActiveAt = DateTime.fromMillisecondsSinceEpoch(
      prefs.getInt('${prefsPrefix}lastActiveAt') ??
          DateTime.now().millisecondsSinceEpoch,
    );
    _stateDayKey =
        prefs.getString('${prefsPrefix}stateDayKey') ??
        _dayKey(DateTime.now());
    _lastCompanionDayKey =
        prefs.getString('${prefsPrefix}lastCompanionDayKey') ??
        _dayKey(DateTime.now());
    _settle();
  }

  /// 与角色的一次互动：情绪上涨、好感度上涨（受每日上限约束），
  /// 并把今天记为陪伴日（连续天数据此累计）。
  void recordInteraction({int moodGain = 2, int affectionGain = 2}) {
    if (moodGain != 0) {
      _mood = (_mood + moodGain).clamp(0, 100);
    }
    if (affectionGain > 0 && affectionRemainingToday > 0) {
      final effective = affectionGain.clamp(0, affectionRemainingToday);
      _affection += effective;
      _affectionGainedToday += effective;
    }
    _markCompanionDay();
    notifyListeners();
    _save();
  }

  /// 完成任务「喂」精力：直接补充，不做日上限
  void feedEnergy(int amount) {
    if (amount <= 0) return;
    _energy = (_energy + amount).clamp(0, 100);
    notifyListeners();
    _save();
  }

  /// 跨天与离线结算：精力衰减、情绪回落、好感度日上限重置、陪伴天数累计
  void _settle() {
    final now = DateTime.now();
    final todayKey = _dayKey(now);
    var changed = false;

    // 精力按离线小时数衰减，只降到底线
    final elapsedHours =
        now.difference(_lastActiveAt).inMinutes.clamp(0, 100000) / 60.0;
    if (elapsedHours >= 1) {
      final decayed =
          _energy -
          (elapsedHours * _CompanionDefaults.energyDecayPerHour).floor();
      final floored = decayed.clamp(
        _CompanionDefaults.energyFloor,
        100,
      );
      if (floored != _energy) {
        _energy = floored;
        changed = true;
      }
    }

    if (_stateDayKey != todayKey) {
      // 新的一天：情绪回落到基线，好感度每日上限重置
      if (_mood != _CompanionDefaults.moodBaseline) {
        _mood = _CompanionDefaults.moodBaseline;
        changed = true;
      }
      _affectionGainedToday = 0;
      _stateDayKey = todayKey;
      changed = true;
    }

    _lastActiveAt = now;
    if (changed) {
      notifyListeners();
      _save();
    } else {
      _save(); // 即便数值没变也要刷新 lastActiveAt
    }
  }

  /// 把今天记为陪伴日：昨天有互动 → 连续 +1；断档 → 连续重置为 1
  void _markCompanionDay() {
    final now = DateTime.now();
    final todayKey = _dayKey(now);
    if (_lastCompanionDayKey == todayKey) return;
    final yesterdayKey = _dayKey(now.subtract(const Duration(days: 1)));
    _companionStreak =
        _lastCompanionDayKey == yesterdayKey ? _companionStreak + 1 : 1;
    _totalCompanionDays += 1;
    _lastCompanionDayKey = todayKey;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${prefsPrefix}mood', _mood);
    await prefs.setInt('${prefsPrefix}energy', _energy);
    await prefs.setInt('${prefsPrefix}affection', _affection);
    await prefs.setInt('${prefsPrefix}affectionGainedToday', _affectionGainedToday);
    await prefs.setInt('${prefsPrefix}companionStreak', _companionStreak);
    await prefs.setInt('${prefsPrefix}totalCompanionDays', _totalCompanionDays);
    await prefs.setInt(
      '${prefsPrefix}lastActiveAt',
      _lastActiveAt.millisecondsSinceEpoch,
    );
    await prefs.setString('${prefsPrefix}stateDayKey', _stateDayKey);
    await prefs.setString(
      '${prefsPrefix}lastCompanionDayKey',
      _lastCompanionDayKey,
    );
  }

  static String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '-${date.month.toString().padLeft(2, '0')}'
      '-${date.day.toString().padLeft(2, '0')}';
}
