import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/form_fields/chip_selector_field.dart';
import 'package:aboutme/widgets/picker/location_picker.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'entry_editor_controller.dart';
import 'entry_editor_image_handler.dart';
import 'entry_editor_tag_handler.dart';

/// 日记编辑表单正文（图片、内容、标签、元数据），由底部弹层 [EntryEditorSheet] 使用
class EntryEditorForm extends StatefulWidget {
  final EntryEditorController controller;

  /// 只读模式（纯查看，禁用编辑与保存）
  final bool readOnly;

  /// 用于弹出位置选择器的上下文（弹层 context）
  final BuildContext parentContext;

  const EntryEditorForm({
    super.key,
    required this.controller,
    this.readOnly = false,
    required this.parentContext,
  });

  @override
  State<EntryEditorForm> createState() => _EntryEditorFormState();
}

class _EntryEditorFormState extends State<EntryEditorForm> {
  EntryEditorController get controller => widget.controller;
  bool get readOnly => widget.readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EntryEditorImageHandler(
          imageUrls: controller.imageUrls,
          thumbUrls: controller.thumbUrls,
          readOnly: readOnly,
          onImageAdded: (url, thumbUrl) {
            controller.imageUrls.add(url);
            controller.thumbUrls.add(thumbUrl ?? '');
          },
          onImageRemoved: (index) {
            controller.imageUrls.removeAt(index);
            if (index < controller.thumbUrls.length) {
              controller.thumbUrls.removeAt(index);
            }
          },
        ),
        const SizedBox(height: 20),
        _buildContentForm(),
        const SizedBox(height: 20),
        EntryEditorTagHandler(
          controller: controller,
          readOnly: readOnly,
        ),
        const SizedBox(height: 20),
        _buildMetadataForm(),
        const SizedBox(height: 40),
      ],
    );
  }

  /// 构建内容表单（标题、内容、心情）
  Widget _buildContentForm() {
    final theme = DSThemeBridge.resolve(context);
    // 准备心情选项
    final moods = [
      'Happy',
      'Sad',
      'Excited',
      'Tired',
      'Calm',
      'Anxious',
      'Content',
      'Angry',
    ];
    final moodOptions = moods
        .map(
          (m) => ChipOption(
            id: m,
            label: 'calendar_album_mood_${m.toLowerCase()}'.tr,
          ),
        )
        .toList();

    // 大容器走手绘面板：纸底 + 淡排线 + 墨线框
    return DsSketchPanel(
      theme: theme,
      radius: theme.radii.xl,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // 心情选择 + 标题输入行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // 心情选择器
                ChipSelectorField(
                  options: moodOptions,
                  selectedId: controller.mood,
                  hintText: 'calendar_album_mood'.tr,
                  selectorTitle: 'calendar_album_select_mood'.tr,
                  icon: Icons.sentiment_satisfied,
                  onValueChanged: (value) {
                    setState(() {
                      controller.mood = value;
                    });
                  },
                ),
                const SizedBox(width: 12),
                // 标题输入框
                Expanded(
                  child: TextField(
                    controller: controller.titleController,
                    readOnly: readOnly,
                    decoration: InputDecoration(
                      hintText: 'calendar_album_title'.tr,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: DsTypography.title.copyWith(
                        color: theme.textSub.withValues(alpha: 0.75),
                      ),
                    ),
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.ink.withValues(alpha: 0.12)),
          // 内容输入
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller.contentController,
              readOnly: readOnly,
              decoration: InputDecoration(
                hintText: 'calendar_album_whats_on_mind'.tr,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintStyle: DsTypography.body.copyWith(
                  color: theme.textSub.withValues(alpha: 0.75),
                ),
              ),
              maxLines: null,
              minLines: 8,
              style: DsTypography.body.copyWith(
                color: theme.text,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建元数据表单（位置、天气）
  Widget _buildMetadataForm() {
    final theme = DSThemeBridge.resolve(context);
    // 准备天气选项
    final weathers = [
      'Sunny',
      'Cloudy',
      'Rainy',
      'Snowy',
      'Windy',
      'Foggy',
      'Stormy',
      'Clear',
    ];
    final weatherOptions = weathers
        .map(
          (w) => ChipOption(
            id: w,
            label: 'calendar_album_weather_${w.toLowerCase()}'.tr,
          ),
        )
        .toList();

    return Row(
      children: [
        // 位置选择器
        Expanded(
          child: _buildMetadataCard(
            icon: DsIconKind.pin,
            iconColor: theme.primary,
            label: 'calendar_album_location'.tr,
            value:
                controller.locationController.text.isNotEmpty
                    ? controller.locationController.text
                    : 'calendar_album_add_location'.tr,
            onTap: readOnly
                ? null
                : () => _handleLocationSelection(widget.parentContext),
          ),
        ),
        const SizedBox(width: 12),
        // 天气选择器
        Expanded(
          child: _buildMetadataCard(
            icon: DsIconKind.sun,
            iconColor: theme.secondary,
            label: 'calendar_album_weather'.tr,
            value:
                controller.weather != null
                    ? 'calendar_album_weather_${controller.weather!.toLowerCase()}'.tr
                    : 'calendar_album_add_weather'.tr,
            onTap: readOnly ? null : () => _showWeatherPicker(weatherOptions),
          ),
        ),
      ],
    );
  }

  /// 构建元数据卡片（手绘墨盒 + 主题色图标）
  Widget _buildMetadataCard({
    required DsIconKind icon,
    required Color iconColor,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: onTap,
      child: JellyBox(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JellyBox(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              radius: theme.radii.lg,
              color: iconColor.mixWhite(0.88),
              child: DsIcon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsTypography.body.copyWith(color: theme.text),
            ),
          ],
        ),
      ),
    );
  }

  /// 处理位置选择
  Future<void> _handleLocationSelection(BuildContext dialogContext) async {
    final isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    await Navigator.of(dialogContext).push(
      ModalSheetRoute(
        swipeDismissible: true,
        builder: (context) => Sheet(
          decoration: const MaterialSheetDecoration(
            size: SheetSize.fit,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: LocationPicker(
            onLocationSelected: (location) {
              if (mounted) {
                setState(() {
                  controller.locationController.text = location;
                });
              }
            },
            onLatLngSelected: (lat, lng) {
              controller.latLng = '$lat,$lng';
            },
            isMobile: isMobile,
          ),
        ),
      ),
    );
  }

  /// 显示天气选择器（手绘底部面板 + DSChip 选项）
  void _showWeatherPicker(List<ChipOption> weatherOptions) {
    SmoothBottomSheet.showWithTitle(
      context: context,
      title: 'calendar_album_select_weather'.tr,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in weatherOptions)
              DSChip(
                label: opt.label,
                selected: controller.weather == opt.id,
                onSelected: (_) {
                  setState(() {
                    controller.weather = opt.id;
                  });
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}
