import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 手写字体参数（markdown 显式样式不走 DefaultTextStyle 继承，需显式指定）
const TextStyle _sketchFont = TextStyle(
  fontFamily: DsTypography.sketchFamily,
  fontFamilyFallback: ['PingFang SC', 'Microsoft YaHei'],
);

/// Markdown内容渲染组件
///
/// 使用flutter_markdown渲染消息内容
class MarkdownContent extends StatelessWidget {
  final String content;
  final bool selectable;

  /// 正文文字颜色（默认主题正文色；深色气泡如用户主色气泡需传浅色）
  final Color? textColor;

  const MarkdownContent({
    super.key,
    required this.content,
    this.selectable = true,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final bodyColor = textColor ?? theme.text;
    return MarkdownBody(
      data: content,
      selectable: selectable,
      styleSheet: MarkdownStyleSheet(
        // 极简风格配置
        p: _sketchFont.copyWith(fontSize: 15, height: 1.5, color: bodyColor),
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
        blockquote: _sketchFont.copyWith(
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
        h1: _sketchFont.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: bodyColor,
        ),
        h2: _sketchFont.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: bodyColor,
        ),
        h3: _sketchFont.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: bodyColor,
        ),
        listBullet: _sketchFont.copyWith(fontSize: 15, color: bodyColor),
        tableBody: _sketchFont.copyWith(fontSize: 14, color: bodyColor),
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
