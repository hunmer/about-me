import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/plugins/calendar_album/controllers/calendar_controller.dart';
import 'package:aboutme/plugins/calendar_album/models/calendar_entry.dart';
import 'package:aboutme/core/services/toast_service.dart';

class EntryEditorController {
  final CalendarEntry? entry;
  final bool isEditing;
  final DateTime? initialDate;

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
  bool isPreview = false;

  EntryEditorController({
    this.entry,
    required this.isEditing,
    this.initialDate,
    this.initialImageUrls,
    this.initialThumbUrls,
    this.initialLiveVideoUrls,
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
        createdAt: initialDate ?? DateTime.now(),
      );
      calendarController.addEntry(newEntry);
      return newEntry;
    }
  }
}
