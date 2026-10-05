import 'dart:io';

import 'package:flutter/material.dart';

import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/moments/models/moment_post.dart';
import 'package:aboutme/plugins/openai/moments/widgets/agent_avatar.dart';
import 'package:aboutme/plugins/openai/moments/widgets/photo_viewer_screen.dart';
import 'package:aboutme/utils/image_utils.dart';

/// 朋友圈动态卡片（Instagram 风格：头像 + 名字 + 时间 + 文案 + 图片区 + 互动）
class MomentCard extends StatelessWidget {
  final MomentPost post;
  final AIAgent? agent;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleLike;
  final ValueChanged<String>? onAddComment;

  const MomentCard({
    super.key,
    required this.post,
    required this.agent,
    this.onDelete,
    this.onToggleLike,
    this.onAddComment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: GestureDetector(
        onLongPress: onDelete != null ? () => _confirmDelete(context) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AgentAvatar(agent: agent, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent?.name ?? '未知助手',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatRelativeTime(post.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.source == 'manual')
                  Icon(Icons.edit_note, size: 16, color: theme.hintColor),
              ],
            ),
            if (post.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(post.text, style: const TextStyle(fontSize: 15, height: 1.4)),
            ],
            if (post.images.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildImages(context),
            ],
            const SizedBox(height: 8),
            _buildActions(theme),
            if (post.comments.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildComments(theme),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// 互动行：点赞红心 + 评论按钮
  Widget _buildActions(ThemeData theme) {
    return Row(
      children: [
        _IconAction(
          icon: post.liked ? Icons.favorite : Icons.favorite_border,
          color: post.liked ? Colors.redAccent : theme.hintColor,
          label: post.liked ? '已赞' : '赞',
          onTap: onToggleLike,
        ),
        const SizedBox(width: 24),
        _IconAction(
          icon: Icons.chat_bubble_outline,
          color: theme.hintColor,
          label: '评论',
          onTap: onAddComment != null ? () => onAddComment!('') : null,
        ),
      ],
    );
  }

  /// 评论列表：agent 名字高亮，用户名显示"我"
  Widget _buildComments(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.disabledColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in post.comments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: c.isAgent ? (agent?.name ?? 'TA') : '我',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: c.isAgent
                            ? theme.colorScheme.primary
                            : theme.hintColor,
                      ),
                    ),
                    TextSpan(
                      text: '：${c.text}',
                      style: const TextStyle(fontSize: 13, height: 1.3),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImages(BuildContext context) {
    if (post.images.length == 1) {
      return GestureDetector(
        onTap: () => _openViewer(context, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _LocalImage(path: post.images.first, maxHeight: 380),
        ),
      );
    }
    // 多图：3 列正方形网格
    final rows = (post.images.length / 3).ceil();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: rows * 118 + (rows - 1) * 4,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: post.images.length,
          itemBuilder: (context, index) => GestureDetector(
            onTap: () => _openViewer(context, index),
            child: _LocalImage(path: post.images[index]),
          ),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => PhotoViewerScreen(
              imageRelativePaths: post.images,
              initialIndex: index,
            ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('删除动态'),
            content: const Text('确定删除这条朋友圈动态吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onDelete?.call();
                },
                child: const Text('删除'),
              ),
            ],
          ),
    );
  }
}

/// 互动图标按钮
class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _IconAction({
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// 本地相对路径图片（等比例显示，加载失败显示占位）
class _LocalImage extends StatelessWidget {
  final String path;
  final double? maxHeight;

  const _LocalImage({required this.path, this.maxHeight});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: ImageUtils.getAbsolutePath(path),
      builder: (context, snapshot) {
        Widget child = Container(
          color: Theme.of(context).disabledColor.withValues(alpha: 0.15),
          child: const Center(
            child: Icon(Icons.image_outlined, color: Colors.white24),
          ),
        );
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final file = File(snapshot.data!);
          if (file.existsSync()) {
            child = Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => child,
            );
          }
        }
        return SizedBox(
          width: double.infinity,
          height: maxHeight,
          child: child,
        );
      },
    );
  }
}
