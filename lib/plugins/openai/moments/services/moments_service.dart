import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/file_attachment.dart';
import 'package:aboutme/plugins/openai/moments/models/moment_post.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';

/// Agent 朋友圈动态服务
///
/// 数据：`openai/moments/posts.json`（新帖插头部，上限 500 条）
class MomentsService extends ChangeNotifier {
  MomentsService._();

  static final MomentsService instance = MomentsService._();

  static const _postsPath = 'openai/moments/posts.json';
  static const _maxPosts = 500;
  static const imagesDir = 'openai/moments/images';

  /// 工具执行上下文：当前会话与其 agent
  /// （由 ChatController.initialize 与 AgentChainExecutor 维护）
  String? currentAgentId;
  String? currentConversationId;

  List<MomentPost> _posts = [];
  bool _loaded = false;

  List<MomentPost> get posts => List.unmodifiable(_posts);

  Future<void> loadPosts({bool force = false}) async {
    if (_loaded && !force) return;
    try {
      final data = await OpenAIPlugin.instance.storage.read(_postsPath);
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

  /// 发布动态（新帖插到最前）
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
      images: List.of(images),
      createdAt: DateTime.now(),
      source: source,
    );
    _posts.insert(0, post);
    if (_posts.length > _maxPosts) {
      _posts = _posts.sublist(0, _maxPosts);
    }
    await _save();
    return post;
  }

  Future<void> deletePost(String postId) async {
    await loadPosts();
    _posts.removeWhere((p) => p.id == postId);
    await _save();
  }

  Future<void> _save() async {
    await OpenAIPlugin.instance.storage.write(_postsPath, {
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
      final messageService =
          AgentChatPlugin.instance.conversationController?.messageService;
      final cid = conversationId ?? currentConversationId;
      if (messageService == null || cid == null) {
        debugPrint('[Moments] 发送图片消息失败: 无可用会话');
        return false;
      }
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
      if (attachments.isEmpty) return false;
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
