import 'package:flutter/foundation.dart';
import 'package:aboutme/core/storage/storage_manager.dart';

/// TTS 播报设置数据类
class TTSAnnouncementSettings {
  final bool isEnabled;
  final String? serviceId;

  /// 未记录时间间隔（秒）
  final int unrecordedIntervalSeconds;
  final String textTemplate;
  final bool checkOnlyWorkHours;
  final int workHoursStart;
  final int workHoursEnd;
  final bool enableHapticFeedback;

  /// 语音缓存拼接播放时，段与段之间的停顿（毫秒）
  final int cacheGapMs;

  const TTSAnnouncementSettings({
    this.isEnabled = false,
    this.serviceId,
    this.unrecordedIntervalSeconds = 60,
    this.textTemplate = '已超过 {unrecorded_time} 分钟未记录活动',
    this.checkOnlyWorkHours = false,
    this.workHoursStart = 9,
    this.workHoursEnd = 18,
    this.enableHapticFeedback = true,
    this.cacheGapMs = 150,
  });

  TTSAnnouncementSettings copyWith({
    bool? isEnabled,
    String? serviceId,
    int? unrecordedIntervalSeconds,
    String? textTemplate,
    bool? checkOnlyWorkHours,
    int? workHoursStart,
    int? workHoursEnd,
    bool? enableHapticFeedback,
    int? cacheGapMs,
  }) {
    return TTSAnnouncementSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      serviceId: serviceId ?? this.serviceId,
      unrecordedIntervalSeconds:
          unrecordedIntervalSeconds ?? this.unrecordedIntervalSeconds,
      textTemplate: textTemplate ?? this.textTemplate,
      checkOnlyWorkHours: checkOnlyWorkHours ?? this.checkOnlyWorkHours,
      workHoursStart: workHoursStart ?? this.workHoursStart,
      workHoursEnd: workHoursEnd ?? this.workHoursEnd,
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
      cacheGapMs: cacheGapMs ?? this.cacheGapMs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'serviceId': serviceId,
      'unrecordedIntervalSeconds': unrecordedIntervalSeconds,
      'textTemplate': textTemplate,
      'checkOnlyWorkHours': checkOnlyWorkHours,
      'workHoursStart': workHoursStart,
      'workHoursEnd': workHoursEnd,
      'enableHapticFeedback': enableHapticFeedback,
      'cacheGapMs': cacheGapMs,
    };
  }

  factory TTSAnnouncementSettings.fromJson(Map<String, dynamic> json) {
    // 兼容旧版分钟配置：无秒字段时按分钟换算
    final intervalSeconds = json['unrecordedIntervalSeconds'] as int? ??
        (json['unrecordedIntervalMinutes'] as int? ?? 5) * 60;
    return TTSAnnouncementSettings(
      isEnabled: json['isEnabled'] as bool? ?? false,
      serviceId: json['serviceId'] as String?,
      unrecordedIntervalSeconds: intervalSeconds,
      textTemplate: json['textTemplate'] as String? ?? '已超过 {unrecorded_time} 分钟未记录活动',
      checkOnlyWorkHours: json['checkOnlyWorkHours'] as bool? ?? false,
      workHoursStart: json['workHoursStart'] as int? ?? 9,
      workHoursEnd: json['workHoursEnd'] as int? ?? 18,
      enableHapticFeedback: json['enableHapticFeedback'] as bool? ?? true,
      cacheGapMs: json['cacheGapMs'] as int? ?? 150,
    );
  }
}

/// TTS 播报设置管理器
class TTSAnnouncementSettingsManager {
  final StorageManager _storage;
  final String _settingsFileName;

  TTSAnnouncementSettingsManager({
    required StorageManager storage,
    String settingsFileName = 'activity/tts_announcement_settings.json',
  })  : _storage = storage,
        _settingsFileName = settingsFileName;

  /// 读取设置
  Future<TTSAnnouncementSettings> load() async {
    try {
      final json = await _storage.read(_settingsFileName);
      if (json.isEmpty) {
        return const TTSAnnouncementSettings();
      }
      return TTSAnnouncementSettings.fromJson(json);
    } catch (e) {
      debugPrint('[TTSAnnouncementSettings] 加载设置失败: $e');
      return const TTSAnnouncementSettings();
    }
  }

  /// 保存设置
  Future<void> save(TTSAnnouncementSettings settings) async {
    try {
      await _storage.write(_settingsFileName, settings.toJson());
    } catch (e) {
      debugPrint('[TTSAnnouncementSettings] 保存设置失败: $e');
      rethrow;
    }
  }

  /// 合并更新设置
  Future<TTSAnnouncementSettings> update({
    bool? isEnabled,
    String? serviceId,
    int? unrecordedIntervalSeconds,
    String? textTemplate,
    bool? checkOnlyWorkHours,
    int? workHoursStart,
    int? workHoursEnd,
    bool? enableHapticFeedback,
    int? cacheGapMs,
  }) async {
    final current = await load();
    final updated = current.copyWith(
      isEnabled: isEnabled,
      serviceId: serviceId,
      unrecordedIntervalSeconds: unrecordedIntervalSeconds,
      textTemplate: textTemplate,
      checkOnlyWorkHours: checkOnlyWorkHours,
      workHoursStart: workHoursStart,
      workHoursEnd: workHoursEnd,
      enableHapticFeedback: enableHapticFeedback,
      cacheGapMs: cacheGapMs,
    );
    await save(updated);
    return updated;
  }
}
