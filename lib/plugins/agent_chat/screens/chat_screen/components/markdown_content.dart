import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// Markdown内容渲染组件
///
/// 使用flutter_markdown渲染消息内容
class MarkdownContent extends StatelessWidget {
  final String content;
  final bool selectable;

  const MarkdownContent({
    super.key,
    required this.content,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return MarkdownBody(
      data: content,
      selectable: selectable,
      styleSheet: MarkdownStyleSheet(
        // 极简风格配置
        p: const TextStyle(fontSize: 15, height: 1.5),
        code: TextStyle(
          backgroundColor: theme.surfaceAlt,
          fontFamily: 'monospace',
          fontSize: 14,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.surfaceAlt,
          borderRadius: theme.radii.sm,
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquote: TextStyle(
          color: theme.textSub,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          color: theme.primary.mixWhite(0.9),
          border: Border(left: BorderSide(color: theme.primary, width: 4)),
        ),
        blockquotePadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        listBullet: const TextStyle(fontSize: 15),
        tableBody: const TextStyle(fontSize: 14),
        tableBorder: TableBorder.all(
          color: theme.textSub.withValues(alpha: 0.4),
          width: 1,
        ),
        tableColumnWidth: const FlexColumnWidth(),
        tableCellsPadding: const EdgeInsets.all(8),
      ),
      onTapLink: (text, href, title) {
        if (href != null) {
          _launchURL(href);
        }
      },
    );
  }

  /// 打开链接
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
