/// 文件夹笔记卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 数据色手绘文件夹图标 + 路径 / 数据色笔记数量徽章 / 笔记列表
/// （手绘便签图标 + 标题 + 相对时间）。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// 文件夹笔记卡片数据模型
class FolderNotesCardData {
  final String folderName;
  final String folderPath;
  final int iconCodePoint;
  final int colorValue;
  final int notesCount;
  final List<NoteItemData> notes;

  const FolderNotesCardData({
    required this.folderName,
    required this.folderPath,
    required this.iconCodePoint,
    required this.colorValue,
    required this.notesCount,
    required this.notes,
  });

  /// 从 JSON 创建
  factory FolderNotesCardData.fromJson(Map<String, dynamic> json) {
    final notesList = (json['notes'] as List<dynamic>?)
            ?.map((e) => NoteItemData.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return FolderNotesCardData(
      folderName: json['folderName'] as String? ?? '',
      folderPath: json['folderPath'] as String? ?? '',
      iconCodePoint: json['iconCodePoint'] as int? ?? Icons.folder.codePoint,
      colorValue: json['colorValue'] as int? ?? 0xFF000000,
      notesCount: json['notesCount'] as int? ?? 0,
      notes: notesList,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'folderName': folderName,
      'folderPath': folderPath,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'notesCount': notesCount,
      'notes': notes.map((e) => e.toJson()).toList(),
    };
  }
}

/// 笔记项数据模型
class NoteItemData {
  final String title;
  final String updatedAt;

  const NoteItemData({
    required this.title,
    required this.updatedAt,
  });

  /// 从 JSON 创建
  factory NoteItemData.fromJson(Map<String, dynamic> json) {
    return NoteItemData(
      title: json['title'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'updatedAt': updatedAt,
    };
  }
}

/// 文件夹笔记卡片组件
///
/// 显示文件夹名称、图标和最近的笔记列表
class FolderNotesCardWidget extends StatefulWidget {
  final String folderName;
  final String folderPath;
  final int iconCodePoint;
  final int colorValue;
  final int notesCount;
  final List<NoteItemData> notes;

  const FolderNotesCardWidget({
    super.key,
    required this.folderName,
    required this.folderPath,
    required this.iconCodePoint,
    required this.colorValue,
    required this.notesCount,
    required this.notes,
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory FolderNotesCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final notesList = (props['notes'] as List<dynamic>?)
            ?.map((e) => NoteItemData.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return FolderNotesCardWidget(
      folderName: props['folderName'] as String? ?? '',
      folderPath: props['folderPath'] as String? ?? '',
      iconCodePoint: props['iconCodePoint'] as int? ?? Icons.folder.codePoint,
      colorValue: props['colorValue'] as int? ?? 0xFF000000,
      notesCount: props['notesCount'] as int? ?? 0,
      notes: notesList,
    );
  }

  @override
  State<FolderNotesCardWidget> createState() => _FolderNotesCardWidgetState();
}

class _FolderNotesCardWidgetState extends State<FolderNotesCardWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    final folderIcon =
        dynamicIconData(widget.iconCodePoint, fontFamily: 'MaterialIcons');
    final folderColor = Color(widget.colorValue);

    // 获取小组件尺寸
    final widgetSize = context.findAncestorStateOfType<_FolderNotesCardWidgetParentState>()
            ?.widgetSize ??
        const LargeSize();
    final scale = widgetSize.scale;
    final isMediumSize = widgetSize == const MediumSize();

    // 根据尺寸限制显示的笔记数量
    final displayNotes = widget.notes.take(isMediumSize ? 3 : 5).toList();
    final moreCount = widget.notesCount > displayNotes.length
        ? widget.notesCount - displayNotes.length
        : 0;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        radius: BorderRadius.circular(24 * scale),
        padding: widgetSize.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部文件夹信息
            Row(
              children: [
                WiredIcon(
                  icon: folderIcon,
                  size: 20,
                  color: folderColor,
                  drawConfig: theme.wired.drawConfig,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.folderPath.isNotEmpty ? widget.folderPath : widget.folderName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.textSub,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 笔记数量徽章：数据色浅底 + 墨线描边
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: dsSketchDecoration(
                    theme: theme,
                    radius: BorderRadius.circular(12),
                    fillColor: folderColor.withValues(alpha: 0.28),
                  ),
                  child: Text(
                    '${widget.notesCount}',
                    style: TextStyle(
                      fontSize: 12,
                      color: folderColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 笔记列表（使用滚动容器防止溢出）
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (displayNotes.isNotEmpty) ...[
                      ...displayNotes.map(
                        (note) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildNoteItem(theme, note),
                        ),
                      ),
                      if (moreCount > 0)
                        Text(
                          '还有 $moreCount 条笔记',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSub,
                          ),
                        ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            '空文件夹',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textSub,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建笔记项
  Widget _buildNoteItem(AppThemeData theme, NoteItemData note) {
    return Row(
      children: [
        DsIcon(DsIconKind.stickyNote, size: 14, color: theme.textSub),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            note.title,
            style: TextStyle(fontSize: 12, color: theme.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatNoteTime(note.updatedAt),
          style: TextStyle(fontSize: 12, color: theme.textSub),
        ),
      ],
    );
  }

  /// 格式化笔记时间为相对时间显示
  String _formatNoteTime(String isoTime) {
    try {
      final date = DateTime.parse(isoTime);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
      if (diff.inDays < 1) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return '${date.month}/${date.day}';
    } catch (e) {
      return '';
    }
  }
}

/// 内部 StatefulWidget 用于传递尺寸信息
class _FolderNotesCardWidgetParent extends StatefulWidget {
  final HomeWidgetSize widgetSize;
  final Widget child;

  const _FolderNotesCardWidgetParent({
    // ignore: unused_element_parameter
    super.key,
    required this.widgetSize,
    required this.child,
  });

  @override
  State<_FolderNotesCardWidgetParent> createState() =>
      _FolderNotesCardWidgetParentState();
}

class _FolderNotesCardWidgetParentState
    extends State<_FolderNotesCardWidgetParent> {
  HomeWidgetSize get widgetSize => widget.widgetSize;

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
