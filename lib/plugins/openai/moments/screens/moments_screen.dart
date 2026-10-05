import 'package:flutter/material.dart';

import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'package:aboutme/plugins/openai/moments/widgets/moment_card.dart';

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

  @override
  Widget build(BuildContext context) {
    final posts = _moments.posts;
    return Scaffold(
      appBar: AppBar(title: const Text('朋友圈')),
      body: posts.isEmpty
          ? _buildEmpty(context)
          : RefreshIndicator(
              onRefresh: () => _moments.loadPosts(force: true),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: posts.length,
                separatorBuilder:
                    (_, __) => Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.5),
                    ),
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return MomentCard(
                    post: post,
                    agent: _agents[post.agentId],
                    onDelete: () => _moments.deletePost(post.id),
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
            '对 TA 说「发一条朋友圈」试试',
            style: TextStyle(fontSize: 12, color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}
