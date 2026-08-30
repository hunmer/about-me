import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:Memento/widgets/quill_viewer/index.dart';
import 'package:Memento/plugins/diary/models/diary_entry.dart';

/// 日记条目卡片 - 展示一篇日记的摘要
///
/// 从日历页搜索结果卡片抽取的独立组件，
/// 同时供插件页（搜索结果）和主页日记日卡使用，保持 UI 一致。
class DiaryEntryCard extends StatelessWidget {
  /// 日记条目
  final DiaryEntry entry;

  /// 点击回调（查看/编辑）
  final VoidCallback? onTap;

  /// 主题色（日期文字颜色），缺省按日历页逻辑从主题推导
  final Color? primaryColor;

  /// 正文文字颜色，缺省按日历页逻辑从主题推导
  final Color? textColor;

  const DiaryEntryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.primaryColor,
    this.textColor,
  });

  // 日记插件的设计色（与日历页一致）
  static const Color _lightPrimaryColor = Color(0xFFD8BFD8); // Dusty Rose
  static const Color _lightTextColor = Color(0xFF4A4A4A); // Soft charcoal

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTextColor =
        textColor ?? (isDark ? Colors.white : _lightTextColor);
    final effectivePrimaryColor =
        primaryColor ??
        (isDark ? Theme.of(context).colorScheme.primary : _lightPrimaryColor);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 2 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日期和心情
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('yyyy年MM月dd日').format(entry.date),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: effectivePrimaryColor,
                    ),
                  ),
                  if (entry.mood != null)
                    Text(entry.mood!, style: const TextStyle(fontSize: 20)),
                ],
              ),
              const SizedBox(height: 8),

              // 标题
              if (entry.title.isNotEmpty) ...[
                Text(
                  entry.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: effectiveTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],

              // 内容预览（使用QuillViewer，支持Markdown格式化显示）
              SizedBox(
                height: 80, // 限制高度，显示3-4行内容
                child: QuillViewer(
                  data: entry.content,
                  selectable: false, // 只读模式
                ),
              ),
              const SizedBox(height: 12),

              // 底部信息
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${entry.content.length} 字',
                    style: TextStyle(
                      fontSize: 12,
                      color: effectiveTextColor.withValues(alpha: 0.5),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: effectiveTextColor.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
