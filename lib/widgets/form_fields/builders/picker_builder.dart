import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import '../form_field_wrapper.dart';
import '../config.dart';
import '../date_picker_field.dart';
import '../time_picker_field.dart';
import '../date_range_field.dart';
import '../avatar_picker_field.dart';
import '../circle_icon_picker_field.dart';
import '../calendar_strip_picker_field.dart';
import '../image_picker_field.dart';
import '../location_picker_field.dart';

/// 构建日期选择框
Widget buildDateField(
  FormFieldConfig config,
  GlobalKey fieldKey,
  BuildContext context,
) {
  final extra = config.extra ?? {};

  return WrappedFormField(
    key: fieldKey,
    name: config.name,
    initialValue: config.initialValue as DateTime?,
    enabled: config.enabled,
    onChanged: config.onChanged,
    builder: (context, value, setValue) {
      return DatePickerField(
        date: value,
        formattedDate:
            value != null
                ? (extra['format'] != null
                    ? DateFormat(extra['format'] as String).format(value)
                    : DateFormat('yyyy-MM-dd').format(value))
                : '',
        placeholder: config.hintText ?? 'app_selectDate'.tr,
        labelText: config.labelText,
        inline: (extra['inline'] as bool?) ?? false,
        onTap:
            config.enabled
                ? () async {
                  final initialDate = value ?? DateTime.now();

                  // DS 无日期范围约束参数，first/lastDate 仅作为兜底校验
                  final picked = await showDSDatePickerDialog(
                    context: context,
                    initial: initialDate,
                    cancelText: 'app_cancel'.tr,
                    confirmText: 'app_ok'.tr,
                    theme: DSThemeBridge.resolve(context),
                  );
                  if (picked != null) {
                    setValue(picked);
                  }
                }
                : () {},
      );
    },
  );
}

/// 构建时间选择框
Widget buildTimeField(FormFieldConfig config, GlobalKey fieldKey) {
  return WrappedFormField(
    key: fieldKey,
    name: config.name,
    initialValue: config.initialValue as TimeOfDay?,
    enabled: config.enabled,
    onChanged: config.onChanged,
    builder:
        (context, value, setValue) => TimePickerField(
          label: config.labelText ?? 'app_selectTime'.tr,
          time: value ?? TimeOfDay.now(),
          onTimeChanged: setValue,
        ),
  );
}

/// 构建日期范围选择器字段
Widget buildDateRangeField(FormFieldConfig config, GlobalKey fieldKey) {
  final extra = config.extra ?? {};

  DateTime? startDate;
  DateTime? endDate;

  if (config.initialValue is DateTimeRange) {
    final range = config.initialValue as DateTimeRange;
    startDate = range.start;
    endDate = range.end;
  } else if (config.initialValue is Map) {
    final data = config.initialValue as Map<String, dynamic>;
    startDate = data['startDate'] as DateTime?;
    endDate = data['endDate'] as DateTime?;
  }

  return WrappedFormField(
    key: fieldKey,
    name: config.name,
    initialValue: {'startDate': startDate, 'endDate': endDate},
    enabled: config.enabled,
    onChanged: config.onChanged,
    builder: (context, value, setValue) {
      final currentStartDate = value?['startDate'] as DateTime?;
      final currentEndDate = value?['endDate'] as DateTime?;

      return DateRangeField(
        startDate: currentStartDate,
        endDate: currentEndDate,
        enabled: config.enabled,
        placeholder: config.hintText,
        rangeLabelText: extra['rangeLabelText'] as String?,
        firstDate: extra['firstDate'] as DateTime?,
        lastDate: extra['lastDate'] as DateTime?,
        onDateRangeChanged: (range) {
          if (range != null) {
            setValue({'startDate': range.start, 'endDate': range.end});
          } else {
            setValue({'startDate': null, 'endDate': null});
          }
        },
      );
    },
  );
}

/// 构建头像选择器字段
Widget buildAvatarPickerField(FormFieldConfig config, GlobalKey fieldKey) {
  final extra = config.extra ?? {};
  final username = extra['username'] as String? ?? 'User';
  final size = extra['size'] as double? ?? 80.0;
  final saveDirectory = extra['saveDirectory'] as String? ?? 'avatars';

  return WrappedFormField(
    key: fieldKey,
    name: config.name,
    initialValue: config.initialValue as String?,
    enabled: config.enabled,
    onChanged: config.onChanged,
    builder:
        (context, value, setValue) => AvatarPickerField(
          username: username,
          currentAvatarPath: value as String?,
          size: size,
          saveDirectory: saveDirectory,
          enabled: config.enabled,
          onAvatarChanged: setValue,
        ),
  );
}

/// 构建圆形图标选择器字段
Widget buildCircleIconPickerField(FormFieldConfig config, GlobalKey fieldKey) {
  final extra = config.extra ?? {};
  final initialBackgroundColor =
      extra['initialBackgroundColor'] as Color? ?? DsColors.primary;
  final showLabel = extra['showLabel'] as bool? ?? false;
  final labelText = extra['labelText'] as String? ?? config.labelText;

  return WrappedFormField(
    key: fieldKey,
    name: config.name,
    initialValue:
        config.initialValue is Map
            ? config.initialValue as Map<String, dynamic>
            : {
              'icon': config.initialValue as IconData? ?? Icons.star,
              'color': initialBackgroundColor,
            },
    enabled: config.enabled,
    onChanged: config.onChanged,
    builder: (context, value, setValue) {
      final data =
          value is Map<String, dynamic>
              ? value
              : {'icon': Icons.star, 'color': initialBackgroundColor};

      return CircleIconPickerField(
        currentIcon: data['icon'] as IconData? ?? Icons.star,
        currentBackgroundColor: data['color'] as Color? ?? DsColors.primary,
        enabled: config.enabled,
        showLabel: showLabel,
        labelText: labelText,
        onValueChanged: setValue,
      );
    },
  );
}

/// 构建日历条日期选择器字段
Widget buildCalendarStripPickerField(
  FormFieldConfig config,
  GlobalKey fieldKey,
) {
  final extra = config.extra ?? {};
  final allowFutureDates = extra['allowFutureDates'] as bool? ?? false;
  final useShortWeekDay = extra['useShortWeekDay'] as bool? ?? false;

  return WrappedFormField(
    key: fieldKey,
    name: config.name,
    initialValue: config.initialValue as DateTime? ?? DateTime.now(),
    enabled: config.enabled,
    onChanged: config.onChanged,
    builder:
        (context, value, setValue) => CalendarStripPickerField(
          selectedDate: value as DateTime? ?? DateTime.now(),
          enabled: config.enabled,
          allowFutureDates: allowFutureDates,
          useShortWeekDay: useShortWeekDay,
          onDateChanged: setValue,
        ),
  );
}

/// 构建图片选择器字段
Widget buildImagePickerField(FormFieldConfig config, GlobalKey fieldKey) {
  final extra = config.extra ?? {};
  final enableCrop = extra['enableCrop'] as bool? ?? false;
  final cropAspectRatio = extra['cropAspectRatio'] as double?;
  final multiple = extra['multiple'] as bool? ?? false;
  final enableCompression = extra['enableCompression'] as bool? ?? false;
  final flex = extra['flex'] as int? ?? 1;
  final previewWidth = extra['previewWidth'] as double?;
  final previewHeight = extra['previewHeight'] as double?;
  final defaultImagePath = extra['defaultImagePath'] as String?;
  final showShadow = extra['showShadow'] as bool? ?? false;
  final borderRadius = extra['borderRadius'] as double? ?? 12;
  final showLabel = extra['showLabel'] as bool? ?? true;
  final showSelectButton = extra['showSelectButton'] as bool? ?? true;

  // 获取初始图片路径（单图模式）
  dynamic getInitialImagePath(dynamic value) {
    if (value == null) return null;
    if (multiple && value is List && value.isNotEmpty) {
      // 多图模式返回第一张图的 URL
      final firstItem = value.first;
      if (firstItem is Map) {
        return firstItem['url'] as String?;
      }
      return null;
    }
    if (value is Map) {
      return value['url'] as String?;
    }
    return value as String?;
  }

  return WrappedFormField(
    key: fieldKey,
    name: config.name,
    initialValue: config.initialValue,
    enabled: config.enabled,
    onChanged: config.onChanged,
    builder:
        (context, value, setValue) => ImagePickerField(
          currentImage: getInitialImagePath(value),
          labelText: config.labelText,
          hintText: config.hintText,
          enabled: config.enabled,
          enableCrop: enableCrop,
          cropAspectRatio: cropAspectRatio,
          multiple: multiple,
          enableCompression: enableCompression,
          flex: flex,
          previewWidth: previewWidth,
          previewHeight: previewHeight,
          defaultImagePath: defaultImagePath,
          showShadow: showShadow,
          borderRadius: borderRadius,
          showLabel: showLabel,
          showSelectButton: showSelectButton,
          onImageChanged: setValue,
        ),
  );
}

/// 构建位置选择器字段
Widget buildLocationPickerField(FormFieldConfig config, GlobalKey fieldKey) {
  return WrappedFormField(
    key: fieldKey,
    name: config.name,
    initialValue: config.initialValue as String?,
    enabled: config.enabled,
    onChanged: config.onChanged,
    builder:
        (context, value, setValue) => LocationPickerField(
          currentLocation: value as String?,
          labelText: config.labelText,
          hintText: config.hintText,
          enabled: config.enabled,
          isMobile: true,
          onLocationChanged: setValue,
        ),
  );
}
