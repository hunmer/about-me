import 'package:flutter/material.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/moments/services/image_gen_service.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'package:aboutme/plugins/openai/moments/widgets/moment_card.dart';
import 'package:aboutme/plugins/openai/widgets/agent_list_drawer.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// Agent 朋友圈：Instagram 风格动态流
class MomentsScreen extends StatefulWidget {
  const MomentsScreen({super.key});

  @override
  State<MomentsScreen> createState() => _MomentsScreenState();
}

class _MomentsScreenState extends State<MomentsScreen> {
  final _moments = MomentsService.instance;
  final Map<String, AIAgent> _agents = {};

  @override
  void initState() {
    super.initState();
    _moments.addListener(_onChanged);
    _moments.loadPosts();
    _loadAgents();
  }

  @override
  void dispose() {
    _moments.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAgents() async {
    try {
      final controller = AgentController();
      await controller.loadAgents();
      if (!mounted) return;
      setState(() {
        for (final agent in controller.agents) {
          _agents[agent.id] = agent;
        }
      });
    } catch (e) {
      debugPrint('[Moments] 加载 agent 失败: $e');
    }
  }

  Future<void> _showCommentDialog(String postId) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('评论'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(hintText: '说点什么…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('发送'),
          ),
        ],
      ),
    );
    if (text != null && text.isNotEmpty) {
      await _moments.addComment(postId, text);
      // agent 会稍后自动回复
    }
  }

  // ---------- 手动发帖 ----------

  Future<void> _composePost() async {
    // 1. 选 agent
    Map<String, String>? selected;
    await SmoothBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AgentListDrawer(
        selectedAgents: const [],
        allowMultipleSelection: false,
        onAgentSelected: (agents) {
          if (agents.isNotEmpty) selected = agents.first;
          Navigator.pop(ctx);
        },
      ),
    );
    if (selected == null || !mounted) return;
    final agentId = selected!['id'];
    final agentName = selected!['name'] ?? 'TA';
    if (agentId == null) return;

    // 2. 撰写
    final textController = TextEditingController();
    final promptController = TextEditingController();
    var generateImage = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('以 $agentName 的身份发布'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                maxLines: 3,
                minLines: 1,
                autofocus: true,
                decoration: const InputDecoration(hintText: '这一刻的想法…'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('AI 生成配图'),
                value: generateImage,
                onChanged: (v) => setDialog(() => generateImage = v),
              ),
              if (generateImage)
                TextField(
                  controller: promptController,
                  maxLines: 2,
                  minLines: 1,
                  decoration: const InputDecoration(hintText: '配图描述（留空用文案生图）'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('发布'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final text = textController.text.trim();

    // 3. 发布（可选生图配图）
    var images = const <String>[];
    if (generateImage) {
      ToastService.instance.showToast('正在生成配图…');
      try {
        final prompt = promptController.text.trim().isEmpty
            ? text
            : promptController.text.trim();
        images = await ImageGenService.instance.generate(prompt: prompt);
      } catch (e) {
        if (mounted) ToastService.instance.showToast('配图生成失败: $e');
      }
    }
    if (text.isEmpty && images.isEmpty) return;
    await _moments.addPost(
      agentId: agentId,
      text: text,
      images: images,
      source: 'manual',
    );
  }

  @override
  Widget build(BuildContext context) {
    final posts = _moments.posts;
    return Scaffold(
      appBar: AppBar(title: const Text('朋友圈')),
      floatingActionButton: DSThemeBridge(
        // DSFab 内部取 AppTheme，需包桥
        child: DSFab(icon: DsIconKind.edit, onPressed: _composePost),
      ),
      body: posts.isEmpty
          ? _buildEmpty(context)
          : RefreshIndicator(
              onRefresh: () => _moments.loadPosts(force: true),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: posts.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                ),
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return MomentCard(
                    post: post,
                    agent: _agents[post.agentId],
                    onDelete: () => _moments.deletePost(post.id),
                    onToggleLike: () => _moments.toggleLike(post.id),
                    onAddComment: (_) => _showCommentDialog(post.id),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined, size: 64, color: theme.hintColor),
          const SizedBox(height: 16),
          Text('还没有动态', style: TextStyle(color: theme.hintColor)),
          const SizedBox(height: 8),
          Text(
            '对 TA 说「发一条朋友圈」，或点右下角发布',
            style: TextStyle(fontSize: 12, color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}
