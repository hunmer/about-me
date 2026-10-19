import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/marquee_button_list_card.dart';

class MarqueeButtonListCardExample extends StatelessWidget {
  const MarqueeButtonListCardExample({super.key});

  // 注意：演示数据用 static final，便于热重载生效
  static final _items = [
    const MarqueeButtonItemData(
      label: 'Flutter',
      icon: Icons.flutter_dash,
      color: Color(0xFF9FB6E8),
      payload: 'tag:flutter>',
    ),
    const MarqueeButtonItemData(
      label: 'Dart',
      icon: Icons.code,
      color: Color(0xFFF2CE5F),
    ),
    const MarqueeButtonItemData(
      label: '健康环',
      icon: Icons.monitor_heart,
      color: Color(0xFFA9BC69),
    ),
    const MarqueeButtonItemData(
      label: '花瓣图',
      icon: Icons.filter_vintage,
      color: Color(0xFFEFA9D9),
    ),
    const MarqueeButtonItemData(
      label: '手账',
      icon: Icons.sticky_note_2,
      color: Color(0xFFC0C96A),
    ),
    const MarqueeButtonItemData(
      label: '画布',
      icon: Icons.dashboard_customize,
      color: Color(0xFF9FB6E8),
    ),
    const MarqueeButtonItemData(
      label: '转轮',
      icon: Icons.album,
      color: Color(0xFFEFA9D9),
    ),
    const MarqueeButtonItemData(
      label: '漫步卡片',
      icon: Icons.style,
      color: Color(0xFFA9BC69),
    ),
    const MarqueeButtonItemData(
      label: '月度胶囊',
      icon: Icons.calendar_view_month,
      color: Color(0xFFF2CE5F),
    ),
    const MarqueeButtonItemData(
      label: '闪光网格',
      icon: Icons.auto_awesome,
      color: Color(0xFFC0C96A),
    ),
  ];

  // 自定义元素演示数据（emoji 载荷）
  static final _emojiItems = [
    ('☕️', '咖啡'),
    ('📚', '阅读'),
    ('🎧', '音乐'),
    ('🏃', '跑步'),
    ('🧘', '冥想'),
    ('🌱', '浇花'),
    ('🎹', '练琴'),
    ('📷', '摄影'),
    ('🎨', '画画'),
    ('🛒', '买菜'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('无限滚动按钮列表卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title('单行（点击有回调，悬浮暂停）'),
              const SizedBox(height: 8),
              _card(
                child: MarqueeButtonListCardWidget(
                  items: _items,
                  rows: 1,
                  size: const Wide2Size(),
                  onItemTap: (item, index) => _toast(context, index, item),
                ),
              ),
              const SizedBox(height: 24),
              _title('双行（默认，奇偶行反向滚动）'),
              const SizedBox(height: 8),
              _card(
                child: MarqueeButtonListCardWidget(
                  items: _items,
                  size: const Wide2Size(),
                ),
              ),
              const SizedBox(height: 24),
              _title('三行 + 更快速度（48px/s）'),
              const SizedBox(height: 8),
              _card(
                child: MarqueeButtonListCardWidget(
                  items: _items,
                  rows: 3,
                  speed: 48,
                  size: const Wide2Size(),
                  onItemTap: (item, index) => _toast(context, index, item),
                ),
              ),
              const SizedBox(height: 24),
              _title('自定义元素（itemBuilder 渲染 emoji 胶囊）'),
              const SizedBox(height: 8),
              _card(
                child: MarqueeButtonListCardWidget(
                  items: [
                    for (final (emoji, name) in _emojiItems)
                      MarqueeButtonItemData(
                        label: name,
                        payload: emoji,
                        color: const Color(0xFF9FB6E8),
                      ),
                  ],
                  rows: 2,
                  itemBuilder: (context, item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isDark ? Colors.white24 : const Color(0xFFE9E6E0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.payload as String? ?? '',
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF211D15),
                          ),
                        ),
                      ],
                    ),
                  ),
                  onItemTap: (item, index) => _toast(context, index, item),
                  size: const Wide2Size(),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Center(
    child: SizedBox(width: 384, child: child),
  );

  void _toast(BuildContext context, int index, MarqueeButtonItemData item) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text('点击了 #$index ${item.label}'),
      ),
    );
  }

  Widget _title(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.grey,
    ),
  );
}
