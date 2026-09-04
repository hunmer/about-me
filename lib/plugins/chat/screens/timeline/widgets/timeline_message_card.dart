import 'dart:io';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:path/path.dart' as path;
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';
import 'package:aboutme/plugins/chat/models/file_message.dart';
import 'package:aboutme/plugins/chat/utils/date_formatter.dart';
import 'package:aboutme/widgets/file_preview/file_preview_screen.dart';
import 'package:aboutme/plugins/chat/widgets/image_message_widget.dart';
import 'package:aboutme/plugins/chat/widgets/audio_player_widget.dart';
import 'package:aboutme/plugins/chat/services/chat_config_service.dart';
import 'package:aboutme/plugins/chat/screens/timeline/utils/text_highlight.dart';
import 'package:aboutme/plugins/chat/screens/timeline/controllers/timeline_controller.dart';
import 'package:aboutme/plugins/chat/utils/message_options_handler.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/chat_screen.dart';

/// Timeline 中显示的消息卡片组件
class TimelineMessageCard extends StatelessWidget {
  final Message message;
  final Channel channel;
  final TimelineController controller;
  final bool isGridView;
  final ChatConfigService? settingsService;

  const TimelineMessageCard({
    super.key,
    required this.message,
    required this.channel,
    required this.controller,
    this.isGridView = false,
    this.settingsService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final cardColor = message.bubbleColor;

    // 根据视图模式调整卡片样式
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isGridView ? 12 : 8),
        boxShadow: isGridView ? theme.shadows.soft : null,
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
              // 头像和用户名
              Row(
                children: [
                  // 根据设置决定是否显示头像
                  if (settingsService?.showAvatarInTimeline ?? true) ...[
                    Container(
                      width: isGridView ? 28 : 40,
                      height: isGridView ? 28 : 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.primary,
                      ),
                      child:
                          message.user.iconPath != null
                              ? FutureBuilder<String>(
                                future: _getAbsolutePath(
                                  message.user.iconPath!,
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData &&
                                      snapshot.data != null) {
                                    return ClipOval(
                                      child: Image.file(
                                        File(snapshot.data!),
                                        width: isGridView ? 28 : 40,
                                        height: isGridView ? 28 : 40,
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  }
                                  return _buildDefaultAvatar(theme, isGridView);
                                },
                              )
                              : _buildDefaultAvatar(theme, isGridView),
                    ),
                    SizedBox(width: isGridView ? 8 : 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.user.username,
                          style:
                              isGridView
                                  ? DsTypography.heading
                                  : DsTypography.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DateFormatter.formatDateTime(message.date, context),
                          style:
                              isGridView
                                  ? DsTypography.caption.copyWith(fontSize: 10)
                                  : DsTypography.caption,
                        ),
                      ],
                    ),
                  ),
                ],
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
                      child: Text(
                        message.fixedSymbol!,
                        style: TextStyle(
                          color: theme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: isGridView ? 10 : 12,
                        ),
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
                                  NavigationHelper.push(
                                    context,
                                    FilePreviewScreen(
                                      filePath: fileInfo.filePath,
                                      fileName: fileInfo.fileName,
                                      mimeType:
                                          fileInfo.mimeType ?? 'image/jpeg',
                                      fileSize: fileInfo.fileSize,
                                    ),
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
                                  NavigationHelper.push(
                                    context,
                                    FilePreviewScreen(
                                      filePath: fileInfo.filePath,
                                      fileName: fileInfo.fileName,
                                      mimeType:
                                          fileInfo.mimeType ?? 'video/mp4',
                                      fileSize: fileInfo.fileSize,
                                    ),
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
                                  NavigationHelper.push(
                                    context,
                                    FilePreviewScreen(
                                      filePath: fileInfo.filePath,
                                      fileName: fileInfo.fileName,
                                      mimeType:
                                          fileInfo.mimeType ??
                                          'application/octet-stream',
                                      fileSize: fileInfo.fileSize,
                                    ),
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
                        return RichText(
                          maxLines:
                              isGridView ? 12 : null, // 增加最大行数，但仍保持一定限制以避免过长
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: TextHighlight.highlightText(
                              text: message.content,
                              query: controller.searchQuery,
                              style:
                                  isGridView
                                      ? DsTypography.body.copyWith(
                                        fontSize: 13,
                                        height: 1.3, // 调整行高使文本更紧凑
                                      )
                                      : DsTypography.body,
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

  Widget _buildDefaultAvatar(AppThemeData theme, bool isGridView) {
    return Center(
      child: Text(
        message.user.username.isNotEmpty
            ? message.user.username[0].toUpperCase()
            : '?',
        style: TextStyle(
          color: theme.onPrimary,
          fontSize: isGridView ? 12 : 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<String> _getAbsolutePath(String relativePath) async {
    final appDir = await StorageManager.getApplicationDocumentsDirectory();
    return path.join(
      appDir.path,
      'app_data',
      relativePath.replaceFirst('./', ''),
    );
  }
}
