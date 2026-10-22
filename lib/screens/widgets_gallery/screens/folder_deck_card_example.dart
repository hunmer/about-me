import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/folder_deck_card.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 文件夹卡片堆叠示例
class FolderDeckCardExample extends StatelessWidget {
  const FolderDeckCardExample({super.key});

  static final _items = [
    FolderDeckItemData(
      label: 'RESUME',
      headline: 'Hey there, I am a product designer polishing ideas',
      color: Color(0xFFD4D6DC),
      statusText: 'Open to new opportunities',
      icon: Icons.description_outlined,
    ),
    FolderDeckItemData(
      label: 'STAX.AI',
      headline: 'From fragmented workflows to a seamless OS',
      color: Color(0xFF20C5E8),
      statusText: 'Currently at STAX.AI',
      icon: Icons.layers_outlined,
    ),
    FolderDeckItemData(
      label: 'TRUFFLE',
      headline: 'Crafting sweet brand moments with playful design',
      color: Color(0xFFEFA9D9),
      icon: Icons.cake_outlined,
    ),
    FolderDeckItemData(
      label: 'PULSE',
      headline: 'Tracking habits and health with gentle reminders',
      color: Color(0xFFA9BC69),
      icon: Icons.favorite_border,
    ),
    FolderDeckItemData(
      label: 'ATLAS',
      headline: 'Mapping journeys and memories across the globe',
      color: Color(0xFF9FB6E8),
      icon: Icons.public,
    ),
    FolderDeckItemData(
      label: 'NOTES',
      headline: 'Collecting daily notes, sketches and ideas',
      color: Color(0xFFF2CE5F),
      icon: Icons.edit_note,
    ),
  ];

  static final _tripItems = [
    FolderDeckItemData(
      label: 'VISA',
      headline: 'Documents ready, submit before the deadline',
      color: Color(0xFF8EC9B7),
      statusText: 'Visa application in review',
      icon: Icons.verified_outlined,
    ),
    FolderDeckItemData(
      label: 'FLIGHT',
      headline: 'Two tickets to Tokyo, window seats booked',
      color: Color(0xFFE8833A),
      icon: Icons.flight_takeoff,
    ),
    FolderDeckItemData(
      label: 'HOTEL',
      headline: 'A quiet ryokan near the old town',
      color: Color(0xFFB9A7E6),
      icon: Icons.hotel_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('文件夹卡片堆叠')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('小尺寸（仅当前文件夹 + 1 层）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: FolderDeckCardWidget(
                      items: _items,
                      size: const SmallSize(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('中尺寸（宽条：标题在左，deck 在右）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 170,
                    child: FolderDeckCardWidget(
                      items: _tripItems,
                      size: MediumSize(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('大高尺寸（标题 + deck + 状态 pill）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 440,
                    child: FolderDeckCardWidget(
                      items: _items,
                      size: Large3Size(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('大宽尺寸（左文右 deck，3 张卡）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 320,
                    child: FolderDeckCardWidget(
                      items: _tripItems,
                      size: Wide2Size(),
                    ),
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
