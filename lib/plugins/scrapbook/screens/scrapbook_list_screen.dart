import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/scrapbook_canvas_card/scrapbook_canvas_card.dart'
    show ScrapItemData, ScrapItemKind;
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/spatial_list_card.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

import '../models/scrapbook_page.dart';
import '../services/scrapbook_repository.dart';
import 'scrapbook_canvas_screen.dart';

/// 手账列表页：空间清单卡片墙（便签化），点击编辑按钮进入画布编辑
class ScrapbookListScreen extends StatefulWidget {
  const ScrapbookListScreen({super.key});

  @override
  State<ScrapbookListScreen> createState() => _ScrapbookListScreenState();
}

class _ScrapbookListScreenState extends State<ScrapbookListScreen> {
  final _repository = ScrapbookRepository.instance;

  /// null = 加载中
  List<ScrapbookPage>? _pages;
  VoidCallback? _unsubscribe;

  @override
  void initState() {
    super.initState();
    _unsubscribe = _repository.subscribe(() {
      if (mounted) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final pages = await _repository.getList();
      if (mounted) setState(() => _pages = pages);
    } catch (e) {
      debugPrint('[Scrapbook] 加载失败: $e');
      if (mounted) setState(() => _pages = _pages ?? []);
    }
  }

  Future<void> _createPage() async {
    final titleController = TextEditingController();
    final input = await SmoothBottomSheet.showWithTitle<String>(
      context: context,
      title: 'scrapbook_newPage'.tr,
      headerActions: [
        Builder(
          builder: (sheetContext) => DSButton(
            label: 'app_save'.tr,
            size: DSButtonSize.sm,
            icon: DsIconKind.check,
            onPressed: () => Navigator.of(sheetContext).pop(
              titleController.text.trim(),
            ),
          ),
        ),
      ],
      child: Builder(
        builder: (sheetContext) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: DSInput(
            controller: titleController,
            hint: 'scrapbook_titleHint'.tr,
            onSubmitted: (value) => Navigator.of(sheetContext).pop(value.trim()),
          ),
        ),
      ),
    );
    final title = input?.trim() ?? '';
    if (title.isEmpty) return;

    final now = DateTime.now();
    final page = ScrapbookPage(
      id: '',
      title: title,
      subtitle: '${now.month}.${now.day}',
      // 预置标题条目，画布不空
      items: [
        ScrapItemData(
          id: 'header_init',
          kind: ScrapItemKind.header,
          x: 96,
          y: 48,
          zIndex: 40,
          dateLabel: '${now.year}.${now.month}.${now.day}',
          title: title,
        ),
      ],
    );
    try {
      final created = await _repository.create(page);
      await _load();
      if (mounted) _openCanvas(created);
    } catch (e) {
      debugPrint('[Scrapbook] 创建失败: $e');
      ToastService.instance.showToast(
        'scrapbook_createFailed'.tr,
        type: ToastType.error,
      );
    }
  }

  Future<void> _openCanvas(ScrapbookPage page) async {
    await NavigationHelper.push(
      context,
      ScrapbookCanvasScreen(page: page),
      routeName: '/scrapbook/canvas',
    );
    _load();
  }

  /// 滑动删除：先确认再真正删除，失败恢复条目
  Future<bool> _confirmDismiss(ScrapbookPage page) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSDialog(
        title: 'scrapbook_deleteTitle'.tr,
        message: 'scrapbook_deleteMessage'.trParams({'title': page.title}),
        cancelText: 'app_cancel'.tr,
        confirmText: 'app_delete'.tr,
        confirmVariant: DSButtonVariant.destructive,
        onConfirm: () => Navigator.pop(dialogContext, true),
      ),
    );
    if (confirmed != true) return false;
    try {
      await _repository.delete(page.id);
      return true;
    } catch (e) {
      debugPrint('[Scrapbook] 删除失败: $e');
      ToastService.instance.showToast(
        'scrapbook_deleteFailed'.tr,
        type: ToastType.error,
      );
      return false;
    }
  }

  String _relativeLabel(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'scrapbook_timeJustNow'.tr;
    if (diff.inHours < 1) {
      return 'scrapbook_timeMinutesAgo'.trParams({'n': '${diff.inMinutes}'});
    }
    if (diff.inDays < 1) {
      return 'scrapbook_timeHoursAgo'.trParams({'n': '${diff.inHours}'});
    }
    if (diff.inDays == 1) return 'scrapbook_timeYesterday'.tr;
    if (diff.inDays < 7) {
      return 'scrapbook_timeDaysAgo'.trParams({'n': '${diff.inDays}'});
    }
    return '${time.year}.${time.month}.${time.day}';
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    return SuperCupertinoNavigationWrapper(
      title: Text('scrapbook_name'.tr),
      largeTitle: 'scrapbook_listTitle'.tr,
      enableLargeTitle: true,
      actions: [_buildAddButton()],
      body: pages == null
          ? const Center(child: CircularProgressIndicator())
          : pages.isEmpty
          ? Center(
              child: DSEmptyState(
                icon: DsIconKind.book,
                title: 'scrapbook_emptyTitle'.tr,
                message: 'scrapbook_emptyMessage'.tr,
                actionLabel: 'scrapbook_create'.tr,
                onAction: _createPage,
              ),
            )
          : HandDrawnListView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 16,
              ),
              itemCount: pages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              tiltKeyOf: (i) => pages[i].id,
              itemBuilder: (context, i) =>
                  _buildCardItem(context, pages[i], i),
            ),
    );
  }

  Widget _buildAddButton() {
    return DSIconButton(
      icon: DsIconKind.plus,
      size: 38,
      onPressed: _createPage,
    );
  }

  Widget _buildCardItem(BuildContext context, ScrapbookPage page, int index) {
    final theme = DSThemeBridge.resolve(context);
    final created = page.createdAt;
    return Dismissible(
      key: ValueKey('scrapbook_${page.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDismiss(page),
      onDismissed: (_) => _load(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 28),
        color: theme.danger,
        child: DsIcon(DsIconKind.trash, color: theme.onPrimary, size: 22),
      ),
      child: SpatialListCardWidget(
        inline: true,
        title: page.title,
        subtitle: page.subtitle ?? '',
        updatedLabel: _relativeLabel(page.updatedAt),
        itemCount: page.items.length,
        noteTitle: page.title,
        noteAuthor: '${created.month}.${created.day}',
        noteContent: page.summary.isEmpty
            ? 'scrapbook_noSummary'.tr
            : page.summary,
        onOpen: () => _openCanvas(page),
      ),
    );
  }
}
