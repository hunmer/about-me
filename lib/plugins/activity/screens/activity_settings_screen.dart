import 'dart:async';
import 'package:get/get.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/adaptive_switch.dart';
import 'package:aboutme/plugins/activity/activity_plugin.dart';
import 'package:aboutme/plugins/activity/models/activity_record.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';
import 'package:aboutme/plugins/tts/models/tts_service_type.dart';

/// 活动插件设置页面
class ActivitySettingsScreen extends StatefulWidget {
  const ActivitySettingsScreen({super.key});

  @override
  State<ActivitySettingsScreen> createState() => _ActivitySettingsScreenState();
}

class _ActivitySettingsScreenState extends State<ActivitySettingsScreen> {
  bool _isNotificationEnabled = false;
  bool _isLoading = true;

  // 最近活动信息
  ActivityRecord? _lastActivity;

  // 通知设置
  int _minimumReminderInterval = 30; // 默认30分钟
  int _updateInterval = 1; // 默认1分钟

  // TTS 播报设置
  bool _isTTSAnnouncementEnabled = false;
  int _ttsIntervalSeconds = 60; // 默认60秒
  final TextEditingController _intervalInputController =
      TextEditingController();
  // 与 TTSAnnouncementSettings 默认模板保持一致（真实模板由 _loadTTSAnnouncementSettings 加载）
  final TextEditingController _ttsTextController = TextEditingController(
    text: '已超过 {unrecorded_time} 分钟未记录活动',
  );
  String? _selectedVariable;
  bool _checkOnlyWorkHours = false;
  int _workHoursStart = 9;
  int _workHoursEnd = 18;

  // TTS 服务列表
  List<dynamic> _ttsServices = [];
  bool _isLoadingTTSServices = true;
  String? _selectedTTSServiceId;

  // 震动反馈设置
  bool _enableHapticFeedback = true;

  // 语音缓存
  bool _isGeneratingCache = false;
  bool _cacheReady = false;
  int _cacheDone = 0;
  int _cacheTotal = 0;
  int _cacheGapMs = 150;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadLastActivityInfo();
    _loadTTSAnnouncementSettings();
    _loadTTSServices();

    // 定时更新时间差
    Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateTimeSinceLast();
    });
  }

  Future<void> _loadSettings() async {
    try {
      final plugin = ActivityPlugin.instance;
      final isEnabled = plugin.isNotificationEnabled();
      final minInterval = await plugin.getMinimumReminderInterval();
      final updateInt = await plugin.getUpdateInterval();

      if (mounted) {
        setState(() {
          _isNotificationEnabled = isEnabled;
          _minimumReminderInterval = minInterval;
          _updateInterval = updateInt;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载设置失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLastActivityInfo() async {
    try {
      final plugin = ActivityPlugin.instance;
      final service = plugin.activityService;

      // 获取今天的活动
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final activities = await service.getActivitiesForDate(today);

      ActivityRecord? lastActivity;
      if (activities.isNotEmpty) {
        // 按结束时间排序，取最新的
        activities.sort((a, b) => b.endTime.compareTo(a.endTime));
        lastActivity = activities.first;
      } else {
        // 如果今天没有活动，检查昨天
        final yesterday = today.subtract(const Duration(days: 1));
        final yesterdayActivities = await service.getActivitiesForDate(
          yesterday,
        );
        if (yesterdayActivities.isNotEmpty) {
          yesterdayActivities.sort((a, b) => b.endTime.compareTo(a.endTime));
          lastActivity = yesterdayActivities.first;
        }
      }

      if (mounted) {
        setState(() {
          _lastActivity = lastActivity;
        });
        _updateTimeSinceLast();
      }
    } catch (e) {
      debugPrint('加载最近活动信息失败: $e');
    }
  }

  void _updateTimeSinceLast() {
    if (_lastActivity == null) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final now = DateTime.now();
    final diff = now.difference(_lastActivity!.endTime);

    if (diff.inDays > 0) {
    } else if (diff.inHours > 0) {
    } else {}

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleNotification(bool value) async {
    try {
      final plugin = ActivityPlugin.instance;

      if (value) {
        await plugin.enableActivityNotification();
        if (!mounted) return;
        toastService.showToast('activity_notificationEnabled'.tr);
      } else {
        await plugin.disableActivityNotification();
        if (!mounted) return;
        toastService.showToast('activity_notificationDisabled'.tr);
      }

      setState(() {
        _isNotificationEnabled = value;
      });
    } catch (e) {
      if (mounted) {
        toastService.showToast('${'activity_operationFailed'.tr}: $e');
      }
      // 恢复开关状态
      setState(() {
        _isNotificationEnabled = !value;
      });
    }
  }

  Future<void> _updateMinimumReminderInterval(int value) async {
    try {
      await ActivityPlugin.instance.setMinimumReminderInterval(value);
      setState(() {
        _minimumReminderInterval = value;
      });
    } catch (e) {
      debugPrint('更新最小提醒间隔失败: $e');
    }
  }

  Future<void> _updateUpdateInterval(int value) async {
    try {
      await ActivityPlugin.instance.setUpdateInterval(value);
      setState(() {
        _updateInterval = value;
      });
    } catch (e) {
      debugPrint('更新通知更新频率失败: $e');
    }
  }

  // ==================== TTS 播报设置 ====================

  Future<void> _loadTTSServices() async {
    try {
      // 获取 TTS 插件
      final plugin = PluginManager.instance.getPlugin('tts');
      if (plugin == null) {
        debugPrint('TTS 插件未安装');
        return;
      }

      final ttsPlugin = plugin as TTSPlugin;
      final services = await ttsPlugin.managerService.getAllServices();
      final defaultService = await ttsPlugin.managerService.getDefaultService();
      final selectedId =
          await ActivityPlugin.instance.getTTSAnnouncementServiceId();

      if (mounted) {
        setState(() {
          _ttsServices = services;
          _isLoadingTTSServices = false;
          _selectedTTSServiceId = selectedId ?? defaultService?.id;
        });
        _refreshCacheStatus();
      }
    } catch (e) {
      debugPrint('加载 TTS 服务列表失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingTTSServices = false;
        });
      }
    }
  }

  Future<void> _loadTTSAnnouncementSettings() async {
    try {
      final plugin = ActivityPlugin.instance;
      final isEnabled = plugin.isTTSAnnouncementEnabled();
      final interval = await plugin.getTTSAnnouncementInterval();
      final text = await plugin.getTTSAnnouncementText();
      final workHours = await plugin.getWorkHoursSettings();
      final hapticFeedback = await plugin.getTTSAnnouncementHapticFeedback();
      final cacheGap = await plugin.getTTSAnnouncementCacheGap();

      if (mounted) {
        setState(() {
          _isTTSAnnouncementEnabled = isEnabled;
          _ttsIntervalSeconds = interval;
          _intervalInputController.text = interval.toString();
          _ttsTextController.text = text;
          _checkOnlyWorkHours = workHours['checkOnlyWorkHours'] as bool;
          _workHoursStart = workHours['workHoursStart'] as int;
          _workHoursEnd = workHours['workHoursEnd'] as int;
          _enableHapticFeedback = hapticFeedback;
          _cacheGapMs = cacheGap;
        });
        // 模板就绪后刷新缓存状态（与 _loadTTSServices 并发，避免早于模板加载误判）
        _refreshCacheStatus();
      }
    } catch (e) {
      debugPrint('加载播报设置失败: $e');
    }
  }

  Future<void> _toggleTTSAnnouncement(bool value) async {
    try {
      final plugin = ActivityPlugin.instance;

      if (value) {
        await plugin.enableTTSAnnouncement();
        if (!mounted) return;
        toastService.showToast('播报服务已启用');
      } else {
        await plugin.disableTTSAnnouncement();
        if (!mounted) return;
        toastService.showToast('播报服务已禁用');
      }

      setState(() {
        _isTTSAnnouncementEnabled = value;
      });
    } catch (e) {
      if (mounted) {
        toastService.showToast('操作失败: $e');
      }
      // 恢复开关状态
      setState(() {
        _isTTSAnnouncementEnabled = !value;
      });
    }
  }

  /// 播报间隔预设（秒）
  static const List<int> _intervalPresets = [10, 30, 60, 300, 600, 1800];

  /// 间隔秒数格式化为显示文本
  String _formatIntervalLabel(int seconds) {
    if (seconds >= 60 && seconds % 60 == 0) {
      return '${seconds ~/ 60} 分钟';
    }
    return '$seconds 秒';
  }

  Future<void> _updateTTSAnnouncementInterval(int seconds) async {
    try {
      await ActivityPlugin.instance.setTTSAnnouncementInterval(seconds);
      setState(() {
        _ttsIntervalSeconds = seconds;
        _intervalInputController.text = seconds.toString();
      });
    } catch (e) {
      debugPrint('更新播报间隔失败: $e');
    }
  }

  /// 应用自定义间隔输入
  Future<void> _applyCustomInterval() async {
    final seconds = int.tryParse(_intervalInputController.text.trim());
    if (seconds == null || seconds < 10 || seconds > 3600) {
      toastService.showToast('请输入 10-3600 之间的秒数');
      return;
    }
    await _updateTTSAnnouncementInterval(seconds);
    toastService.showToast('播报间隔已更新为 ${_formatIntervalLabel(seconds)}');
  }

  Future<void> _updateTTSText() async {
    try {
      await ActivityPlugin.instance.setTTSAnnouncementText(
        _ttsTextController.text,
      );
      toastService.showToast('播报文本已更新');
      _refreshCacheStatus();
    } catch (e) {
      toastService.showToast('更新失败: $e');
    }
  }

  void _insertVariable(String variable) {
    final text = _ttsTextController.text;
    final selection = _ttsTextController.selection;
    final newText = text.replaceRange(selection.start, selection.end, variable);
    _ttsTextController.text = newText;
    _ttsTextController.selection = TextSelection.collapsed(
      offset: selection.start + variable.length,
    );
  }

  Future<void> _updateWorkHoursSettings() async {
    try {
      await ActivityPlugin.instance.setWorkHoursSettings(
        checkOnlyWorkHours: _checkOnlyWorkHours,
        workHoursStart: _workHoursStart,
        workHoursEnd: _workHoursEnd,
      );
      toastService.showToast('工作时间设置已更新');
    } catch (e) {
      toastService.showToast('更新失败: $e');
    }
  }

  Future<void> _testTTSSpeak() async {
    try {
      await ActivityPlugin.instance.ttsAnnouncementService.testSpeak();
      toastService.showToast('测试播报已发送');
    } catch (e) {
      toastService.showToast('测试播报失败: $e');
    }
  }

  Future<void> _updateTTSServiceId(String? serviceId) async {
    try {
      await ActivityPlugin.instance.setTTSAnnouncementServiceId(serviceId);
      setState(() {
        _selectedTTSServiceId = serviceId;
      });
      _refreshCacheStatus();
    } catch (e) {
      toastService.showToast('设置失败: $e');
    }
  }

  // ==================== 语音缓存 ====================

  /// 刷新缓存可用状态（模板或服务变化后缓存会失效）
  Future<void> _refreshCacheStatus() async {
    try {
      final ready = await ActivityPlugin.instance.voiceCacheService
          .isCacheReady(_ttsTextController.text, _selectedTTSServiceId);
      if (mounted) {
        setState(() {
          _cacheReady = ready;
        });
      }
    } catch (e) {
      debugPrint('读取语音缓存状态失败: $e');
    }
  }

  /// 一键生成语音缓存：数字 0-10、时间单位及模板固定文本
  Future<void> _generateVoiceCache() async {
    if (_isGeneratingCache) return;

    final template = _ttsTextController.text;
    if (template.trim().isEmpty) {
      toastService.showToast('请先输入播报文本模板');
      return;
    }

    setState(() {
      _isGeneratingCache = true;
      _cacheDone = 0;
      _cacheTotal = 0;
    });
    try {
      // 先保存模板，确保缓存与生效模板一致
      await ActivityPlugin.instance.setTTSAnnouncementText(template);

      final error = await ActivityPlugin.instance.voiceCacheService.generate(
        template: template,
        serviceId: _selectedTTSServiceId,
        onProgress: (done, total) {
          if (mounted) {
            setState(() {
              _cacheDone = done;
              _cacheTotal = total;
            });
          }
        },
      );
      if (!mounted) return;
      toastService.showToast(error ?? '语音缓存生成完成');
    } catch (e) {
      if (mounted) {
        toastService.showToast('生成语音缓存失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingCache = false;
        });
      }
      await _refreshCacheStatus();
    }
  }

  @override
  void dispose() {
    _ttsTextController.dispose();
    _intervalInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('设置')),
      // DS 组件内部取 AppTheme，整个 body 包一层桥
      body: DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);

            return _buildBody(context, theme);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppThemeData theme) {
    return _isLoading
        ? Center(child: DSLoadingDots(color: ActivityPlugin.instance.color))
        : ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 通知设置区域 - 仅在移动端平台显示
            if (UniversalPlatform.isIOS || UniversalPlatform.isAndroid)
              DSCard(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        DsIcon(
                          DsIconKind.bell,
                          color: ActivityPlugin.instance.color,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'activity_notificationSettings'.tr,
                          style: DsTypography.heading.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '在通知栏常驻显示最后记录的活动、时间和快捷添加按钮',
                      style: DsTypography.body.copyWith(color: theme.textSub),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'activity_enableNotificationBar'.tr,
                          style: DsTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.text,
                          ),
                        ),
                        AdaptiveSwitch(
                          value: _isNotificationEnabled,
                          onChanged: _toggleNotification,
                          activeColor: ActivityPlugin.instance.color,
                        ),
                      ],
                    ),
                    // 通知时间设置
                    if (_isNotificationEnabled &&
                        UniversalPlatform.isAndroid) ...[
                      const SizedBox(height: 24),
                      Divider(height: 1, color: theme.stroke),
                      const SizedBox(height: 16),

                      // 最小提醒间隔
                      Text(
                        'activity_minimumReminderInterval'.tr,
                        style: DsTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'activity_minimumReminderIntervalDesc'.tr,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DSSlider(
                              // 5-120 分钟归一化
                              value: (_minimumReminderInterval - 5) / (120 - 5),
                              activeColor: ActivityPlugin.instance.color,
                              onChanged: (value) {
                                _updateMinimumReminderInterval(
                                  (value * (120 - 5) + 5).round(),
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              'activity_minutesUnit'.trParams({
                                'minutes': '$_minimumReminderInterval',
                              }),
                              style: DsTypography.body.copyWith(
                                fontWeight: FontWeight.bold,
                                color: ActivityPlugin.instance.color,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 通知更新频率
                      Text(
                        'activity_updateInterval'.tr,
                        style: DsTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'activity_updateIntervalDesc'.tr,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DSSlider(
                              // 1-10 分钟归一化
                              value: (_updateInterval - 1) / (10 - 1),
                              activeColor: ActivityPlugin.instance.color,
                              onChanged: (value) {
                                _updateUpdateInterval(
                                  (value * (10 - 1) + 1).round(),
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              'activity_minutesUnit'.trParams({
                                'minutes': '$_updateInterval',
                              }),
                              style: DsTypography.body.copyWith(
                                fontWeight: FontWeight.bold,
                                color: ActivityPlugin.instance.color,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

            // TTS 播报设置区域
            DSCard(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      DsIcon(
                        DsIconKind.mic,
                        color: ActivityPlugin.instance.color,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '语音播报提醒',
                          style: DsTypography.heading.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.text,
                          ),
                        ),
                      ),
                      AdaptiveSwitch(
                        value: _isTTSAnnouncementEnabled,
                        onChanged: _toggleTTSAnnouncement,
                        activeColor: ActivityPlugin.instance.color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '当超过指定时间未记录活动时，通过语音播报提醒',
                    style: DsTypography.body.copyWith(color: theme.textSub),
                  ),

                  // 播报设置
                  if (_isTTSAnnouncementEnabled) ...[
                    const SizedBox(height: 24),
                    Divider(height: 1, color: theme.stroke),
                    const SizedBox(height: 16),

                    // TTS 服务选择
                    Text(
                      'TTS 语音服务',
                      style: DsTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isLoadingTTSServices
                        ? Center(
                          child: DSLoadingDots(
                            color: ActivityPlugin.instance.color,
                          ),
                        )
                        : _ttsServices.isEmpty
                        ? Text(
                          '没有可用的 TTS 服务',
                          style: DsTypography.body.copyWith(
                            color: theme.textSub,
                          ),
                        )
                        // 选项行带图标/默认角标，DS 暂不支持自定义行选项，保留 Material 下拉
                        : DropdownButtonFormField<String>(
                          value: _selectedTTSServiceId,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: '选择 TTS 服务',
                          ),
                          items:
                              _ttsServices.where((s) => s.isEnabled).map((
                                service,
                              ) {
                                final config = service;
                                return DropdownMenuItem<String>(
                                  value: config.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        config.type == TTSServiceType.system
                                            ? Icons.record_voice_over
                                            : Icons.cloud,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(config.name),
                                      if (config.isDefault) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.success,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            '默认',
                                            style: DsTypography.caption
                                                .copyWith(
                                                  color: theme.onSuccess,
                                                  fontSize: 10,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                          onChanged: (value) {
                            _updateTTSServiceId(value);
                          },
                        ),
                    const SizedBox(height: 16),

                    // 语音缓存（离线拼接播报）
                    Row(
                      children: [
                        DsIcon(
                          DsIconKind.download,
                          color: ActivityPlugin.instance.color,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '语音缓存',
                          style: DsTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.text,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _cacheReady ? '已生成，离线拼接播报生效中' : '未生成，播报将在线合成',
                            style: DsTypography.caption.copyWith(
                              color: _cacheReady ? theme.success : theme.textSub,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '预生成 0-10 数字、天/时/分/秒单位及模板固定文本语音，'
                      '播报时本地智能拼接，{unrecorded_time} 无需在线生成；'
                      '修改模板或切换服务后需重新生成',
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DSButton(
                      label: _isGeneratingCache
                          ? (_cacheTotal > 0
                                ? '生成中 $_cacheDone/$_cacheTotal'
                                : '生成中...')
                          : '一键生成语音缓存',
                      icon: _isGeneratingCache
                          ? DsIconKind.refresh
                          : DsIconKind.download,
                      onPressed: _isGeneratingCache ? null : _generateVoiceCache,
                    ),

                    // 拼接停顿
                    if (_cacheReady) ...[
                      const SizedBox(height: 16),
                      Text(
                        '拼接停顿',
                        style: DsTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '拼接播放时段与段之间的停顿时长',
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DSSlider(
                              // 0-500 毫秒归一化
                              value: _cacheGapMs / 500,
                              activeColor: ActivityPlugin.instance.color,
                              onChanged: (value) {
                                setState(() {
                                  _cacheGapMs = (value * 500).round();
                                });
                                ActivityPlugin.instance
                                    .setTTSAnnouncementCacheGap(_cacheGapMs);
                              },
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              '$_cacheGapMs 毫秒',
                              style: DsTypography.body.copyWith(
                                fontWeight: FontWeight.bold,
                                color: ActivityPlugin.instance.color,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // 播报间隔
                    Text(
                      '未记录时间间隔',
                      style: DsTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '超过该时间未记录活动时播报提醒，两次播报至少间隔同样时长',
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final seconds in _intervalPresets)
                          DSButton(
                            label: _formatIntervalLabel(seconds),
                            size: DSButtonSize.sm,
                            variant: _ttsIntervalSeconds == seconds
                                ? DSButtonVariant.primary
                                : DSButtonVariant.outline,
                            onPressed: () =>
                                _updateTTSAnnouncementInterval(seconds),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DSInput(
                            controller: _intervalInputController,
                            hint: '自定义间隔（秒，10-3600）',
                          ),
                        ),
                        const SizedBox(width: 8),
                        DSButton(
                          label: '应用',
                          size: DSButtonSize.sm,
                          variant: DSButtonVariant.outline,
                          icon: DsIconKind.check,
                          onPressed: _applyCustomInterval,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 播报文本
                    DSInput(
                      controller: _ttsTextController,
                      maxLines: 3,
                      hint: '输入播报文本模板',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DSSelect<String>(
                            value: _selectedVariable,
                            hint: '插入变量',
                            items: const [
                              DSSelectItem(
                                value: '{date}',
                                label: '{date} - 日期',
                              ),
                              DSSelectItem(
                                value: '{last_activity}',
                                label: '{last_activity} - 上次活动',
                              ),
                              DSSelectItem(
                                value: '{unrecorded_time}',
                                label: '{unrecorded_time} - 未记录时间',
                              ),
                              DSSelectItem(
                                value: '{time}',
                                label: '{time} - 时间',
                              ),
                              DSSelectItem(
                                value: '{weekday}',
                                label: '{weekday} - 星期',
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                _insertVariable(value);
                                setState(() {
                                  _selectedVariable = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        DSButton(
                          label: '保存',
                          icon: DsIconKind.check,
                          onPressed: _updateTTSText,
                        ),
                        const SizedBox(width: 8),
                        DSButton(
                          label: '测试',
                          variant: DSButtonVariant.outline,
                          icon: DsIconKind.play,
                          onPressed: _testTTSSpeak,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    // 工作时间限制
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '仅在工作时间检查',
                          style: DsTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.text,
                          ),
                        ),
                        AdaptiveSwitch(
                          value: _checkOnlyWorkHours,
                          onChanged: (value) {
                            setState(() {
                              _checkOnlyWorkHours = value;
                            });
                            _updateWorkHoursSettings();
                          },
                          activeColor: ActivityPlugin.instance.color,
                        ),
                      ],
                    ),

                    if (_checkOnlyWorkHours) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '开始时间',
                                  style: DsTypography.caption.copyWith(
                                    color: theme.textSub,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                DSSelect<int>(
                                  value: _workHoursStart,
                                  items:
                                      List.generate(24, (i) => i)
                                          .map(
                                            (hour) => DSSelectItem(
                                              value: hour,
                                              label: '$hour:00',
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _workHoursStart = value;
                                      });
                                      _updateWorkHoursSettings();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '结束时间',
                                  style: DsTypography.caption.copyWith(
                                    color: theme.textSub,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                DSSelect<int>(
                                  value: _workHoursEnd,
                                  items:
                                      List.generate(24, (i) => i)
                                          .map(
                                            (hour) => DSSelectItem(
                                              value: hour,
                                              label: '$hour:00',
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _workHoursEnd = value;
                                      });
                                      _updateWorkHoursSettings();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // 震动反馈开关
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // DS 暂无震动类图标，保留 Material 图标
                            Icon(
                              Icons.vibration,
                              size: 20,
                              color: ActivityPlugin.instance.color,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '震动反馈',
                              style: DsTypography.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.text,
                              ),
                            ),
                          ],
                        ),
                        AdaptiveSwitch(
                          value: _enableHapticFeedback,
                          onChanged: (value) {
                            setState(() {
                              _enableHapticFeedback = value;
                            });
                            ActivityPlugin.instance
                                .setTTSAnnouncementHapticFeedback(value);
                          },
                          activeColor: ActivityPlugin.instance.color,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
  }
}
