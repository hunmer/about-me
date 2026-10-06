import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/activity_record.dart';
import '../services/activity_service.dart';
import '../services/activity_voice_cache_service.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';

/// 活动后台播报服务
///
/// 当检测到未记录时间超过指定间隔时，播报提示语音
/// 支持占位符：{date}, {last_activity}, {unrecorded_time}
///
/// 配置了语音缓存时优先本地智能拼接播报（固定文本 + 数字 + 单位），
/// 缓存不可用则回退在线合成。
class ActivityTTSAnnouncementService extends ChangeNotifier {
  /// 活动服务
  final ActivityService activityService;

  /// TTS 插件
  final TTSPlugin ttsPlugin;

  /// 语音缓存服务（可选，为空时始终在线合成）
  final ActivityVoiceCacheService? voiceCache;

  ActivityTTSAnnouncementService({
    required this.activityService,
    required this.ttsPlugin,
    this.voiceCache,
  });

  /// 定时检查器
  Timer? _checkTimer;

  /// 是否正在运行
  bool _isActive = false;

  /// 使用的 TTS 服务 ID
  String? _serviceId;

  /// 未记录时间间隔（秒）
  int _unrecordedIntervalSeconds = 60;

  /// 播报文本模板（与 TTSAnnouncementSettings 默认值保持一致）
  String _textTemplate = '已超过 {unrecorded_time} 分钟未记录活动';

  /// 是否只在工作时间检查
  bool _checkOnlyWorkHours = false;

  /// 工作时间开始（小时）
  int _workHoursStart = 9;

  /// 工作时间结束（小时）
  int _workHoursEnd = 18;

  /// 是否启用震动反馈
  bool _enableHapticFeedback = true;

  /// 语音缓存拼接播放时段间停顿（毫秒）
  int _cacheGapMs = 150;

  /// 最近一次检查时间
  DateTime? _lastCheckTime;

  /// 最后一次播报时间
  DateTime? _lastAnnouncementTime;

  /// 最近的活动记录
  ActivityRecord? _lastActivity;

  /// 是否正在运行
  bool get isActive => _isActive;

  /// 使用的 TTS 服务 ID
  String? get serviceId => _serviceId;

  /// 未记录时间间隔（秒）
  int get unrecordedIntervalSeconds => _unrecordedIntervalSeconds;

  /// 播报文本模板
  String get textTemplate => _textTemplate;

  /// 是否只在工作时间检查
  bool get checkOnlyWorkHours => _checkOnlyWorkHours;

  /// 工作时间开始（小时）
  int get workHoursStart => _workHoursStart;

  /// 工作时间结束（小时）
  int get workHoursEnd => _workHoursEnd;

  /// 是否启用震动反馈
  bool get enableHapticFeedback => _enableHapticFeedback;

  /// 语音缓存拼接播放时段间停顿（毫秒）
  int get cacheGapMs => _cacheGapMs;

  /// 最近一次检查时间
  DateTime? get lastCheckTime => _lastCheckTime;

  /// 最后一次播报时间
  DateTime? get lastAnnouncementTime => _lastAnnouncementTime;

  /// 最近的未记录时间（分钟）
  int? get unrecordedMinutes {
    if (_lastActivity == null) return null;
    final now = DateTime.now();
    return now.difference(_lastActivity!.endTime).inMinutes;
  }

  /// 启动播报服务
  Future<void> start() async {
    if (_isActive) {
      debugPrint('[ActivityTTSAnnouncement] 服务已在运行');
      return;
    }

    _isActive = true;
    _lastCheckTime = DateTime.now();

    // 启动定时检查器（每 10 秒检查一次，支持秒级间隔）
    _checkTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkAndAnnounce(),
    );

    debugPrint('[ActivityTTSAnnouncement] 服务已启动');
    notifyListeners();
  }

  /// 停止播报服务
  Future<void> stop() async {
    if (!_isActive) return;

    _isActive = false;
    _checkTimer?.cancel();
    _checkTimer = null;

    // 清空播报时间记录，避免重启后立即播报
    _lastAnnouncementTime = null;
    _lastCheckTime = null;

    // 停止本地缓存拼接播放
    await voiceCache?.stopPlayback();

    // 停止当前的 TTS 播放
    try {
      await ttsPlugin.stop();
    } catch (e) {
      debugPrint('[ActivityTTSAnnouncement] 停止 TTS 失败: $e');
    }

    debugPrint('[ActivityTTSAnnouncement] 服务已停止');
    notifyListeners();
  }

  /// 检查并播报
  Future<void> _checkAndAnnounce() async {
    if (!_isActive) return;

    _lastCheckTime = DateTime.now();

    try {
      // 检查是否在工作时间内（如果启用了工作时间限制）
      if (_checkOnlyWorkHours && !_isWorkHours()) {
        debugPrint('[ActivityTTSAnnouncement] 非工作时间，跳过检查');
        return;
      }

      // 获取最近的活动
      await _updateLastActivity();

      // 计算未记录时间（秒；如果没有活动，从今天 0 点开始计算）
      final now = DateTime.now();
      final unrecordedSeconds =
          _lastActivity == null
              ? now.difference(DateTime(now.year, now.month, now.day)).inSeconds
              : now.difference(_lastActivity!.endTime).inSeconds;

      // 检查是否超过设定间隔
      if (unrecordedSeconds >= _unrecordedIntervalSeconds) {
        // 检查距离上次播报是否已超过设定间隔（避免重复播报）
        if (_lastAnnouncementTime != null) {
          final timeSinceLastAnnouncement =
              now.difference(_lastAnnouncementTime!).inSeconds;
          if (timeSinceLastAnnouncement < _unrecordedIntervalSeconds) {
            debugPrint(
              '[ActivityTTSAnnouncement] 距离上次播报仅 $timeSinceLastAnnouncement 秒，跳过本次播报',
            );
            return;
          }
        }

        // 播报（优先本地缓存拼接，回退在线合成）
        await _announce();

        _lastAnnouncementTime = DateTime.now();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ActivityTTSAnnouncement] 检查失败: $e');
    }
  }

  /// 更新最近的活动记录
  Future<void> _updateLastActivity() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final activities = await activityService.getActivitiesForDate(today);

      if (activities.isNotEmpty) {
        // 按结束时间排序，取最新的
        activities.sort((a, b) => b.endTime.compareTo(a.endTime));
        _lastActivity = activities.first;
      } else {
        // 如果今天没有活动，检查昨天
        final yesterday = today.subtract(const Duration(days: 1));
        final yesterdayActivities = await activityService.getActivitiesForDate(
          yesterday,
        );
        if (yesterdayActivities.isNotEmpty) {
          yesterdayActivities.sort((a, b) => b.endTime.compareTo(a.endTime));
          _lastActivity = yesterdayActivities.first;
        }
      }
    } catch (e) {
      debugPrint('[ActivityTTSAnnouncement] 获取最近活动失败: $e');
    }
  }

  /// 替换文本中的占位符
  String _replacePlaceholders(String template) {
    final now = DateTime.now();
    String result = template;

    // {date} - 当前日期
    result = result.replaceAll('{date}', DateFormat('yyyy年MM月dd日').format(now));

    // {last_activity} - 最近的活动标题或标签
    if (_lastActivity != null) {
      // 如果有标签，优先显示标签
      if (_lastActivity!.tags.isNotEmpty) {
        final tagsStr = _lastActivity!.tags.join('、');
        result = result.replaceAll('{last_activity}', tagsStr);
      } else {
        // 没有标签，显示标题
        result = result.replaceAll('{last_activity}', _lastActivity!.title);
      }
    } else {
      result = result.replaceAll('{last_activity}', '无');
    }

    // {unrecorded_time} - 未记录时间（实时计算，显示小时制）
    String unrecordedTimeStr = _formatDuration(_lastActivity);
    result = result.replaceAll('{unrecorded_time}', unrecordedTimeStr);

    // {time} - 当前时间
    result = result.replaceAll('{time}', DateFormat('HH:mm').format(now));

    // {weekday} - 星期
    final weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    result = result.replaceAll('{weekday}', weekDays[now.weekday - 1]);

    return result;
  }

  /// 计算当前未记录分钟数
  ///
  /// 如果没有活动，从今天 0 点开始计算
  int _currentUnrecordedMinutes() {
    final now = DateTime.now();
    if (_lastActivity == null) {
      final todayStart = DateTime(now.year, now.month, now.day);
      return now.difference(todayStart).inMinutes;
    }
    return now.difference(_lastActivity!.endTime).inMinutes;
  }

  /// 格式化时长文本
  ///
  /// 层级：分钟 -> 小时（满 60 分）-> 天（满 24 时）-> 月（满 30 天）
  String _formatDuration(ActivityRecord? activity) {
    final minutes = _currentUnrecordedMinutes();

    if (minutes < 60) {
      return '$minutes 分钟';
    } else if (minutes < 60 * 24) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins > 0) {
        return '$hours 小时 $mins 分钟';
      } else {
        return '$hours 小时';
      }
    } else {
      final totalDays = minutes ~/ (60 * 24);
      if (totalDays < 30) {
        final hours = (minutes % (60 * 24)) ~/ 60;
        if (hours > 0) {
          return '$totalDays 天 $hours 小时';
        } else {
          return '$totalDays 天';
        }
      }
      final months = totalDays ~/ 30;
      final days = totalDays % 30;
      if (days > 0) {
        return '$months 月 $days 天';
      } else {
        return '$months 月';
      }
    }
  }

  /// 执行播报：优先本地缓存智能拼接，回退在线合成整句
  Future<void> _announce({bool isTest = false}) async {
    try {
      // 震动反馈
      if (_enableHapticFeedback) {
        HapticFeedback.heavyImpact();
      }

      if (await _speakWithCache(isTest: isTest)) {
        debugPrint('[ActivityTTSAnnouncement] 本地缓存拼接播报完成');
        return;
      }

      final text = _replacePlaceholders(_textTemplate);
      await ttsPlugin.speak(text, serviceId: _serviceId);
      debugPrint('[ActivityTTSAnnouncement] 播报: $text');
    } catch (e) {
      debugPrint('[ActivityTTSAnnouncement] 播报失败: $e');
    }
  }

  /// 使用本地语音缓存智能拼接播报
  ///
  /// 固定文本段与 {unrecorded_time}（数字 + 单位）播放缓存音频，
  /// 其它动态占位符（{date} 等）单独在线合成。返回 false 表示缓存不可用。
  Future<bool> _speakWithCache({bool isTest = false}) async {
    final cache = voiceCache;
    if (cache == null) return false;

    try {
      if (!await cache.isCacheReady(_textTemplate, _serviceId)) return false;

      final manifest = await cache.loadManifest();
      final ext = manifest?['ext'] as String?;
      if (ext == null) return false;

      final timeParts = cache.unrecordedTimeFileParts(
        _currentUnrecordedMinutes(),
        ext,
      );
      if (timeParts == null) return false;

      final segments = cache.parseTemplate(_textTemplate);
      final gap = Duration(milliseconds: _cacheGapMs);
      var segmentIndex = 0;
      for (final segment in segments) {
        if (!isTest && !_isActive) return false;

        switch (segment.type) {
          case VoiceSegmentType.fixed:
            // 固定文本段：播放预生成缓存（失败则跳过该段）
            await cache.playFiles(
              ['seg_${segmentIndex++}.$ext'],
              gap: gap,
              shouldContinue: () => isTest || _isActive,
            );
            break;
          case VoiceSegmentType.unrecordedTime:
            // 未记录时间：数字 + 单位拼接播放
            await cache.playFiles(
              timeParts,
              gap: gap,
              shouldContinue: () => isTest || _isActive,
            );
            break;
          case VoiceSegmentType.dynamic:
            // 动态占位符：替换后在线合成播报
            final text = _replacePlaceholders(segment.text);
            await ttsPlugin.speak(text, serviceId: _serviceId);
            break;
        }
      }
      return true;
    } catch (e) {
      debugPrint('[ActivityTTSAnnouncement] 缓存拼接播报失败: $e');
      return false;
    }
  }

  /// 更新配置
  Future<void> updateConfig({
    String? serviceId,
    int? unrecordedIntervalSeconds,
    String? textTemplate,
    bool? checkOnlyWorkHours,
    int? workHoursStart,
    int? workHoursEnd,
    bool? enableHapticFeedback,
    int? cacheGapMs,
  }) async {
    bool needRestart = false;

    if (serviceId != null && serviceId != _serviceId) {
      _serviceId = serviceId;
      needRestart = true;
    }

    if (unrecordedIntervalSeconds != null &&
        unrecordedIntervalSeconds != _unrecordedIntervalSeconds) {
      _unrecordedIntervalSeconds = unrecordedIntervalSeconds;
      needRestart = true;
    }

    if (textTemplate != null && textTemplate != _textTemplate) {
      _textTemplate = textTemplate;
    }

    if (checkOnlyWorkHours != null &&
        checkOnlyWorkHours != _checkOnlyWorkHours) {
      _checkOnlyWorkHours = checkOnlyWorkHours;
      needRestart = true;
    }

    if (workHoursStart != null && workHoursStart != _workHoursStart) {
      _workHoursStart = workHoursStart;
      needRestart = true;
    }

    if (workHoursEnd != null && workHoursEnd != _workHoursEnd) {
      _workHoursEnd = workHoursEnd;
      needRestart = true;
    }

    if (enableHapticFeedback != null &&
        enableHapticFeedback != _enableHapticFeedback) {
      _enableHapticFeedback = enableHapticFeedback;
    }

    if (cacheGapMs != null && cacheGapMs != _cacheGapMs) {
      _cacheGapMs = cacheGapMs;
    }

    if (needRestart && _isActive) {
      // 重启服务（原子操作：先停止，再启动）
      await _restart();
    }

    notifyListeners();
  }

  /// 重启服务（原子操作）
  Future<void> _restart() async {
    debugPrint('[ActivityTTSAnnouncement] 正在重启服务...');

    // 先停止服务（这会清空计时器和状态）
    await stop();

    // 等待一小段时间确保停止完成
    await Future.delayed(const Duration(milliseconds: 100));

    // 再启动服务
    await start();

    debugPrint('[ActivityTTSAnnouncement] 服务重启完成');
  }

  /// 手动刷新最近活动
  Future<void> refreshLastActivity() async {
    await _updateLastActivity();
    notifyListeners();
  }

  /// 测试播报一次
  Future<void> testSpeak() async {
    try {
      // 先刷新最近活动
      await _updateLastActivity();

      await _announce(isTest: true);
    } catch (e) {
      debugPrint('[ActivityTTSAnnouncement] 测试播报失败: $e');
      rethrow;
    }
  }

  /// 检查当前是否在工作时间内
  bool _isWorkHours() {
    final now = DateTime.now();
    final currentHour = now.hour;

    return currentHour >= _workHoursStart && currentHour < _workHoursEnd;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
