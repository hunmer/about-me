import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/walk_stack_card.dart';

/// 随机漫步卡片堆叠示例页
///
/// 两种模式：顺序循环（默认）与随机漫步（randomMode，
/// 每次切卡从剩余卡片随机抽取下一张）。
class WalkStackCardExample extends StatefulWidget {
  const WalkStackCardExample({super.key});

  @override
  State<WalkStackCardExample> createState() => _WalkStackCardExampleState();
}

class _WalkStackCardExampleState extends State<WalkStackCardExample> {
  /// 演示数据不用 static const（热重载不生效，见 handoff 坑 3）
  static final List<WalkStackCardData> _cards = [
    WalkStackCardData(
      id: 'snowball',
      quote:
          'Now, instead of just skimming, I truly understand challenging '
          'concepts and actually use them to make better decisions.',
      signature: 'Jeremy Stinson',
      stars: 5,
    ),
    WalkStackCardData(
      id: 'thinking',
      quote:
          'Every chapter feels like a calm conversation that turns mental '
          'models into daily habits I can effortlessly recall and apply.',
      signature: 'Clara Vance',
      stars: 4,
    ),
    WalkStackCardData(
      id: 'atomic',
      quote:
          'Complex books used to sit unfinished on my shelf. Now I connect '
          'key ideas in minutes and remember what truly matters.',
      signature: 'Marcus Sterling',
      stars: 5,
    ),
    WalkStackCardData(
      id: 'almanack',
      quote:
          'Reading shifted how I think about long-term wealth and gave me '
          'clearer judgment in everyday life and business.',
      signature: 'Elena Rostova',
      stars: 4,
    ),
  ];

  int _seenCount = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('随机漫步卡片堆叠')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('顺序循环（默认）'),
                const SizedBox(height: 8),
                Center(
                  child: WalkStackCardWidget(cards: _cards),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '左右拖拽顶层卡片飞出切卡，后层弹性补位；轻扫或拖过阈值即触发。',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('随机漫步（randomMode）'),
                const SizedBox(height: 8),
                Center(
                  child: WalkStackCardWidget(
                    cards: _cards,
                    randomMode: true,
                    onCardDismissed: (_) {
                      if (mounted) setState(() => _seenCount++);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '已随机漫步 $_seenCount 张：每次飞出后从剩余卡片随机抽取下一张。',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('说明'),
                const SizedBox(height: 8),
                Text(
                  '卡片数据中的 imagePaths 前 2 张会以拍立得相框贴纸的形式贴在'
                  '卡片左下角与右上角（随拖拽视差移动）；星级与签名使用手写字体，'
                  '卡片纸底 + 淡排线 + 墨线框由 skribble 手绘，卡面默认叠加'
                  '磨砂模糊（frosted 可关闭）。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
      ),
    );
  }
}
