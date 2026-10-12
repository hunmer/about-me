import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:super_cupertino_navigation_bar/utils/navigation_bar_static_components.dart';
import 'package:super_cupertino_navigation_bar/utils/persistent_nav_bar.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/form_fields/chip_selector_field.dart';
import 'package:aboutme/widgets/picker/location_picker.dart';
import 'entry_editor_controller.dart';
import 'entry_editor_image_handler.dart';
import 'entry_editor_tag_handler.dart';

class EntryEditorUI extends StatefulWidget {
  final EntryEditorController controller;
  final bool isEditing;
  final BuildContext parentContext;

  const EntryEditorUI({
    super.key,
    required this.controller,
    required this.isEditing,
    required this.parentContext,
  });

  @override
  State<EntryEditorUI> createState() => _EntryEditorUIState();
}

class _EntryEditorUIState extends State<EntryEditorUI> {
  late EntryEditorController controller;
  late bool isEditing;

  // PersistentNavigationBar 组件 key（GlobalKey 需跨帧稳定，不能每次 build 新建）
  final NavigationBarStaticComponentsKeys _navBarKeys =
      NavigationBarStaticComponentsKeys();

  @override
  void initState() {
    super.initState();
    controller = widget.controller;
    isEditing = widget.isEditing;
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Scaffold(
      backgroundColor: theme.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context, theme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EntryEditorImageHandler(
                      imageUrls: controller.imageUrls,
                      thumbUrls: controller.thumbUrls,
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
                    EntryEditorTagHandler(controller: controller),
                    const SizedBox(height: 20),
                    _buildMetadataForm(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部导航：嵌入式 PersistentNavigationBar（编辑页标准，与全局导航同源）
  Widget _buildHeader(BuildContext context, AppThemeData theme) {
    return PersistentNavigationBar(
      components: NavigationBarStaticComponents(
        keys: _navBarKeys,
        route: null,
        // NavigationToolbar 对 leading 施加紧高度约束会把按钮拉变形，
        // 用 Align 转成宽松约束保持正圆
        userLeading: Align(
          alignment: AlignmentDirectional.centerStart,
          child: DSIconButton(
            icon: DsIconKind.chevronLeft,
            size: 36,
            color: theme.surfaceAlt,
            iconColor: theme.textSub,
            tooltip: 'calendar_album_cancel'.tr,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        automaticallyImplyLeading: false,
        automaticallyImplyTitle: false,
        previousPageTitle: null,
        userMiddle: Text(
          isEditing
              ? 'calendar_album_edit_post'.tr
              : 'calendar_album_new_post'.tr,
          style: DsTypography.title.copyWith(color: theme.text),
        ),
        userTrailing: DSIconButton(
          icon: DsIconKind.check,
          size: 36,
          color: theme.primary,
          iconColor: theme.onPrimary,
          tooltip: 'calendar_album_save'.tr,
          onPressed: () {
            final result = controller.saveEntry(context);
            if (result != null && mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
        userLargeTitle: null,
        largeTitleActions: null,
        appbarBottom: null,
        padding: null,
        // 嵌入式小导航（编辑页），非大标题模式
        large: false,
      ),
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
      'Angry',
      'Content',
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
            onTap: () => _handleLocationSelection(widget.parentContext),
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
            onTap: () => _showWeatherPicker(weatherOptions),
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
    required VoidCallback onTap,
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
            isMobile: isMobile,
          ),
        ),
      ),
    );
  }

  /// 显示天气选择器（手绘底部面板 + DSChip 选项）
  void _showWeatherPicker(List<ChipOption> weatherOptions) {
    showDSBottomSheet(
      context: context,
      title: 'calendar_album_select_weather'.tr,
      builder:
          (context) => Padding(
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
