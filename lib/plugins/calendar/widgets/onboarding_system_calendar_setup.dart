import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_platform/universal_platform.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 日历插件首次引导第二步：导入系统日历（仅移动端）
///
/// 主开关控制是否读取系统日历事件（开启时请求日历权限），
/// 子开关控制是否包含节假日日历。
/// 收集结果写入共享 [values]（importSystemCalendar / importHolidays），
/// 由插件在引导完成时统一应用
class OnboardingSystemCalendarSetup extends StatefulWidget {
  const OnboardingSystemCalendarSetup({super.key, required this.values});

  final Map<String, dynamic> values;

  @override
  State<OnboardingSystemCalendarSetup> createState() =>
      _OnboardingSystemCalendarSetupState();
}

class _OnboardingSystemCalendarSetupState
    extends State<OnboardingSystemCalendarSetup> {
  // 步骤页可能被 PageView 回收重建，已收集的选择优先从 values 恢复
  late bool _importSystemCalendar =
      (widget.values['importSystemCalendar'] as bool?) ?? true;
  late bool _importHolidays =
      (widget.values['importHolidays'] as bool?) ?? true;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    // 默认值同步写入 values，确保用户不操作直接完成时也按默认应用
    widget.values['importSystemCalendar'] = _importSystemCalendar;
    widget.values['importHolidays'] = _importHolidays;
  }

  /// 请求日历权限（device_calendar 已有权限时直接通过）
  Future<bool> _requestCalendarPermission() async {
    try {
      final existing = await DeviceCalendarPlugin().hasPermissions();
      if (existing.isSuccess && existing.data == true) return true;

      final permission = UniversalPlatform.isIOS
          ? Permission.calendarFullAccess
          : Permission.calendar;
      final status = await permission.request();
      if (status.isGranted) return true;
      if (status.isPermanentlyDenied) {
        Toast.error(
          'app_permissionRequiredInSettings'.trParams({
            'permission': 'app_permission_calendarTitle'.tr,
          }),
        );
      }
      return false;
    } catch (e) {
      debugPrint('OnboardingSystemCalendarSetup: 请求日历权限失败: $e');
      return false;
    }
  }

  Future<void> _toggleImportSystemCalendar(bool value) async {
    if (value) {
      final granted = await _requestCalendarPermission();
      if (!granted) {
        // 保持开关状态不变（保留用户意图），提示去系统设置授权，授权后即可生效
        if (mounted) setState(() => _permissionDenied = true);
        return;
      }
    }
    setState(() => _permissionDenied = false);
    setState(() {
      _importSystemCalendar = value;
      widget.values['importSystemCalendar'] = value;
    });
  }

  void _toggleImportHolidays(bool value) {
    setState(() {
      _importHolidays = value;
      widget.values['importHolidays'] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTile(
          theme: theme,
          title: 'calendar_importSystemCalendar'.tr,
          description: 'calendar_importSystemCalendarDesc'.tr,
          value: _importSystemCalendar,
          onChanged: _toggleImportSystemCalendar,
        ),
        SizedBox(height: theme.spacing.sm),
        // 节假日子选项：主开关关闭时置灰不可用
        Padding(
          padding: EdgeInsets.only(left: theme.spacing.lg),
          child: _buildTile(
            theme: theme,
            title: 'calendar_importHolidays'.tr,
            description: 'calendar_importHolidaysDesc'.tr,
            value: _importHolidays,
            onChanged: _importSystemCalendar ? _toggleImportHolidays : null,
          ),
        ),
        if (_permissionDenied) ...[
          SizedBox(height: theme.spacing.sm),
          Text(
            'calendar_systemCalendarPermissionDenied'.tr,
            style: DsTypography.caption.copyWith(color: theme.warning),
          ),
        ],
      ],
    );
  }

  Widget _buildTile({
    required AppThemeData theme,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final disabled = onChanged == null;
    return DSCard(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.sm,
      ),
      onTap: disabled ? null : () => onChanged(!value),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DsTypography.body.copyWith(
                    color: disabled ? theme.textSub : theme.text,
                  ),
                ),
                SizedBox(height: theme.spacing.xs),
                Text(
                  description,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ],
            ),
          ),
          SizedBox(width: theme.spacing.md),
          DSSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
