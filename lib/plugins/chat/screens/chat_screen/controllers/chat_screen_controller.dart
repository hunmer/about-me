import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import '../../../../../../utils/audio_service.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class ChatScreenController extends ChangeNotifier {
  final String channelId;
  final Channel _initialChannel;
  Channel get channel =>
      chatPlugin.channelService.channelById(channelId) ?? _initialChannel;
  StreamSubscription<List<Message>>? _messageSubscription;
  bool _disposed = false;
  int _pages = 1;
  Object? loadError;

  void reloadMessages() => _subscribeMessages();

  void _subscribeMessages() {
    _messageSubscription?.cancel();
    isLoading = true;
    _messageSubscription = chatPlugin.channelService
        .watchMessages(
          channelId,
          pages: _pages,
          throughMessageId: autoScroll ? initialMessage?.id : null,
        )
        .listen(
          (items) {
            if (_disposed) return;
            allMessages = items;
            isLoading = false;
            loadError = null;
            currentStartIndex = 0;
            currentEndIndex = items.length;
            _loadMessagesInRange();
            if (autoScroll && initialMessage != null) {
              final target = initialMessage!;
              autoScroll = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_disposed) scrollToMessage(target);
              });
            }
          },
          onError: (Object error) {
            if (_disposed) return;
            isLoading = false;
            loadError = error;
            debugPrint('[Chat] 消息查询失败 channel=$channelId: $error');
            notifyListeners();
          },
        );
  }

  final ChatPlugin chatPlugin;
  final AutoScrollController scrollController = AutoScrollController();
  final _audioService = AudioService();
  bool _needsScroll = false;
  bool _isNavigatingToMessage = false; // 标记是否正在跳转到消息
  bool _isLocatingMessage = false; // 标记是否正在定位消息

  List<Message> messages = [];
  List<Message> allMessages = []; // 完整消息列表
  bool isMultiSelectMode = false;
  final ValueNotifier<Set<String>> selectedMessageIds = ValueNotifier(
    <String>{},
  );
  DateTime? selectedDate;
  bool isLoading = false;
  static const int pageSize = 50;
  int currentStartIndex = 0; // 当前显示的消息起始索引
  int currentEndIndex = 0; // 当前显示的消息结束索引

  Message? messageBeingEdited;
  final TextEditingController editingController = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final TextEditingController draftController = TextEditingController();
  Message? initialMessage;
  Message? highlightMessage;
  bool autoScroll = false;

  late User currentUser;

  ChatScreenController({
    required Channel channel,
    required this.chatPlugin,
    this.initialMessage,
    this.highlightMessage,
    this.autoScroll = false,
  }) : channelId = channel.id,
       _initialChannel = channel {
    // 初始化时计算并加载最后一页
    _initializeAndLoadLastPage();
    _setupScrollListener();
    _initializeCurrentUser();
  }

  void _initializeAndLoadLastPage() => _subscribeMessages();

  void _initializeCurrentUser() {
    currentUser = chatPlugin.userService.currentUser;
  }

  void _setupScrollListener() {
    scrollController.addListener(() {
      // 如果正在跳转到消息或定位消息，不处理滚动事件
      if (_isNavigatingToMessage || _isLocatingMessage) return;

      // 向上滚动（查看更早的消息）
      if (scrollController.position.pixels <=
          scrollController.position.minScrollExtent + 100) {
        _loadMoreMessagesAtBeginning();
      }
      // 向下滚动（查看更新的消息）
      else if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 100) {
        _loadMoreMessagesAtEnd();
      }
    });
  }

  /// 加载指定范围的消息
  void _loadMessagesInRange() {
    if (isLoading) return;
    isLoading = true;
    notifyListeners();

    try {
      messages.clear();
      final endIndex = currentEndIndex.clamp(0, allMessages.length);
      final startIndex = currentStartIndex.clamp(0, endIndex);

      if (startIndex < endIndex) {
        messages.addAll(allMessages.sublist(startIndex, endIndex));
        debugPrint(
          'Loaded messages range: $startIndex-$endIndex (${messages.length} messages)',
        );
      }

      _updateDatesWithMessages();
    } catch (e) {
      debugPrint('Error loading messages in range: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// 在显示列表中滚动到指定索引（使用scroll_to_index）
  Future<void> scrollToMessageAtDisplayIndex(
    int displayIndex, {
    bool preferBeforePosition = false,
  }) async {
    if (displayIndex >= 0 && displayIndex < messages.length) {
      try {
        await scrollController.scrollToIndex(
          displayIndex,
          duration: const Duration(milliseconds: 300),
          preferPosition: preferBeforePosition
              ? AutoScrollPosition.begin
              : AutoScrollPosition.end,
        );
      } catch (e) {
        debugPrint('滚动到消息索引时发生错误: $e');
        // 备用方法：使用固定位置计算
        scrollController.animateTo(
          displayIndex * 60.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  /// 在开头加载更多消息（向上滚动时）
  void _loadMoreMessagesAtBeginning() {
    if (isLoading) return;

    // 如果已经到达列表开头，不加载更多
    if (currentStartIndex <= 0) {
      return;
    }

    // 计算新的起始索引
    final newStartIndex = (currentStartIndex - pageSize).clamp(
      0,
      allMessages.length,
    );
    currentStartIndex = newStartIndex;

    _loadMessagesInRange();
  }

  /// 在末尾加载更多消息（向下滚动时）
  void _loadMoreMessagesAtEnd() {
    if (isLoading) return;

    // 如果已经到达列表末尾，不加载更多
    if (currentEndIndex >= allMessages.length) {
      _pages++;
      _subscribeMessages();
      return;
    }

    // 计算新的结束索引
    final newEndIndex = (currentEndIndex + pageSize).clamp(
      0,
      allMessages.length,
    );
    currentEndIndex = newEndIndex;

    debugPrint('Loading more messages at end, new end index: $currentEndIndex');

    _loadMessagesInRange();
  }

  void _updateDatesWithMessages() {
    if (messages.isEmpty) {
      selectedDate = null;
      notifyListeners();
      return;
    }

    // 默认不选中日期，显示全部消息
    // selectedDate 保持为 null
    notifyListeners();
  }

  void toggleMultiSelectMode() {
    isMultiSelectMode = !isMultiSelectMode;
    if (!isMultiSelectMode) {
      selectedMessageIds.value = {};
    }
    notifyListeners();
  }

  void toggleMessageSelection(String messageId) {
    final newSet = Set<String>.from(selectedMessageIds.value);
    if (newSet.contains(messageId)) {
      newSet.remove(messageId);
    } else {
      newSet.add(messageId);
    }
    selectedMessageIds.value = newSet;
    // 不调用 notifyListeners()，只更新 selectedMessageIds
  }

  // 滚动到指定消息
  Future<void> scrollToMessage(
    Message message, {
    bool preferBeforePosition = false,
  }) async {
    // 在完整消息列表中查找消息
    final targetIndex = allMessages.indexWhere((m) => m.id == message.id);
    if (targetIndex == -1) {
      return;
    }

    _isNavigatingToMessage = true; // 设置标志

    try {
      // 检查消息是否在当前显示范围内
      final displayIndex = targetIndex - currentStartIndex;

      if (displayIndex >= 0 && displayIndex < messages.length) {
        // 消息在当前显示范围内，直接滚动
        scrollToMessageAtDisplayIndex(
          displayIndex,
          preferBeforePosition: preferBeforePosition,
        );
      } else {
        // 消息不在当前显示范围内，调整显示范围
        final halfPageSize = (pageSize / 2).floor();
        currentStartIndex = (targetIndex - halfPageSize).clamp(
          0,
          allMessages.length,
        );
        currentEndIndex = (targetIndex + halfPageSize).clamp(
          0,
          allMessages.length,
        );

        // 如果目标消息接近列表末尾，调整显示范围
        if (targetIndex > allMessages.length - halfPageSize) {
          currentStartIndex = (allMessages.length - pageSize).clamp(
            0,
            allMessages.length,
          );
          currentEndIndex = allMessages.length;
        }

        // 重新加载消息
        _loadMessagesInRange();

        // 等待布局完成后滚动
        Future.delayed(const Duration(milliseconds: 100), () {
          final newDisplayIndex = targetIndex - currentStartIndex;
          scrollToMessageAtDisplayIndex(
            newDisplayIndex,
            preferBeforePosition: preferBeforePosition,
          );
        });
      }
    } catch (e) {
      debugPrint('滚动到消息时发生错误: $e');
    } finally {
      // 延迟重置标志，等待滚动动画完成
      Future.delayed(const Duration(milliseconds: 500), () {
        _isNavigatingToMessage = false;
      });
    }
  }

  void editMessage(Message message) {
    messageBeingEdited = message;
    editingController.text = message.content;
    notifyListeners();
  }

  void cancelEdit() {
    messageBeingEdited = null;
    editingController.clear();
    notifyListeners();
  }

  Future<void> deleteMessage(Message message) async {
    try {
      // 使用 ChannelService 的 deleteMessage 方法正确删除消息
      // 这会从频道的完整消息列表中删除消息并持久化
      final success = await chatPlugin.channelService.deleteMessage(message);

      if (success) {
        // 同步更新控制器中的消息列表
        messages.removeWhere((m) => m.id == message.id);
        notifyListeners();
      }
    } catch (e) {
      // Handle error
      debugPrint('Error deleting message: $e');
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  /// 请求滚动到最新消息
  void requestScrollToLatest() {
    // 如果正在定位消息，不执行自动滚动
    if (_isLocatingMessage) {
      return;
    }

    _needsScroll = true;
    _tryScrollToLatest();
  }

  /// 尝试滚动到最新消息（使用scroll_to_index）
  Future<void> _tryScrollToLatest() async {
    // 如果不需要滚动，直接返回
    if (_disposed || !_needsScroll) return;

    // 如果正在定位消息，取消滚动
    if (_isLocatingMessage) {
      _needsScroll = false;
      return;
    }

    // 如果ScrollController还没有附加到视图，等待下一帧
    if (!scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryScrollToLatest());
      return;
    }

    // 执行滚动到最新消息（索引0）
    try {
      await scrollController.scrollToIndex(
        0,
        duration: const Duration(milliseconds: 300),
        preferPosition: AutoScrollPosition.begin,
      );
      // 滚动成功后重置标志
      _needsScroll = false;
    } catch (e) {
      debugPrint('滚动到最新消息时发生错误: $e');
      // 如果滚动失败，在下一帧重试
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryScrollToLatest());
    }
  }

  /// 发送消息并返回真正存入频道的消息实例（供外部广播事件使用）
  Future<Message?> sendMessage(
    String content, {
    Map<String, dynamic>? metadata,
    String type = 'text',
    Message? replyTo,
  }) async {
    MessageType messageType;
    switch (type) {
      case 'sent':
        messageType = MessageType.sent;
        break;
      case 'received':
        messageType = MessageType.received;
        break;
      case 'file':
        messageType = MessageType.file;
        break;
      case 'image':
        messageType = MessageType.image;
        break;
      case 'video':
        messageType = MessageType.video;
        break;
      case 'audio':
        messageType = MessageType.audio;
        break;
      default:
        messageType = MessageType.sent;
    }
    if (content.trim().isEmpty) return null;

    try {
      final newMessage = await Message.create(
        id: const Uuid().v4(),
        content: content,
        channelId: channel.id,
        user: currentUser,
        date: DateTime.now(),
        type: messageType,
        metadata: metadata,
        replyTo: replyTo,
      );

      final committed = await chatPlugin.channelService.addMessage(
        channelId,
        newMessage,
      );

      // 清除草稿
      draftController.clear();

      // 请求滚动到最新消息
      // 如果之前在定位消息，发送新消息后应该恢复正常的自动滚动
      _isLocatingMessage = false;
      requestScrollToLatest();

      // 确保在主线程中更新UI
      notifyListeners();

      // 根据设置决定是否播放提示音
      if (chatPlugin.settingsService.shouldPlayMessageSound()) {
        // 在主线程上播放声音
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            await _audioService.playMessageSentSound();
          } catch (e) {
            debugPrint('Error playing audio: $e');
          }
        });
      }
      return committed;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return null;
    }
  }

  void saveDraft(String draft) {
    chatPlugin.channelService.saveDraft(channel.id, draft);
  }

  Future<void> clearMessages() async {
    await chatPlugin.channelService.deleteChannelMessages(channel.id);
    if (_disposed) return;
    allMessages.clear();
    messages.clear();
    notifyListeners();
  }

  void retryMessages() => reloadMessages();

  @override
  void dispose() {
    _disposed = true;
    _messageSubscription?.cancel();
    editingController.dispose();
    draftController.dispose();
    scrollController.dispose();
    focusNode.dispose();
    selectedMessageIds.dispose();
    super.dispose();
  }
}
