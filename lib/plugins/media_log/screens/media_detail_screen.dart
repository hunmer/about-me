import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

import '../media_log_plugin.dart';
import '../models/media_item.dart';
import '../widgets/media_cover.dart' show MediaCoverView;
import '../widgets/media_item_card.dart';
import '../widgets/media_item_form.dart';
import '../widgets/media_review_form.dart';

/// 媒体详情页：封面 + 简介 + 标签 + 多条带时间戳的点评
///
/// UI 迁移自 ai_picks_demo 详情页。
class MediaDetailScreen extends StatefulWidget {
  const MediaDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  @override
  void initState() {
    super.initState();
    MediaLogPlugin.instance.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    MediaLogPlugin.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (!mounted) return;
    // 条目被删除时自动返回
    if (MediaLogPlugin.instance.getItem(widget.itemId) == null) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {});
  }

  /// 编辑条目（表单 sheet 内含删除入口）
  Future<void> _editItem(MediaItem item) async {
    final result = await showDSBottomSheet<dynamic>(
      context: context,
      title: 'media_editItem'.tr,
      builder: (context) => MediaItemForm(
        kind: item.kind,
        initial: item,
        availableTags: MediaLogPlugin.instance.getAllTags(),
        showDelete: true,
      ),
    );
    if (result == null || !mounted) return;
    if (result == 'delete') {
      await MediaLogPlugin.instance.deleteItem(item.id);
      return;
    }
    final saved = result as MediaItem;
    await MediaLogPlugin.instance.saveItem(saved);
  }

  /// 新增点评
  Future<void> _addReview(MediaItem item) async {
    final result = await showDSBottomSheet<MediaReview>(
      context: context,
      title: 'media_addReview'.tr,
      builder: (context) => MediaReviewForm(),
    );
    if (result == null || !mounted) return;
    await MediaLogPlugin.instance.saveReview(
      item.id,
      result.copyWith(id: MediaLogPlugin.newId()),
    );
  }

  /// 点评操作：编辑 / 删除
  Future<void> _showReviewActions(MediaItem item, MediaReview review) async {
    await showDSBottomSheet(
      context: context,
      title: 'media_reviewSection'.tr,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DSSheetAction(
            icon: DsIconKind.edit,
            label: 'media_editReview'.tr,
            onTap: () {
              Navigator.pop(sheetContext);
              _editReview(item, review);
            },
          ),
          DSSheetAction(
            icon: DsIconKind.trash,
            label: 'media_deleteReview'.tr,
            destructive: true,
            onTap: () {
              Navigator.pop(sheetContext);
              MediaLogPlugin.instance.deleteReview(item.id, review.id);
            },
          ),
        ],
      ),
    );
  }

  /// 编辑点评
  Future<void> _editReview(MediaItem item, MediaReview review) async {
    final result = await showDSBottomSheet<MediaReview>(
      context: context,
      title: 'media_editReview'.tr,
      builder: (context) => MediaReviewForm(initial: review),
    );
    if (result == null || !mounted) return;
    await MediaLogPlugin.instance.saveReview(
      item.id,
      result.copyWith(id: review.id),
    );
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'media_notFinished'.tr;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final item = MediaLogPlugin.instance.getItem(widget.itemId);
    if (item == null) {
      return const SizedBox.shrink();
    }

    // 独立路由可能不在 AppTheme 树内，自行桥接主题
    return DSThemeBridge(
      child: Builder(
        builder: (context) => _build(context, item),
      ),
    );
  }

  Widget _build(BuildContext context, MediaItem item) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Column(
          children: [
            // 轻量顶栏：返回 + 标题 + 编辑（design.md §2.1）
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: DSLightHeader(
                title: item.title,
                trailing: DSIconButton(
                  icon: DsIconKind.edit,
                  size: 38,
                  color: theme.surface,
                  iconColor: theme.text,
                  tooltip: 'media_edit'.tr,
                  onPressed: () => _editItem(item),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.paddingOf(context).bottom),
                child: Column(
                  children: [
                    // 封面（错落旋转，迁移自 demo；与列表卡片共享 Hero 飞行过渡）
                    Transform.rotate(
                      angle: -0.02,
                      child: Container(
                        decoration: dsSketchDecoration(
                          theme: theme,
                          radius: DsRadii.md,
                          seed: 7,
                        ),
                        child: ClipRRect(
                          borderRadius: DsRadii.md,
                          child: SizedBox(
                            width: 168,
                            child: Hero(
                              tag: item.coverHeroTag,
                              child: ClipRRect(
                                borderRadius: DsRadii.md,
                                child: AspectRatio(
                                  aspectRatio: 1 / item.aspect,
                                  child: MediaCoverView(item: item),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    // 标题 + 倾斜手绘下划线
                    Center(
                      child: DsScribbleUnderline(
                        child: Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: DsTypography.title.copyWith(color: theme.text),
                        ),
                      ),
                    ),
                    if (item.author != null && item.author!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.author!,
                        style: DsTypography.body.copyWith(color: theme.textSub),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _buildStatsRow(item, theme),
                    if (item.overview != null && item.overview!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _Section(title: 'media_overviewSection'.tr),
                      const SizedBox(height: 8),
                      Text(
                        item.overview!,
                        style: DsTypography.body.copyWith(color: theme.textSub),
                      ),
                    ],
                    if (item.tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [for (final tag in item.tags) DSChip(label: tag)],
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                      Expanded(
                        child: _Section(
                          title: '${'media_reviewSection'.tr} (${item.reviews.length})',
                          circled: true,
                        ),
                      ),
                        DSIconButton(
                          icon: DsIconKind.plus,
                          size: 34,
                          color: theme.surface,
                          iconColor: theme.text,
                          tooltip: 'media_addReview'.tr,
                          onPressed: () => _addReview(item),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (item.reviews.isEmpty)
                      DSEmptyState(
                        emoji: '💬',
                        title: 'media_noReviews'.tr,
                        message: 'media_noReviewsMessage'.tr,
                      )
                    else
                      for (var i = 0; i < item.reviews.length; i++) ...[
                        MediaReviewCard(
                          review: item.reviews[i],
                          seed: i + 3,
                          onTap: () => _showReviewActions(item, item.reviews[i]),
                        ),
                        if (i < item.reviews.length - 1) const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(MediaItem item, AppThemeData theme) {
    final stats = [
      (DsIconKind.star, 'media_rating'.tr, item.rating != null ? '${item.rating}' : '-'),
      (DsIconKind.bubble, 'media_reviewSection'.tr, '${item.reviews.length}'),
      (DsIconKind.calendarCheck, 'media_finishedAt'.tr, _dateLabel(item.finishedAt)),
    ];
    return IntrinsicHeight(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(width: 1, color: theme.stroke),
              ),
            Column(
              children: [
                DsIcon(stats[i].$1, size: 16, color: theme.textSub),
                const SizedBox(height: 4),
                Text(
                  stats[i].$2,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
                const SizedBox(height: 2),
                Text(
                  stats[i].$3,
                  style: DsTypography.heading.copyWith(color: theme.text),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.circled = false});

  final String title;

  /// 是否用手绘椭圆圈选标题（点评区标记）
  final bool circled;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final text = Text(
      title,
      style: DsTypography.title.copyWith(fontSize: 16, color: theme.text),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: circled ? DsScribbleCircle(child: text) : text,
    );
  }
}
