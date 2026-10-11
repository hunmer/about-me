import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:agentlib/openai_compat.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';

import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/file_attachment.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/moments/models/moment_post.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';

/// Agent 朋友圈动态服务
///
/// 数据：`openai/moments/posts.json`（新帖插头部，上限 500 条）
class MomentsService extends ChangeNotifier {
  MomentsService._();

  static final MomentsService instance = MomentsService._();

  static const _postsPath = 'openai/moments/posts.json';
  static const _maxPosts = 500;

  /// 单帖图片数上限（多图网格 3 列展示）
  static const maxImagesPerPost = 9;
  static const imagesDir = 'openai/moments/images';

  /// 工具执行上下文：当前会话与其 agent
  /// （由 ChatController.initialize 与 AgentChainExecutor 维护）
  String? currentAgentId;
  String? currentConversationId;

  /// 当前聊天界面的 MessageService 实例（由 ChatController.initialize 注册）。
  ///
  /// ChatScreen 每次打开会自建 MessageService（而非插件级单例），两个实例
  /// 各自缓存、先后落盘同一文件会互相覆盖——图片消息必须写进聊天 UI 正在
  /// 使用的那个实例，否则会被其后续落盘抹掉
  MessageService? currentMessageService;

  List<MomentPost> _posts = [];
  bool _loaded = false;

  List<MomentPost> get posts => List.unmodifiable(_posts);

  Future<void> loadPosts({bool force = false}) async {
    if (_loaded && !force) return;
    try {
      final data = await AboutmeDataService.instance.readPath(_postsPath);
      final list =
          (data is Map ? data['posts'] : null) as List<dynamic>? ?? [];
      _posts = list
          .map(
            (e) => MomentPost.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      _posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('[Moments] 读取帖子失败: $e');
      _posts = [];
    }
    _loaded = true;
    notifyListeners();
  }

  /// 发布动态（新帖插到最前；图片数超过上限时截断）
  Future<MomentPost> addPost({
    required String agentId,
    required String text,
    List<String> images = const [],
    String source = 'agent',
  }) async {
    await loadPosts();
    final post = MomentPost(
      id: const Uuid().v4(),
      agentId: agentId,
      text: text,
      images: List.of(images.take(maxImagesPerPost)),
      createdAt: DateTime.now(),
      source: source,
    );
    _posts.insert(0, post);
    if (_posts.length > _maxPosts) {
      _posts = _posts.sublist(0, _maxPosts);
    }
    await _save();
    // 成就系统计数（A10 朋友圈原住民）
    EventManager.instance.broadcast('moment_posted', EventArgs('moment_posted'));
    return post;
  }

  Future<void> deletePost(String postId) async {
    await loadPosts();
    _posts.removeWhere((p) => p.id == postId);
    await _save();
  }

  // ---------- 点赞 / 评论 ----------

  /// 切换点赞状态
  Future<void> toggleLike(String postId) async {
    await loadPosts();
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index < 0) return;
    final old = _posts[index];
    _posts[index] = MomentPost(
      id: old.id,
      agentId: old.agentId,
      text: old.text,
      images: old.images,
      createdAt: old.createdAt,
      source: old.source,
      liked: !old.liked,
      comments: old.comments,
    );
    await _save();
  }

  /// 添加评论（用户评论后异步触发 agent 回复）
  Future<void> addComment(
    String postId,
    String text, {
    bool isAgent = false,
  }) async {
    final comment = MomentComment(
      id: const Uuid().v4(),
      text: text,
      isAgent: isAgent,
      createdAt: DateTime.now(),
    );
    await loadPosts();
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index < 0) return;
    final old = _posts[index];
    final updated = MomentPost(
      id: old.id,
      agentId: old.agentId,
      text: old.text,
      images: old.images,
      createdAt: old.createdAt,
      source: old.source,
      liked: old.liked,
      comments: [...old.comments, comment],
    );
    _posts[index] = updated;
    await _save();
    // agent 异步回复（稍作延迟模拟"正在看评论"，不打断 UI，失败静默）
    if (!isAgent) {
      unawaited(
        Future.delayed(
          Duration(seconds: 2, milliseconds: Random().nextInt(3000)),
        ).then((_) => _autoAgentReply(updated)),
      );
    }
  }

  /// 用户评论后让 agent 用 LLM 生成一条回复评论
  Future<void> _autoAgentReply(MomentPost post) async {
    try {
      final agent = await AgentController().getAgent(post.agentId);
      if (agent == null) return;
      final userComments = post.comments
          .where((c) => !c.isAgent)
          .map((c) => c.text)
          .join('\n');
      final system =
          '${agent.description.isEmpty ? '' : '${agent.description}\n\n'}'
          '你是「${agent.name}」。你发了一条朋友圈：「${post.text}」。\n'
          '用户评论了你：「$userComments」。\n'
          '请以你的口吻回复这条评论，像朋友之间随意自然，1~2 句话。\n'
          '只输出回复内容本身，不要引号、表情符号可选、不要任何解释。';
      final reply = await RequestService.chat(
        '（回复朋友圈评论）',
        agent,
        contextMessages: [ChatCompletionMessage.system(content: system)],
      );
      final text = reply.trim();
      if (text.isEmpty || text.startsWith('Error:')) {
        debugPrint('[Moments] agent 回复评论失败: $text');
        return;
      }
      // 帖子可能已被删除
      final fresh = _posts.where((p) => p.id == post.id).firstOrNull;
      if (fresh == null) return;
      await addComment(post.id, text, isAgent: true);
      debugPrint('[Moments] agent 已回复评论 | ${agent.name}');
    } catch (e) {
      debugPrint('[Moments] agent 回复评论异常: $e');
    }
  }

  Future<void> _save() async {
    await AboutmeDataService.instance.writePath(_postsPath, {
      'posts': _posts.map((p) => p.toJson()).toList(),
    });
    notifyListeners();
  }

  /// 发送纯图 AI 消息到会话（复用 agent_chat 图片消息渲染）
  ///
  /// [imageAbsolutePaths] 必须是本地绝对路径（message_bubble 用 Image.file 渲染）
  Future<bool> sendImageToChat({
    required String agentId,
    required List<String> imageAbsolutePaths,
    String? conversationId,
  }) async {
    try {
      // 优先用聊天 UI 注册的实例，避免双实例落盘互相覆盖
      final messageService =
          currentMessageService ??
          AgentChatPlugin.instance.conversationController?.messageService;
      final cid = conversationId ?? currentConversationId;
      if (messageService == null || cid == null) {
        debugPrint('[Moments] 发送图片消息失败: 无可用会话');
        return false;
      }
      debugPrint('[Moments] 发送图片消息 → 会话 $cid');
      final attachments = <FileAttachment>[];
      for (final abs in imageAbsolutePaths) {
        final file = File(abs);
        if (!await file.exists()) continue;
        attachments.add(
          FileAttachment.image(
            filePath: abs,
            fileName: abs.split(Platform.pathSeparator).last,
            fileSize: await file.length(),
          ),
        );
      }
      if (attachments.isEmpty) {
        debugPrint('[Moments] 发送图片消息失败: 文件不存在 $imageAbsolutePaths');
        return false;
      }
      final message = ChatMessage(
        id: const Uuid().v4(),
        conversationId: cid,
        content: '',
        isUser: false,
        timestamp: DateTime.now(),
        attachments: attachments,
        isGenerating: false,
        generatedByAgentId: agentId,
        metadata: {'isGeneratedImage': true},
      );
      await messageService.addMessage(message);
      return true;
    } catch (e) {
      debugPrint('[Moments] 发送图片消息失败: $e');
      return false;
    }
  }
}
