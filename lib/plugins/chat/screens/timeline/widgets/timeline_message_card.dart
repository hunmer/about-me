import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';
import 'package:aboutme/plugins/chat/models/file_message.dart';
import 'package:aboutme/plugins/chat/utils/date_formatter.dart';
import 'package:aboutme/plugins/chat/utils/message_content_utils.dart';
import 'package:aboutme/widgets/gallery_viewer.dart';
import 'package:aboutme/plugins/chat/widgets/image_message_widget.dart';
import 'package:aboutme/plugins/chat/widgets/audio_player_widget.dart';
import 'package:aboutme/plugins/chat/screens/timeline/utils/text_highlight.dart';
import 'package:aboutme/plugins/chat/screens/timeline/controllers/timeline_controller/base_controller.dart';
import 'package:aboutme/plugins/chat/utils/message_options_handler.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_bubble/components/fixed_symbol.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/chat_screen.dart';

/// Timeline 中显示的消息卡片组件
class TimelineMessageCard extends StatelessWidget {
  final Message message;
  final Channel channel;
  final MessageActionsController controller;
  final bool isGridView;

  const TimelineMessageCard({
    super.key,
    required this.message,
    required this.channel,
    required this.controller,
    this.isGridView = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    // 瀑布流卡片：气泡色描边，内部背景为气泡色调亮的浅色底
    final bubbleColor = message.bubbleColor;
    final cardColor = isGridView && bubbleColor != null
        ? Color.lerp(bubbleColor, Colors.white, 0.85)
        : bubbleColor;

    // 根据视图模式调整卡片样式
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isGridView ? 12 : 8),
        boxShadow: isGridView ? theme.shadows.soft : null,
        border: isGridView
            ? Border.all(
                color: bubbleColor ?? theme.primary,
                width: 1.8,
              )
            : null,
      ),
      child: InkWell(
        onLongPress: () {
          MessageOptionsHandler.showOptionsDialog(
            context: context,
            message: message,
            onMessageEdit: (_) => controller.handleMessageEdit(message),
            onMessageDelete: (_) => controller.handleMessageDelete(message),
            onMessageCopy: (_) => controller.handleMessageCopy(message),
            onSetFixedSymbol:
                (msg, symbol) =>
                    controller.handleSetFixedSymbol(message, symbol),
            onSetBubbleColor:
                (msg, color) => controller.handleSetBubbleColor(message, color),
            onToggleFavorite: (_) => controller.handleToggleFavorite(message),
          );
        },
        onTap: () async {
          // 设置当前活跃频道，这是关键步骤！
          ChatPlugin.instance.channelService.setCurrentChannel(channel);

          // 导航到频道页面并定位到消息
          // 使用 MaterialPageRoute 直接构建 ChatScreen 页面
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => ChatScreen(
                    channel: channel,
                    initialMessage: message, // 用于初始滚动定位
                    highlightMessage: message, // 用于高亮显示
                    autoScroll: true, // 明确指示需要自动滚动
                  ),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(isGridView ? 8 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 时间
              Text(
                DateFormatter.formatDateTime(message.date, context),
                style:
                    isGridView
                        ? DsTypography.caption.copyWith(fontSize: 10)
                        : DsTypography.caption,
              ),

              SizedBox(height: isGridView ? 8 : 12),

              // 消息内容（带高亮）和固定字符
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 显示固定字符（如果有）
                  if (message.fixedSymbol != null) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isGridView ? 4 : 6,
                        vertical: isGridView ? 1 : 2,
                      ),
                      margin: EdgeInsets.only(right: isGridView ? 4 : 8),
                      decoration: BoxDecoration(
                        color: theme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: buildFixedSymbolChild(
                        message.fixedSymbol!,
                        style: TextStyle(
                          color: theme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: isGridView ? 10 : 12,
                        ),
                        imageSize: isGridView ? 12 : 14,
                      ),
                    ),
                  ],

                  // 消息内容
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 检查消息类型
                        if (message.metadata?[Message.metadataKeyFileInfo] !=
                            null) {
                          final fileInfo = FileMessage.fromJson(
                            Map<String, dynamic>.from(
                              message.metadata![Message.metadataKeyFileInfo],
                            ),
                          );

                          // 根据文件类型显示不同的预览
                          switch (fileInfo.type) {
                            case FileMessageType.image:
                              return GestureDetector(
                                onTap: () {
                                  GalleryViewer.showFilePreview(
                                    context,
                                    filePath: fileInfo.filePath,
                                    fileName: fileInfo.fileName,
                                    mimeType:
                                        fileInfo.mimeType ?? 'image/jpeg',
                                    fileSize: fileInfo.fileSize,
                                  );
                                },
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: isGridView ? 120 : 200,
                                    maxHeight: isGridView ? 120 : 200,
                                  ),
                                  child: ImageMessageWidget(
                                    message: message,
                                    isOutgoing: false,
                                  ),
                                ),
                              );

                            case FileMessageType.document:
                            case FileMessageType.audio:
                              return Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      isGridView
                                          ? constraints.maxWidth * 0.8
                                          : constraints.maxWidth,
                                ),
                                child: AudioPlayerWidget(
                                  audioPath: fileInfo.filePath,
                                  durationInSeconds: message.audioDuration,
                                  isLocalFile: true,
                                  primaryColor: theme.primary,
                                  backgroundColor: theme.surface,
                                  progressColor: theme.primary,
                                ),
                              );

                            case FileMessageType.video:
                              return GestureDetector(
                                onTap: () {
                                  GalleryViewer.showFilePreview(
                                    context,
                                    filePath: fileInfo.filePath,
                                    fileName: fileInfo.fileName,
                                    mimeType:
                                        fileInfo.mimeType ?? 'video/mp4',
                                    fileSize: fileInfo.fileSize,
                                  );
                                },
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: isGridView ? 120 : 200,
                                    maxHeight: isGridView ? 120 : 200,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.surface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      DsIcon(
                                        DsIconKind.video,
                                        size: isGridView ? 24.0 : 32.0,
                                        color: theme.primary,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          fileInfo.originalFileName,
                                          style: TextStyle(
                                            fontSize: isGridView ? 10 : 12,
                                            color: theme.text,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                    ],
                                  ),
                                ),
                              );

                            default: // 文档和其他类型文件
                              return GestureDetector(
                                onTap: () {
                                  GalleryViewer.showFilePreview(
                                    context,
                                    filePath: fileInfo.filePath,
                                    fileName: fileInfo.fileName,
                                    mimeType:
                                        fileInfo.mimeType ??
                                        'application/octet-stream',
                                    fileSize: fileInfo.fileSize,
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      fileInfo.getIcon(),
                                      size: isGridView ? 16 : 24,
                                      color: theme.primary,
                                    ),
                                    SizedBox(width: isGridView ? 4 : 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            fileInfo.originalFileName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: isGridView ? 12 : 14,
                                              color: theme.text,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            fileInfo.formattedSize,
                                            style: TextStyle(
                                              fontSize: isGridView ? 10 : 12,
                                              color: theme.textSub,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                          }
                        }
                        final (_, text, hasMarkdown) =
                            MessageContentUtils.resolveContent(message.content);
                        // Markdown 内容用 MarkdownBody 渲染；
                        // 搜索时退回纯文本以保留关键词高亮
                        if (hasMarkdown && controller.searchQuery.isEmpty) {
                          return _buildMarkdownBody(context, text);
                        }
                        return RichText(
                          maxLines:
                              isGridView ? 12 : null, // 增加最大行数，但仍保持一定限制以避免过长
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: TextHighlight.highlightText(
                              text: text,
                              query: controller.searchQuery,
                              style:
                                  isGridView
                                      ? DsTypography.body.copyWith(
                                        fontSize: 13,
                                        height: 1.3, // 调整行高使文本更紧凑
                                        color: theme.text,
                                      )
                                      : DsTypography.body.copyWith(
                                        color: theme.text,
                                      ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              SizedBox(height: isGridView ? 8 : 12),

              // 频道信息
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DsIcon(
                    DsIconKind.chat,
                    size: isGridView ? 12.0 : 16.0,
                    color: theme.textSub,
                  ),
                  SizedBox(width: isGridView ? 2 : 4),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: TextHighlight.highlightText(
                        text: channel.title,
                        query: controller.searchQuery,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                          fontSize: isGridView ? 10 : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Markdown 消息渲染，样式对齐聊天气泡的 MarkdownBody
  Widget _buildMarkdownBody(BuildContext context, String data) {
    final theme = DSThemeBridge.resolve(context);
    // 手写字体参数（markdown 显式样式不走 DefaultTextStyle 继承，需显式指定）
    final base = TextStyle(
      fontFamily: DsTypography.sketchFamily,
      fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei'],
      color: theme.text,
      fontSize: isGridView ? 13.0 : 15.0,
      height: 1.4,
    );
    return MarkdownBody(
      data: data,
      selectable: false,
      styleSheet: MarkdownStyleSheet(
        p: base,
        code: base.copyWith(
          backgroundColor: theme.surfaceAlt,
          fontSize: (isGridView ? 13.0 : 15.0) - 1,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquote: base.copyWith(
          color: theme.text.withValues(alpha: 0.8),
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: theme.primary, width: 4)),
        ),
        blockquotePadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        h1: base.copyWith(
          fontSize: (isGridView ? 13.0 : 15.0) + 8,
          fontWeight: FontWeight.bold,
        ),
        h2: base.copyWith(
          fontSize: (isGridView ? 13.0 : 15.0) + 6,
          fontWeight: FontWeight.bold,
        ),
        h3: base.copyWith(
          fontSize: (isGridView ? 13.0 : 15.0) + 4,
          fontWeight: FontWeight.bold,
        ),
        listBullet: base,
        a: base.copyWith(
          color: theme.primary,
          decoration: TextDecoration.underline,
        ),
        strong: base.copyWith(fontWeight: FontWeight.bold),
        em: base.copyWith(fontStyle: FontStyle.italic),
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
