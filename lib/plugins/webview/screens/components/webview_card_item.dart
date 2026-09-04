import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../../models/webview_card.dart';

/// 网址卡片组件
class WebViewCardItem extends StatelessWidget {
  final WebViewCard card;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const WebViewCardItem({
    super.key,
    required this.card,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final isDark = theme.isDark;

    // 生成卡片背景色
    final bgColor =
        card.backgroundColor ?? _generateColorFromString(card.id, isDark);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图标和固定标识
              Row(
                children: [
                  _buildIcon(context),
                  const Spacer(),
                  if (card.isPinned)
                    DsIcon(
                      DsIconKind.pin,
                      size: 16,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                ],
              ),
              const Spacer(),
              // 标题
              Text(
                card.title,
                style: DsTypography.heading.copyWith(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // URL 或描述
              Text(
                card.description ?? card.displayUrl,
                style: DsTypography.caption.copyWith(
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // 标签
              if (card.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children:
                      card.tags.take(2).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.white10
                                    : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: DsTypography.label.copyWith(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    // isDark 用于持久化图标配色（刻意保留 Material 图标与配色逻辑）
    final isDark = DSThemeBridge.resolve(context).isDark;

    // 如果有自定义图标（Material Icons）
    if (card.icon != null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          card.icon,
          size: 24,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      );
    }

    // 如果有 iconUrl（支持网络图片和 emoji 文本）
    if (card.iconUrl != null && card.iconUrl!.isNotEmpty) {
      // 判断是否为网络图片 URL
      final bool isNetworkImage =
          card.iconUrl!.startsWith('http://') ||
          card.iconUrl!.startsWith('https://');

      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child:
            isNetworkImage
                ? Image.network(
                  card.iconUrl!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      card.isLocalFile ? Icons.folder : Icons.language,
                      size: 24,
                      color: isDark ? Colors.white70 : Colors.black54,
                    );
                  },
                )
                : Center(
                  child: Text(
                    card.iconUrl!,
                    style: const TextStyle(fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                ),
      );
    }

    // 默认图标
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        card.isLocalFile ? Icons.folder : Icons.language,
        size: 24,
        color: isDark ? Colors.white70 : Colors.black54,
      ),
    );
  }

  /// 根据字符串生成颜色
  Color _generateColorFromString(String str, bool isDark) {
    final hash = str.hashCode.abs();
    final colors =
        isDark
            ? [
              const Color(0xFF1E3A5F), // 深蓝
              const Color(0xFF2D3E50), // 深灰蓝
              const Color(0xFF1E4D2B), // 深绿
              const Color(0xFF4A3728), // 深棕
              const Color(0xFF3D2E5C), // 深紫
              const Color(0xFF5C3D3D), // 深红
            ]
            : [
              const Color(0xFFE3F2FD), // 浅蓝
              const Color(0xFFF3E5F5), // 浅紫
              const Color(0xFFE8F5E9), // 浅绿
              const Color(0xFFFFF3E0), // 浅橙
              const Color(0xFFE0F7FA), // 浅青
              const Color(0xFFFCE4EC), // 浅粉
            ];
    return colors[hash % colors.length];
  }
}
