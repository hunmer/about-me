import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/arc_context_menu.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:aboutme/plugins/calendar_album/controllers/tag_controller.dart';
import 'package:aboutme/plugins/calendar_album/controllers/calendar_controller.dart';
import 'package:aboutme/plugins/calendar_album/widgets/tag_folder_card.dart';
import 'package:aboutme/plugins/calendar_album/widgets/folder_icon_sheet.dart';
import 'album_screen.dart';

class TagScreen extends StatefulWidget {
  const TagScreen({super.key});

  @override
  State<TagScreen> createState() => _TagScreenState();
}

class _TagScreenState extends State<TagScreen> {
  /// 上次路由上下文记录的标签数，避免每次 build 重复更新
  int? _lastContextCount;

  @override
  void initState() {
    super.initState();
    _updateRouteContext(0);
  }

  /// 更新路由上下文，使"询问当前上下文"功能能获取到当前标签数
  void _updateRouteContext(int tagCount) {
    if (_lastContextCount == tagCount) return;
    _lastContextCount = tagCount;
    RouteHistoryManager.updateCurrentContext(
      pageId: '/calendar_album_tags',
      title: 'calendar_album_route_title_tags'.trParams({
        'count': tagCount.toString(),
      }),
      params: {'tagCount': tagCount.toString()},
    );
  }

  /// 收集标签下的图片（imageUrls + markdown 内联图，去重，新条目在前）
  List<String> _tagImages(CalendarController controller, String tag) {
    final urls = <String>[];
    final seen = <String>{};
    for (final entry in controller.getEntriesByTag(tag)) {
      for (final url in [...entry.imageUrls, ...entry.extractImagesFromMarkdown()]) {
        if (url.isEmpty || !seen.add(url)) continue;
        urls.add(url);
      }
    }
    return urls;
  }

  /// 打开标签对应的相册（应用标签过滤）
  void _openFolder(
    String tag,
    CalendarController calendarController,
    TagController tagController,
  ) {
    NavigationHelper.push<void>(
      context,
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CalendarController>.value(
            value: calendarController,
          ),
          ChangeNotifierProvider<TagController>.value(value: tagController),
        ],
        child: AlbumScreen(initialTags: [tag]),
      ),
    );
  }

  /// 编辑文件夹图标：smoothsheet ModalSheet 底部抽屉 + 图标选择器
  void _showFolderIconSheet(String tag, TagController tagController) {
    final theme = DSThemeBridge.resolve(context);
    SmoothBottomSheet.showWithTitle(
      context: context,
      title: 'calendar_album_edit_folder_icon'.tr,
      backgroundColor: theme.surface,
      child: SizedBox(
        height: 430,
        child: DSThemeBridge(
          child: FolderIconSheet(tag: tag, tagController: tagController),
        ),
      ),
    );
  }

  /// 打开标签管理对话框
  Future<void> _manageTags(TagController tagController) async {
    await tagController.showTagManagerDialog(context);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tagController = context.watch<TagController>();
    final theme = DSThemeBridge.resolve(context);

    return SuperCupertinoNavigationWrapper(
      // tab 内嵌页：关闭路由 hero 转场，避免 Hero tag 冲突
      transitionBetweenRoutes: false,
      title: Text('calendar_album_tag_management'.tr),
      largeTitle: 'calendar_album_tag_management'.tr,
      actions: [
        DSIconButton(
          icon: DsIconKind.tag,
          size: 36,
          color: theme.surfaceAlt,
          iconColor: theme.textSub,
          tooltip: 'calendar_album_tag_management'.tr,
          onPressed: () => _manageTags(tagController),
        ),
      ],
      body: Consumer<CalendarController>(
        builder: (context, calendarController, child) {
          // 标签来源：条目实际使用的标签 ∪ 标签管理器中定义的标签
          final tags =
              <String>{
                ...calendarController.getAllTags(),
                ...tagController.tags,
              }.toList();

          if (tags.isEmpty) {
            _updateRouteContext(0);
            return Center(
              child: DSThemeBridge(
                child: DSEmptyState(
                  emoji: '🗂️',
                  title: 'calendar_album_no_tags'.tr,
                  message: 'calendar_album_tags_empty_hint'.tr,
                ),
              ),
            );
          }

          // 每个文件夹的图片列表 + 按图片数排序
          final folderImages = {for (final tag in tags) tag: _tagImages(calendarController, tag)};
          tags.sort(
            (a, b) =>
                folderImages[b]!.length != folderImages[a]!.length
                    ? folderImages[b]!.length.compareTo(folderImages[a]!.length)
                    : a.compareTo(b),
          );

          _updateRouteContext(tags.length);

          return GridView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 18,
              mainAxisSpacing: 20,
              childAspectRatio: 0.82,
            ),
            itemCount: tags.length,
            itemBuilder: (context, index) {
              final tag = tags[index];
              final images = folderImages[tag]!;
              final folder = TagFolderCard(
                tag: tag,
                imageUrls: images,
                count: images.length,
                stickerIcon: tagController.getTagIcon(tag),
              );

              return ArcContextMenu(
                onTap:
                    () => _openFolder(tag, calendarController, tagController),
                items: [
                  ArcMenuItem(
                    icon: DsIconKind.edit,
                    label: 'calendar_album_edit'.tr,
                    onTap: () => _showFolderIconSheet(tag, tagController),
                  ),
                  ArcMenuItem(
                    icon: DsIconKind.image,
                    label: 'calendar_album_open_folder'.tr,
                    onTap:
                        () =>
                            _openFolder(tag, calendarController, tagController),
                  ),
                  ArcMenuItem(
                    icon: DsIconKind.tag,
                    label: 'calendar_album_tag_management'.tr,
                    onTap: () => _manageTags(tagController),
                  ),
                ],
                child: folder,
              );
            },
          );
        },
      ),
    );
  }
}
