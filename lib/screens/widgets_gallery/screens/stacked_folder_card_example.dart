import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/stacked_folder_card.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 堆叠文件夹卡片示例
class StackedFolderCardExample extends StatelessWidget {
  const StackedFolderCardExample({super.key});

  static final _photos = [
    'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?auto=format&fit=crop&w=600&q=85',
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=600&q=85',
    'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=600&q=85',
  ];

  static final _assetPhotos = [
    'asset://assets/images/default_avatar.jpg',
    'assets/images/jelly_status_panel.png',
    'assets/images/image_not_found.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('堆叠文件夹卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('三个变体（点击卡片或悬停扇出）'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 24,
                  runSpacing: 40,
                  alignment: WrapAlignment.center,
                  children: [
                    SizedBox(
                      width: 320,
                      height: 410,
                      child: StackedFolderCardWidget(
                        title: 'Gallery',
                        subtitle: '15 photos',
                        variant: StackedFolderVariant.gallery,
                        photos: _photos,
                        size: const Large3Size(),
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      height: 410,
                      child: StackedFolderCardWidget(
                        title: 'Quick Notes',
                        subtitle: '7 notes',
                        variant: StackedFolderVariant.notes,
                        size: const Large3Size(),
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      height: 410,
                      child: StackedFolderCardWidget(
                        title: 'Drafts',
                        subtitle: '4 files',
                        variant: StackedFolderVariant.drafts,
                        size: const Large3Size(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('本地图源（asset:// 或 assets/ 前缀，其余按文件路径）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 320,
                    height: 410,
                    child: StackedFolderCardWidget(
                      title: 'Local Gallery',
                      subtitle: '3 assets',
                      variant: StackedFolderVariant.gallery,
                      photos: _assetPhotos,
                      size: const Large3Size(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('小尺寸（口袋精简版）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 170,
                    height: 110,
                    child: StackedFolderCardWidget(
                      title: 'Gallery',
                      subtitle: '15 photos',
                      variant: StackedFolderVariant.gallery,
                      photos: _photos,
                      size: const SmallSize(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('中尺寸（2x1 宽格）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 190,
                    child: StackedFolderCardWidget(
                      title: 'Quick Notes',
                      subtitle: '7 notes',
                      variant: StackedFolderVariant.notes,
                      size: const MediumSize(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('大尺寸（LargeSize）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 320,
                    height: 390,
                    child: StackedFolderCardWidget(
                      title: 'Drafts',
                      subtitle: '4 files',
                      variant: StackedFolderVariant.drafts,
                      size: const LargeSize(),
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
