import 'package:flutter/material.dart';

import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/widgets/adaptive_image.dart';

/// 圆形 agent 头像：avatarUrl > 自定义图标 > 默认机器人图标
class AgentAvatar extends StatelessWidget {
  final AIAgent? agent;
  final double size;

  const AgentAvatar({super.key, required this.agent, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final color = agent?.iconColor ?? Colors.pinkAccent;
    final avatarUrl = agent?.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: AdaptiveImage(
            imagePath: avatarUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    final icon =
        agent?.icon != null
            ? dynamicIconData(agent!.icon!.codePoint, fontFamily: 'MaterialIcons')
            : Icons.smart_toy;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.55, color: Colors.white),
    );
  }
}

/// 相对时间格式化（刚刚 / x分钟前 / x小时前 / 昨天 / M月d日）
String formatRelativeTime(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays == 1) return '昨天';
  if (diff.inDays < 365) return '${time.month}月${time.day}日';
  return '${time.year}年${time.month}月${time.day}日';
}
