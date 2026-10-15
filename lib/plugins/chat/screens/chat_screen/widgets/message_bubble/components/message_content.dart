import 'dart:convert';
import 'package:aboutme/utils/image_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/quill_viewer/index.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/widgets/image_message_widget.dart';
import 'package:aboutme/widgets/file_preview/index.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/audio_message_bubble.dart';
import 'package:aboutme/widgets/file_preview/file_preview_screen.dart';
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

  /// 内容解析结果缓存：key 为原始 content，
  /// 避免气泡每次重建（如选中态切换）都重复 jsonDecode 与正则检测
  static final Map<String, (bool, String, bool)> _resolveCache = {};
  static const int _maxCacheEntries = 300;

  /// 返回 (是否纯文本, 提取的文本, 是否含 Markdown)
  (bool, String, bool) _resolveContent(String content) {
    final cached = _resolveCache[content];
    if (cached != null) return cached;

    final isPlain = _isPlainText(content);
    final text = isPlain ? _extractPlainText(content) : content;
    final result = (isPlain, text, isPlain && _containsMarkdown(text));

    if (_resolveCache.length >= _maxCacheEntries) {
      _resolveCache.remove(_resolveCache.keys.first);
    }
    _resolveCache[content] = result;
    return result;
  }

  /// 判断内容是否为纯文本（没有任何 Quill 格式）
  bool _isPlainText(String content) {
    if (content.isEmpty) return true;

    try {
      // 尝试解析为 JSON
      final json = jsonDecode(content);

      // 检查是否为 Quill Delta 格式
      if (json is! List) return true;

      // 遍历所有操作
      for (var op in json) {
        if (op is! Map<String, dynamic>) continue;

        // 检查是否有格式属性
        if (op.containsKey('attributes')) {
          final attributes = op['attributes'];
          if (attributes != null &&
              attributes is Map &&
              attributes.isNotEmpty) {
            return false; // 包含格式属性，不是纯文本
          }
        }

        // 检查 insert 的内容类型
        if (op.containsKey('insert')) {
          final insert = op['insert'];
          // 如果 insert 是 Map（如嵌入的图片、视频等），不是纯文本
          if (insert is Map) {
            return false;
          }
        }
      }

      return true; // 没有任何格式属性，是纯文本
    } catch (e) {
      // JSON 解析失败，说明是纯文本
      return true;
    }
  }

  /// 从 Quill Delta 格式中提取纯文本内容
  String _extractPlainText(String content) {
    try {
      final json = jsonDecode(content);
      if (json is! List) return content;

      final buffer = StringBuffer();
      for (var op in json) {
        if (op is Map<String, dynamic> && op.containsKey('insert')) {
          final insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          }
        }
      }

      return buffer.toString();
    } catch (e) {
      return content;
    }
  }

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

  /// 常见 Markdown 语法的正则表达式（只编译一次）
  static final List<RegExp> _markdownPatterns = [
    RegExp(r'^#{1,6}\s', multiLine: true), // 标题: # ## ###
    RegExp(r'\*\*[^*]+\*\*'), // 粗体: **text**
    RegExp(r'__[^_]+__'), // 粗体: __text__
    RegExp(r'(?<!\*)\*(?!\*)[^*]+\*(?!\*)'), // 斜体: *text*
    RegExp(r'(?<!_)_(?!_)[^_]+_(?!_)'), // 斜体: _text_
    RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), // 链接: [text](url)
    RegExp(r'!\[([^\]]*)\]\(([^)]+)\)'), // 图片: ![alt](url)
    RegExp(r'`[^`]+`'), // 行内代码: `code`
    RegExp(r'```[\s\S]*?```', multiLine: true), // 代码块: ```code```
    RegExp(r'^>\s', multiLine: true), // 引用: > text
    RegExp(r'^[-*+]\s', multiLine: true), // 无序列表: - * +
    RegExp(r'^\d+\.\s', multiLine: true), // 有序列表: 1. 2.
    RegExp(r'^---+$', multiLine: true), // 水平线: ---
    RegExp(r'^\*\*\*+$', multiLine: true), // 水平线: ***
  ];

  /// 检测文本是否包含 Markdown 语法
  bool _containsMarkdown(String text) {
    for (final pattern in _markdownPatterns) {
      if (pattern.hasMatch(text)) {
        return true;
      }
    }
    return false;
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
        return ImageMessageWidget(
          message: message,
          isOutgoing: message.type == MessageType.sent,
        );
      } else if (type == 'audio') {
        return AudioMessageBubble(
          message: message,
          isCurrentUser: message.type == MessageType.sent,
          textColor: textColor,
        );
      } else if (type == 'video') {
        return Pressable(
          onPressed: () {
            NavigationHelper.push(
              context,
              FilePreviewScreen(
                filePath: filePath,
                fileName: fileName,
                mimeType: mimeType,
                fileSize: fileSize,
              ),
            );
          },
          builder: (context, states) {
            final pressed = states.contains(WidgetState.pressed);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: DsIcon(
                            DsIconKind.video,
                            size: 24,
                            color: theme.primary,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fileName,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: pressed ? theme.primary : textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${(fileSize / 1024).toStringAsFixed(1)} KB',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
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
            NavigationHelper.push(
              context,
              FilePreviewScreen(
                filePath: filePath,
                fileName: fileName,
                mimeType: mimeType,
                fileSize: fileSize,
              ),
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
        return FutureBuilder<String>(
          future: ImageUtils.getAbsolutePath(filePath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilePreviewScreen(
                    filePath: snapshot.data!,
                    fileName: fileName,
                    mimeType: mimeType,
                    fileSize: fileSize,
                  ),
                  if (message.content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(message.content),
                    ),
                ],
              );
            } else {
              return Center(child: DSLoadingDots(color: theme.textSub));
            }
          },
        );
      }
    } else {
      // 普通文本消息（解析结果按 content 缓存）
      final (isPlainText, plainText, hasMarkdown) = _resolveContent(
        message.content,
      );

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
