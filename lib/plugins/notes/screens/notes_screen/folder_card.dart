import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/widgets/arc_context_menu.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/models/folder.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 手绘文件夹卡片：彩色主体 + 顶部露出的文件夹舌头与便签纸
///
/// 参考便签墙的文件夹样式（彩色块 + 纸张探出），但全部用
/// skribble 手绘墨线渲染，与笔记卡保持同一套手绘语言。
class FolderCard extends StatelessWidget {
  final Folder folder;

  /// 文件夹内笔记数量（直接子项，由外部统计传入）
  final int noteCount;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// 归档/取消归档回调（null 时不显示菜单项）
  final VoidCallback? onToggleArchive;

  const FolderCard({
    super.key,
    required this.folder,
    required this.noteCount,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onToggleArchive,
  });

  /// 底部抽屉菜单（重命名 / 归档 / 删除）
  void _showBottomSheet(BuildContext context) {
    if (onEdit == null && onDelete == null && onToggleArchive == null) return;
    SmoothBottomSheet.show(
      context: context,
      builder:
          (context) => DSThemeBridge(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  SmoothSheetAction(
                    icon: DsIconKind.edit,
                    label: 'notes_renameFolder'.tr,
                    onTap: () {
                      Navigator.pop(context);
                      onEdit!();
                    },
                  ),
                if (onToggleArchive != null)
                  SmoothSheetAction(
                    icon: DsIconKind.archive,
                    label: folder.isArchived
                        ? 'notes_unarchive'.tr
                        : 'notes_archive'.tr,
                    onTap: () {
                      Navigator.pop(context);
                      onToggleArchive!();
                    },
                  ),
                if (onDelete != null)
                  SmoothSheetAction(
                    icon: DsIconKind.trash,
                    label: 'app_delete'.tr,
                    destructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      onDelete!();
                    },
                  ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    // 环境描画动画（列表项外层 WiredDraw 注入）；null = 已画完
    final progress = WiredDrawTransition.progressOf(context);
    // 墨迹按文件夹稳定变化（rebuild 不抖变）
    final seed = folder.id.hashCode & 0x7fffffff;

    // 彩色底上文字按亮度切换深墨/纸白，保证可读
    final onFolder =
        folder.color.computeLuminance() > 0.45 ? DsColors.text : Colors.white;

    // 长按弹圆盘快捷菜单（与底部 sheet 按钮一致，动态；无可用操作时为空）
    return ArcContextMenu.actions(
      onTap: onTap,
      actions: [
        if (onEdit != null)
          ArcMenuItem(
            icon: DsIconKind.edit,
            label: 'notes_renameFolder'.tr,
            onTap: onEdit!,
          ),
        if (onToggleArchive != null)
          ArcMenuItem(
            icon: DsIconKind.archive,
            label: folder.isArchived ? 'notes_unarchive'.tr : 'notes_archive'.tr,
            onTap: onToggleArchive!,
          ),
        if (onDelete != null)
          ArcMenuItem(
            icon: DsIconKind.trash,
            label: 'app_delete'.tr,
            destructive: true,
            onTap: onDelete!,
          ),
      ],
      showMore: () => _showBottomSheet(context),
      child: Padding(
        // 顶部留白给文件夹舌头与露出的纸张
        padding: const EdgeInsets.only(top: 16),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 文件夹舌头（左上，与主体同色，仅上边圆角）
            Positioned(
              top: -14,
              left: 12,
              child: IgnorePointer(
                child: Container(
                  width: 72,
                  height: 26,
                  decoration: dsSketchDecoration(
                    theme: theme,
                    fillColor: folder.color,
                    radius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    strokeWidth: 1.8,
                    seed: seed + 1,
                    progress: progress,
                  ),
                ),
              ),
            ),
            // 露出的便签纸（后层，微右倾）
            Positioned(
              top: -8,
              left: 52,
              right: 42,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: 0.03,
                  child: Container(
                    height: 24,
                    decoration: dsSketchDecoration(
                      theme: theme,
                      fillColor: theme.paper,
                      radius: BorderRadius.circular(6),
                      strokeWidth: 1.4,
                      seed: seed + 2,
                      progress: progress,
                    ),
                  ),
                ),
              ),
            ),
            // 露出的便签纸（前层，微左倾）
            Positioned(
              top: -11,
              left: 70,
              right: 22,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: -0.04,
                  child: Container(
                    height: 24,
                    decoration: dsSketchDecoration(
                      theme: theme,
                      fillColor: theme.paper,
                      radius: BorderRadius.circular(6),
                      strokeWidth: 1.4,
                      seed: seed + 3,
                      progress: progress,
                    ),
                  ),
                ),
              ),
            ),
            // 彩色主体（实底 + 墨线描边）
            DsSketchPanel(
              theme: theme,
              radius: BorderRadius.circular(14),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              seed: seed,
              progress: progress,
              fillColor: folder.color,
              fillStyle: DsSketchFill.solid,
              hachureColor: folder.color,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          folder.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DsTypography.title.copyWith(color: onFolder),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showBottomSheet(context),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: DsIcon(
                            DsIconKind.dots,
                            size: 18,
                            color: onFolder,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$noteCount',
                    style: DsTypography.caption.copyWith(
                      color: onFolder.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
