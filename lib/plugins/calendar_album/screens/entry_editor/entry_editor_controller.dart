import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/plugins/calendar_album/controllers/calendar_controller.dart';
import 'package:aboutme/plugins/calendar_album/models/calendar_entry.dart';
import 'package:aboutme/core/services/toast_service.dart';

class EntryEditorController {
  final CalendarEntry? entry;
  final bool isEditing;

  /// 新建模式的初始日期（如"从照片创建"带入的分组日期）；
  /// 对应日期照片组被删除时置空，保存回退当前时间
  DateTime? initialDate;

  /// 新建模式的初始图片（如"从照片创建"带入），编辑模式忽略
  final List<String>? initialImageUrls;
  final List<String>? initialThumbUrls;
  final List<String>? initialLiveVideoUrls;

  late TextEditingController titleController;
  late TextEditingController contentController;
  late TextEditingController locationController;

  /// 位置经纬度 "lat,lng"（GCJ-02），与 locationController 地址文本配套
  String? latLng;
  String? mood;
  String? weather;
  List<String> selectedTags = [];
  List<String> imageUrls = [];
  List<String> thumbUrls = [];
  List<String> liveVideoUrls = [];

  /// 各图片的拍摄日期（与 [imageUrls] 平行，手动添加的为 null），
  /// 驱动表单顶部按日期分组的照片管理按钮
  List<DateTime?> imageDates = [];
  bool isPreview = false;

  EntryEditorController({
    this.entry,
    required this.isEditing,
    this.initialDate,
    this.initialImageUrls,
    this.initialThumbUrls,
    this.initialLiveVideoUrls,
    List<DateTime?>? initialImageDates,
  }) {
    titleController = TextEditingController(text: entry?.title ?? '');
    contentController = TextEditingController(text: entry?.content ?? '');
    locationController = TextEditingController(text: entry?.location ?? '');
    latLng = entry?.latLng;
    mood = entry?.mood;
    weather = entry?.weather;
    imageUrls = entry?.imageUrls.toList() ?? initialImageUrls?.toList() ?? [];
    thumbUrls = entry?.thumbUrls.toList() ?? initialThumbUrls?.toList() ?? [];
    liveVideoUrls =
        entry?.liveVideoUrls.toList() ?? initialLiveVideoUrls?.toList() ?? [];
    imageDates = List<DateTime?>.generate(
      imageUrls.length,
      (i) =>
          (initialImageDates != null && i < initialImageDates.length)
          ? initialImageDates[i]
          : null,
    );
  }

  /// 按天分组的照片数（日期升序），供表单顶部日期按钮渲染
  List<MapEntry<DateTime, int>> get dateGroupCounts {
    final counts = <DateTime, int>{};
    for (final date in imageDates) {
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  /// 删除某天的照片组（同步移除四条平行列表的对应项）；
  /// [initialDate] 落在该天时一并清空，保存日期回退当前时间
  void removeImagesOfDate(DateTime day) {
    for (var i = imageDates.length - 1; i >= 0; i--) {
      final date = imageDates[i];
      if (date == null) continue;
      if (date.year == day.year &&
          date.month == day.month &&
          date.day == day.day) {
        imageUrls.removeAt(i);
        thumbUrls.removeAt(i);
        liveVideoUrls.removeAt(i);
        imageDates.removeAt(i);
      }
    }
    final initial = initialDate;
    if (initial != null &&
        initial.year == day.year &&
        initial.month == day.month &&
        initial.day == day.day) {
      initialDate = null;
    }
  }

  void dispose() {
    titleController.dispose();
    contentController.dispose();
    locationController.dispose();
  }

  CalendarEntry? saveEntry(CalendarController calendarController) {
    // 如果标题为空且没有图片,则提示错误
    if (titleController.text.isEmpty && imageUrls.isEmpty) {
      toastService.showToast('calendar_album_title_cannot_be_empty'.tr);
      return null;
    }

    if (isEditing && entry != null) {
      final updatedEntry = entry!.copyWith(
        title: titleController.text,
        content: contentController.text,
        tags: selectedTags.toList(),
        location: locationController.text.isEmpty
            ? null
            : locationController.text,
        latLng: latLng,
        mood: mood,
        weather: weather,
        imageUrls: imageUrls,
        thumbUrls: thumbUrls,
        liveVideoUrls: liveVideoUrls,
      );
      calendarController.updateEntry(updatedEntry);
      return updatedEntry;
    } else {
      final newEntry = CalendarEntry.create(
        title: titleController.text,
        content: contentController.text,
        tags: selectedTags.toList(),
        location: locationController.text.isEmpty
            ? null
            : locationController.text,
        latLng: latLng,
        mood: mood,
        weather: weather,
        imageUrls: imageUrls,
        thumbUrls: thumbUrls,
        liveVideoUrls: liveVideoUrls,
        // 日期优先取剩余照片组中最早的一天（删除日期组后自动回退）
        createdAt: dateGroupCounts.isNotEmpty
            ? dateGroupCounts.first.key
            : initialDate ?? DateTime.now(),
      );
      calendarController.addEntry(newEntry);
      return newEntry;
    }
  }
}
