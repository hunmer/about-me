import 'package:flutter/material.dart';
import 'package:aboutme/widgets/personality_carousel.dart';

/// PersonalityCarousel 示例页
///
/// 演示两种用法：
/// 1. 内置发光小人（Friend / Commander / Guardian / Data Nerd）
/// 2. 混入自定义展示组件（图片 / 图标等）
class PersonalityCarouselExample extends StatelessWidget {
  const PersonalityCarouselExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('人格选择轮播')),
      backgroundColor: const Color(0xFFF2F2F7),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildEntryCard(
            context,
            title: '内置小人',
            subtitle: '默认 4 个发光圆球人格（弹簧物理 + 眨眼动效）',
            onTap: () => _openCarousel(
              context,
              title: '内置小人',
              items: PersonalityItem.defaultPersonas,
            ),
          ),
          const SizedBox(height: 12),
          _buildEntryCard(
            context,
            title: '自定义展示组件',
            subtitle: '内置小人 + 图片 / 图标等自定义头像混排',
            onTap: () => _openCarousel(
              context,
              title: '自定义头像',
              items: _mixedItems,
            ),
          ),
        ],
      ),
    );
  }

  /// 内置小人 + 自定义展示组件混排示例
  static final List<PersonalityItem> _mixedItems = [
    ...PersonalityItem.defaultPersonas.take(2),
    PersonalityItem(
      name: 'Painter',
      quote: '今天也来画点什么吧！',
      bubbleAngle: -2,
      tailLeftPercent: 40,
      glowPrimary: const Color(0xFFEFA9D9),
      glowSecondary: const Color(0xFFF9D6EC),
      traits: const [
        PersonalityTrait(icon: '🎨', label: '创意'),
        PersonalityTrait(icon: '🖌️', label: '随性'),
      ],
      description: '用色彩和灵感陪伴你，鼓励你记录生活中的美好瞬间。',
      // 自定义展示组件：图片（也可换成任意 Widget）
      avatarBuilder: (context, size) => ClipOval(
        child: Image.asset(
          'assets/agents/agent_assistant.webp',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFEFA9D9),
            child: const Icon(Icons.image, size: 64, color: Colors.white),
          ),
        ),
      ),
    ),
    PersonalityItem(
      name: 'Robot',
      quote: 'System online. 随时待命。',
      bubbleAngle: 2,
      tailLeftPercent: 60,
      glowPrimary: const Color(0xFF9FB6E8),
      glowSecondary: const Color(0xFFD3DEF6),
      traits: const [
        PersonalityTrait(icon: '🤖', label: '高效'),
        PersonalityTrait(icon: '⚙️', label: '可靠'),
      ],
      description: '像精密仪器一样运转，随时准备响应你的每一个指令。',
      // 自定义展示组件：渐变圆形 + 图标
      avatarBuilder: (context, size) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9FB6E8), Color(0xFF6D7CFF)],
          ),
        ),
        child: const Icon(Icons.smart_toy, size: 88, color: Colors.white),
      ),
    ),
  ];

  void _openCarousel(
    BuildContext context, {
    required String title,
    required List<PersonalityItem> items,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: PersonalityCarousel(
              items: items,
              title: title,
              onConfirm: (item, index) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已选择人格：${item.name}')),
                );
              },
              onClose: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
