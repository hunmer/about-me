import 'package:flutter/material.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/screens/timeline/models/timeline_filter.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';

/// Timeline 基础控制器，包含共享状态和基本功能
abstract class BaseTimelineController extends ChangeNotifier {
  final ChatPlugin chatPlugin;
  final TextEditingController searchController;
  final ScrollController scrollController;

  // 消息操作回调
  final void Function(Message)? onMessageEdit;
  final Future<void> Function(Message)? onMessageDelete;
  final void Function(Message)? onMessageCopy;
  final void Function(Message, String?)? onSetFixedSymbol;
  final void Function(Message, Color?)? onSetBubbleColor;
  final void Function(Message)? onToggleFavorite;

  // 共享状态
  List<Message> allMessages = [];
  List<Message> filteredMessages = [];
  List<Message> displayMessages = [];
  bool isLoading = false;
  String searchQuery = '';
  final TimelineFilter filter;
  bool isFilterActive = false;

  /// 获取当前显示的消息列表
  List<Message> get messages => displayMessages;

  BaseTimelineController({
    required this.chatPlugin,
    required this.searchController,
    required this.scrollController,
    required this.filter,
    this.onMessageEdit,
    this.onMessageDelete,
    this.onMessageCopy,
    this.onSetFixedSymbol,
    this.onSetBubbleColor,
    this.onToggleFavorite,
  });

  /// 保存时间线状态的抽象方法
  Future<void> saveTimelineState();

  @override
  void dispose() {
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }
}

/// 消息卡片（TimelineMessageCard）依赖的控制器能力：
/// 搜索高亮词 + 消息操作入口。
/// 完整时间线控制器（TimelineController）与页面级轻量控制器均实现该接口
abstract class MessageActionsController implements BaseTimelineController {
  /// 处理消息编辑
  void handleMessageEdit(Message message);

  /// 处理消息删除
  Future<void> handleMessageDelete(Message message);

  /// 处理消息复制
  void handleMessageCopy(Message message);

  /// 处理设置固定标记
  void handleSetFixedSymbol(Message message, String? symbol);

  /// 处理设置气泡颜色
  void handleSetBubbleColor(Message message, Color? color);

  /// 处理消息收藏
  void handleToggleFavorite(Message message);
}
