/// 笔记列表卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 主题色"Notes"图标徽章 / 墨线分隔的笔记列表（标题 + 时间预览 + 缩略图，
/// 逐项错峰浮现）。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 笔记数据模型
class NoteItem {
  final String title;
  final String time;
  final String preview;
  final String? imageUrl;

  const NoteItem({
    required this.title,
    required this.time,
    required this.preview,
    this.imageUrl,
  });

  /// 从 JSON 创建
  factory NoteItem.fromJson(Map<String, dynamic> json) {
    return NoteItem(
      title: json['title'] as String? ?? '',
      time: json['time'] as String? ?? '',
      preview: json['preview'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'time': time,
      'preview': preview,
      'imageUrl': imageUrl,
    };
  }
}

/// 笔记列表卡片小组件
class NotesListCardWidget extends StatefulWidget {
  final List<NoteItem> notes;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const NotesListCardWidget({
    super.key,
    required this.notes,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory NotesListCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final notesJson = props['notes'] as List<dynamic>?;

    return NotesListCardWidget(
      notes:
          notesJson
              ?.map((e) => NoteItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<NotesListCardWidget> createState() => _NotesListCardWidgetState();
}

class _NotesListCardWidgetState extends State<NotesListCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: ConstrainedBox(
        constraints: widget.size.getHeightConstraints(),
        child: DsSketchPanel(
          theme: theme,
          width: widget.inline ? double.maxFinite : null,
          height: widget.inline ? double.maxFinite : null,
          radius: BorderRadius.circular(24 * scale),
          padding: widget.size.getPadding(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(theme),
              _buildDivider(theme),
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < widget.notes.length; i++)
                        _buildNoteItem(
                          theme,
                          widget.notes[i],
                          i,
                          hasDivider: i < widget.notes.length - 1,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 头部：主题色实底"Notes"图标徽章（墨线描边）
  Widget _buildHeader(AppThemeData theme) {
    final scale = widget.size.scale;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 5 * scale,
      ),
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(10 * scale),
        fillColor: theme.primary,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsIcon(
            DsIconKind.folder,
            size: widget.size.getIconSize() * 0.8,
            color: theme.onPrimary,
          ),
          SizedBox(width: widget.size.getItemSpacing() * 0.6),
          Text(
            'Notes',
            style: TextStyle(
              color: theme.onPrimary,
              fontSize: widget.size.getTitleFontSize() * 0.8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 分隔线：淡墨细线
  Widget _buildDivider(AppThemeData theme) {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(vertical: widget.size.getSmallSpacing()),
      color: theme.ink.withValues(alpha: 0.18),
    );
  }

  Widget _buildNoteItem(
    AppThemeData theme,
    NoteItem note,
    int index, {
    required bool hasDivider,
  }) {
    // 计算每个元素的延迟动画（逐项错峰浮现）
    final itemAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        index * 0.1,
        0.5 + index * 0.1,
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: itemAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: itemAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - itemAnimation.value)),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: widget.size.getItemSpacing() * 0.75,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: widget.size.getSubtitleFontSize(),
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: widget.size.getItemSpacing() / 2),
                      Text(
                        '${note.time} ${note.preview}',
                        style: TextStyle(
                          color: theme.textSub,
                          fontSize: widget.size.getLegendFontSize(),
                          height: 1.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (note.imageUrl != null) ...[
                  SizedBox(width: widget.size.getItemSpacing()),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      note.imageUrl!,
                      width: widget.size.getThumbnailImageSize(),
                      height: widget.size.getThumbnailImageSize(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: widget.size.getThumbnailImageSize(),
                          height: widget.size.getThumbnailImageSize(),
                          decoration: dsSketchDecoration(
                            theme: theme,
                            radius: BorderRadius.circular(8),
                            fillColor: theme.surfaceAlt,
                          ),
                          child: DsIcon(
                            DsIconKind.image,
                            size: widget.size.getIconSize() - 4,
                            color: theme.textSub,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasDivider)
            Container(height: 1, color: theme.ink.withValues(alpha: 0.18)),
        ],
      ),
    );
  }
}
