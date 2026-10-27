import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/scrapbook_canvas_card/scrapbook_canvas_card.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 手帐无限画布卡片示例（东京 Day 1 拼贴场景）
class ScrapbookCanvasCardExample extends StatelessWidget {
  const ScrapbookCanvasCardExample({super.key});

  /// 东京 Day 1 演示场景（坐标/旋转/z 序移植自 HTML 原型）
  static final _tokyoDay1Items = [
    // 标题区
    ScrapItemData(
      id: 'header',
      kind: ScrapItemKind.header,
      x: 138,
      y: 65,
      zIndex: 20,
      dateLabel: 'SUNDAY, JUNE 2',
      title: 'Tokyo',
      subtitle: 'DAY 1',
    ),
    // 飞机窗照片
    ScrapItemData(
      id: 'airplane_window',
      kind: ScrapItemKind.photo,
      x: 36,
      y: 152,
      rotation: -3,
      zIndex: 22,
      width: 98,
      height: 144,
      artStyle: 'airplaneWindow',
      captions: ['2am from san diego 🌅'],
      captionColor: const Color(0xFFD9388A),
    ),
    // 涩谷夜巷照片
    ScrapItemData(
      id: 'shibuya',
      kind: ScrapItemKind.photo,
      x: 164,
      y: 185,
      rotation: 5.5,
      zIndex: 23,
      width: 96,
      height: 134,
      imageUrl:
          'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=400&q=80',
      fallbackColor: const Color(0xFF120E1A),
      captions: ['to shibuya 🇯🇵'],
      captionColor: const Color(0xFFD9388A),
      tape: const ScrapTapeData(dx: 66, dy: -8, angle: 38),
    ),
    // with 同行人
    ScrapItemData(
      id: 'companions',
      kind: ScrapItemKind.companions,
      x: 282,
      y: 158,
      zIndex: 21,
      companions: const [
        ScrapCompanionData(name: 'Amily', emoji: '👩🏻', color: Color(0xFFFFE4D6)),
        ScrapCompanionData(name: 'Bella', emoji: '👩🏼', color: Color(0xFFFFF0D6)),
        ScrapCompanionData(name: 'Andy', emoji: '👦🏻', color: Color(0xFFE8F0FE)),
      ],
    ),
    // 左缘半露樱花照片
    ScrapItemData(
      id: 'nakameguro',
      kind: ScrapItemKind.photo,
      x: -64,
      y: 372,
      rotation: -1.5,
      zIndex: 20,
      width: 86,
      height: 142,
      imageUrl:
          'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=400&q=80',
      fallbackColor: const Color(0xFFE8ECEF),
      captions: ['nakameguro 🌸'],
      captionColor: const Color(0xFFD9388A),
      tape: const ScrapTapeData(dx: 56, dy: 132, angle: -38),
    ),
    // 黄色礼盒 + 小票 + 价格 pill + WISHLIST
    ScrapItemData(
      id: 'gift',
      kind: ScrapItemKind.gift,
      x: 52,
      y: 372,
      zIndex: 25,
    ),
    // 猫咪照片 + 云朵气泡 + 日文说明
    ScrapItemData(
      id: 'kitten',
      kind: ScrapItemKind.photo,
      x: 214,
      y: 382,
      zIndex: 24,
      width: 98,
      height: 138,
      imageUrl:
          'https://images.unsplash.com/photo-1574158622682-e40e69881006?auto=format&fit=crop&w=400&q=80',
      fallbackColor: const Color(0xFFB38E6B),
      bubbleText: 'help..',
      captions: ['世界で一番かわい', 'い子猫たち'],
      captionColor: const Color(0xFF222222),
    ),
    // 右缘半露芦之湖照片
    ScrapItemData(
      id: 'lake_ashi',
      kind: ScrapItemKind.photo,
      x: 368,
      y: 304,
      rotation: 3,
      zIndex: 20,
      width: 96,
      height: 146,
      imageUrl:
          'https://images.unsplash.com/photo-1509023464722-18d996393ca8?auto=format&fit=crop&w=400&q=80',
      fallbackColor: const Color(0xFF2C4C64),
      captions: ['lake ashi 🛶'],
      captionColor: const Color(0xFF3B9E4C),
      tape: const ScrapTapeData(dx: -15, dy: 140, angle: 36),
    ),
    // 左缘半露拉面照片 + 鱼板边框
    ScrapItemData(
      id: 'ramen',
      kind: ScrapItemKind.photo,
      x: -38,
      y: 568,
      rotation: 7,
      zIndex: 23,
      width: 94,
      height: 128,
      imageUrl:
          'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80',
      fallbackColor: const Color(0xFFD9C7B2),
      narutomakiBorder: true,
      captions: ['best ramen', 'all along'],
      captionColor: const Color(0xFFD4842A),
    ),
    // 富士山拱形照片
    ScrapItemData(
      id: 'fuji',
      kind: ScrapItemKind.photo,
      x: 92,
      y: 598,
      zIndex: 22,
      width: 44,
      height: 48,
      artStyle: 'fuji',
      captions: ['Mount Fuji'],
      captionColor: const Color(0xFF3B9E4C),
    ),
    // 新干线照片 + sparkles
    ScrapItemData(
      id: 'shinkansen',
      kind: ScrapItemKind.photo,
      x: 192,
      y: 598,
      zIndex: 22,
      width: 90,
      height: 134,
      artStyle: 'shinkansen',
      sparklesDecor: true,
    ),
    // 速度文字
    ScrapItemData(
      id: 'speed_caption',
      kind: ScrapItemKind.text,
      x: 162,
      y: 752,
      zIndex: 24,
      captions: ['320 km/h 💨'],
      captionColor: const Color(0xFF111111),
    ),
    // 右缘半露黄色毛绒玩具照片
    ScrapItemData(
      id: 'plushie',
      kind: ScrapItemKind.photo,
      x: 350,
      y: 582,
      rotation: 3.5,
      zIndex: 21,
      width: 92,
      height: 130,
      artStyle: 'plushie',
      captions: ['⚡ It took 2', '  hours to', '  pick...'],
      captionColor: const Color(0xFF1E1E1E),
    ),
    // ===== 边缘外 bonus 照片 =====
    // 左：matcha
    ScrapItemData(
      id: 'matcha',
      kind: ScrapItemKind.photo,
      x: -195,
      y: 195,
      rotation: -4,
      zIndex: 19,
      width: 96,
      height: 132,
      imageUrl:
          'https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=400&q=80',
      fallbackColor: const Color(0xFFDCE5D5),
      captions: ['double matcha 🍵'],
      captionColor: const Color(0xFF3B9E4C),
      tape: const ScrapTapeData(dx: 24, dy: -8, angle: -8),
    ),
    // 右：浅草灯笼
    ScrapItemData(
      id: 'asakusa',
      kind: ScrapItemKind.photo,
      x: 495,
      y: 155,
      rotation: 4,
      zIndex: 19,
      width: 98,
      height: 136,
      imageUrl:
          'https://images.unsplash.com/photo-1545569341-9eb8b30979d9?auto=format&fit=crop&w=400&q=80',
      fallbackColor: const Color(0xFF3A1614),
      captions: ['asakusa vibes 🏮'],
      captionColor: const Color(0xFFD9388A),
      tape: const ScrapTapeData(dx: -12, dy: -7, angle: -32),
    ),
    // 下：东京塔夜景
    ScrapItemData(
      id: 'tokyo_tower',
      kind: ScrapItemKind.photo,
      x: 135,
      y: 885,
      rotation: -2.5,
      zIndex: 19,
      width: 104,
      height: 138,
      imageUrl:
          'https://images.unsplash.com/photo-1536098561742-ca998e48cbcc?auto=format&fit=crop&w=400&q=80',
      fallbackColor: const Color(0xFF181424),
      captions: ['midnight walk 🗼✨'],
      captionColor: const Color(0xFFD4842A),
      tape: const ScrapTapeData(dx: 72, dy: -8, angle: 18),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('手帐无限画布卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('默认尺寸（东京 Day 1）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 560,
                    child: ScrapbookCanvasCardWidget(
                      items: _tokyoDay1Items,
                      size: const Large3Size(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('操作提示'),
                const SizedBox(height: 8),
                Text(
                  '拖动空白处平移画布，双指捏合或滚轮缩放；左右下边缘外藏有 bonus 照片，平移即可发现。\n'
                  '点选条目可拖拽、↻ 旋转、× 删除；底部工具栏：撤销/重做/文字/涂鸦/添加素材（照片与手账贴纸）。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? Colors.white60 : Colors.black54,
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
