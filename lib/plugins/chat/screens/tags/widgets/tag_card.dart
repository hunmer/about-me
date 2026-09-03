import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/tag.dart';

/// 标签卡片组件
/// 显示标签名称和消息数量，支持点击跳转
class TagCard extends StatelessWidget {
  final MessageTag tag;
  final VoidCallback onTap;

  const TagCard({super.key, required this.tag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return DSCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 标签名称（带#前缀）
          Row(
            children: [
              DsIcon(
                DsIconKind.tag,
                size: 16,
                color: tag.color ?? theme.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  tag.name,
                  style: DsTypography.heading.copyWith(color: theme.text),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // 消息数量
          Text(
            'chat_messageCount'.trParams({
              'count': tag.messageCount.toString(),
            }),
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ],
      ),
    );
  }
}
