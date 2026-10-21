import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/quill_viewer/index.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/utils/message_content_utils.dart';
import 'package:aboutme/plugins/chat/widgets/image_message_widget.dart';
import 'package:aboutme/plugins/chat/widgets/image_stack_message_widget.dart';
import 'package:aboutme/plugins/chat/widgets/video_message_widget.dart';
import 'package:aboutme/plugins/chat/widgets/video_stack_message_widget.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/audio_message_bubble.dart';
import 'package:aboutme/widgets/gallery_viewer.dart';
import 'thinking_indicator.dart';
/// 手写字体参数（markdown 显式样式不走 DefaultTextStyle 继承，需显式指定）
const TextStyle _sketchMdFont = TextStyle(
  fontFamily: DsTypography.sketchFamily,
  fontFamilyFallback: ['PingFang SC', 'Microsoft YaHei'],
);

class MessageContent extends StatelessWidget {
  final Message message;
  final Color textColor;

  const MessageContent({
    super.key,
    required this.message,
    required this.textColor,
  });

  /// 打开链接
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// 复选框勾选持久化：用最新 Delta 内容更新消息（不改 editedAt，
  /// 勾选不算编辑痕迹）
  Future<void> _onCheckboxToggled(String updatedContent) async {
    if (message.channelId == null) return;
    final updated = await message.copyWith(content: updatedContent);
    await ChatPlugin.instance.channelService.updateMessage(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    // 检查消息是否处于"正在思考"状态
    final bool isThinking =
        message.metadata?.containsKey('isThinking') == true &&
        message.metadata!['isThinking'] == true;

    if (isThinking) {
      return ThinkingIndicator(textColor: textColor);
    }

    // 检查消息是否包含文件信息
    if (message.metadata?.containsKey(Message.metadataKeyFileInfo) == true) {
      final fileInfo =
          message.metadata![Message.metadataKeyFileInfo]
              as Map<String, dynamic>;
      final filePath = fileInfo['path'] as String?;
      if (filePath == null) {
        return Text(
          '文件路径无效',
          style: TextStyle(color: theme.danger, fontSize: 13),
        );
      }
      final fileName =
          fileInfo['fileName'] as String? ??
          fileInfo['name'] as String? ??
          '未命名文件';
      final mimeType =
          fileInfo['mimeType'] as String? ?? 'application/octet-stream';
      final fileSize =
          fileInfo['fileSize'] as int? ?? fileInfo['size'] as int? ?? 0;
      final type = fileInfo['type'] as String? ?? '';

      if (type == 'image') {
        // 多图消息（fileInfo.images >= 2）：折叠为 WalkStackCard 卡片堆
        final images = fileInfo['images'] as List?;
        if (images != null && images.length >= 2) {
          return ImageStackMessageWidget(
            message: message,
            isOutgoing: message.type == MessageType.sent,
          );
        }
        return ImageMessageWidget(
          message: message,
          isOutgoing: message.type == MessageType.sent,
        );
      } else if (type == 'audio') {
        return AudioMessageBubble(message: message);
      } else if (type == 'video') {
        // 多视频消息（fileInfo.videos >= 2）：折叠为 WalkStackCard 卡片堆
        final videos = fileInfo['videos'] as List?;
        if (videos != null && videos.length >= 2) {
          return VideoStackMessageWidget(
            message: message,
            isOutgoing: message.type == MessageType.sent,
          );
        }
        // 单视频：与图片一致以封面图展示，点击播放
        return VideoMessageWidget(
          message: message,
          isOutgoing: message.type == MessageType.sent,
        );
      } else if (type == 'document' || type == 'file') {
        // 确定文件图标和颜色（文件类型图标无 DS 等价物，保留 Material Icon）
        IconData fileIcon;
        Color iconColor;

        if (mimeType.contains('pdf')) {
          fileIcon = Icons.picture_as_pdf;
          iconColor = Colors.red.shade700;
        } else if (mimeType.contains('word') || mimeType.contains('document')) {
          fileIcon = Icons.description;
          iconColor = Colors.blue.shade700;
        } else if (mimeType.contains('sheet') || mimeType.contains('excel')) {
          fileIcon = Icons.table_chart;
          iconColor = Colors.green.shade700;
        } else if (mimeType.contains('presentation') ||
            mimeType.contains('powerpoint')) {
          fileIcon = Icons.slideshow;
          iconColor = Colors.orange.shade700;
        } else if (mimeType.contains('zip') ||
            mimeType.contains('compressed')) {
          fileIcon = Icons.folder_zip;
          iconColor = Colors.amber.shade700;
        } else {
          fileIcon = Icons.insert_drive_file;
          iconColor = theme.primary;
        }

        return Pressable(
          onPressed: () {
            GalleryViewer.showFilePreview(
              context,
              filePath: filePath,
              fileName: fileName,
              mimeType: mimeType,
              fileSize: fileSize,
            );
          },
          builder: (context, states) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 12.0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(fileIcon, size: 24, color: iconColor),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          fileName,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${(fileSize / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(fontSize: 12, color: theme.textSub),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(8),
                    child: DsIcon(
                      DsIconKind.download,
                      size: 20,
                      color: theme.primary,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      } else {
        // 未知文件类型：通用文件卡片 + 点击全屏预览（GalleryViewer 文件页）
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Pressable(
              onPressed: () {
                GalleryViewer.showFilePreview(
                  context,
                  filePath: filePath,
                  fileName: fileName,
                  mimeType: mimeType,
                  fileSize: fileSize,
                );
              },
              builder: (context, states) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 12.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DsIcon(
                        DsIconKind.file,
                        size: 24,
                        color: theme.primary,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          fileName,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (message.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(message.content),
              ),
          ],
        );
      }
    } else {
      // 普通文本消息（解析结果按 content 缓存）
      final (isPlainText, plainText, hasMarkdown) =
          MessageContentUtils.resolveContent(message.content);

      // 判断是否为纯文本（无 Quill 格式）
      if (isPlainText) {
        // 检测是否包含 Markdown 语法
        if (hasMarkdown) {
          // 深底浅字气泡（实色主色/深色自定义色）上链接用文字色保证对比，浅底气泡保持主色
          final linkColor =
              textColor.computeLuminance() > 0.5 ? textColor : theme.primary;
          // 包含 Markdown，使用 MarkdownBody 渲染
          return MarkdownBody(
            data: plainText,
            selectable: false,
            styleSheet: MarkdownStyleSheet(
              p: _sketchMdFont.copyWith(color: textColor, fontSize: 15, height: 1.5),
              code: _sketchMdFont.copyWith(
                backgroundColor: theme.surfaceAlt,
                color: textColor,
                fontSize: 14,
              ),
              codeblockDecoration: BoxDecoration(
                color: theme.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              codeblockPadding: const EdgeInsets.all(12),
              blockquote: _sketchMdFont.copyWith(
                color: textColor.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
              blockquoteDecoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: theme.primary, width: 4),
                ),
              ),
              blockquotePadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              h1: _sketchMdFont.copyWith(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              h2: _sketchMdFont.copyWith(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              h3: _sketchMdFont.copyWith(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              listBullet: _sketchMdFont.copyWith(color: textColor, fontSize: 15),
              a: _sketchMdFont.copyWith(
                color: linkColor,
                decoration: TextDecoration.underline,
              ),
              strong: _sketchMdFont.copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
              em: _sketchMdFont.copyWith(
                color: textColor,
                fontStyle: FontStyle.italic,
              ),
            ),
            onTapLink: (text, href, title) {
              if (href != null) {
                _launchURL(href);
              }
            },
          );
        } else {
          // 纯文本，使用 Text 显示（保留换行符）
          return Text(
            plainText,
            style: TextStyle(color: textColor, fontSize: 15),
          );
        }
      } else {
        // 包含 Quill 格式，使用 QuillViewer 显示（禁用选择功能以避免与长按菜单冲突）
        return QuillViewer(
          data: message.content,
          selectable: false,
          // 复选框勾选后把最新 Delta 写回消息（广播刷新气泡并持久化）
          onCheckboxToggle: _onCheckboxToggled,
          customStyles: quill.DefaultStyles(
            paragraph: quill.DefaultTextBlockStyle(
              TextStyle(color: textColor),
              const quill.HorizontalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              null,
            ),
            h1: quill.DefaultTextBlockStyle(
              TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              const quill.HorizontalSpacing(0, 0),
              const quill.VerticalSpacing(8, 4),
              const quill.VerticalSpacing(0, 0),
              null,
            ),
            h2: quill.DefaultTextBlockStyle(
              TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              const quill.HorizontalSpacing(0, 0),
              const quill.VerticalSpacing(6, 4),
              const quill.VerticalSpacing(0, 0),
              null,
            ),
            h3: quill.DefaultTextBlockStyle(
              TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              const quill.HorizontalSpacing(0, 0),
              const quill.VerticalSpacing(4, 4),
              const quill.VerticalSpacing(0, 0),
              null,
            ),
            code: quill.DefaultTextBlockStyle(
              TextStyle(
                backgroundColor: theme.surfaceAlt,
                color: textColor,
                fontFamily: 'monospace',
              ),
              const quill.HorizontalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              null,
            ),
            inlineCode: quill.InlineCodeStyle(
              backgroundColor: theme.surfaceAlt,
              style: TextStyle(color: textColor, fontFamily: 'monospace'),
            ),
          ),
        );
      }
    }
  }
}
