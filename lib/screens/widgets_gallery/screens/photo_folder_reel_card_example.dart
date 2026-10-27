import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/photo_folder_reel_card.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 3D 毛玻璃照片文件夹轮播示例
class PhotoFolderReelCardExample extends StatelessWidget {
  const PhotoFolderReelCardExample({super.key});

  static final _folders = [
    PhotoReelFolderData(
      title: 'Paris 2025',
      photos: [
        PhotoReelPhotoData.tucked(
          index: 0,
          colors: const [Color(0xFF4F6D96), Color(0xFF9CB2CC), Color(0xFF1C1E21)],
        ),
        PhotoReelPhotoData.tucked(
          index: 1,
          colors: const [Color(0xFFCFC4B4), Color(0xFF2C2A29)],
        ),
        PhotoReelPhotoData.tucked(
          index: 2,
          colors: const [Color(0xFFDED6CC), Color(0xFFB8AEA0), Color(0xFF1D1C1A)],
        ),
      ],
    ),
    PhotoReelFolderData(
      title: 'Japan 2026',
      photos: [
        PhotoReelPhotoData.tucked(
          index: 0,
          colors: const [Color(0xFFD8E1E8), Color(0xFF646B73), Color(0xFF22252A)],
        ),
        PhotoReelPhotoData.tucked(
          index: 1,
          colors: const [Color(0xFF232629), Color(0xFF0C0D0F)],
        ),
        PhotoReelPhotoData.tucked(
          index: 2,
          colors: const [Color(0xFFEEF3F7), Color(0xFF75828E), Color(0xFF262B30)],
        ),
        PhotoReelPhotoData.tucked(
          index: 3,
          colors: const [Color(0xFF8EA8C3), Color(0xFFC9D6E3), Color(0xFF2B3542)],
        ),
      ],
    ),
    PhotoReelFolderData(
      title: 'China 2026',
      photos: [
        PhotoReelPhotoData.tucked(
          index: 0,
          colors: const [Color(0xFF7896B8), Color(0xFFB9CADB), Color(0xFF1E2024)],
        ),
        PhotoReelPhotoData.tucked(
          index: 1,
          colors: const [Color(0xFF181A1D), Color(0xFF31363C)],
        ),
        PhotoReelPhotoData.tucked(
          index: 2,
          colors: const [Color(0xFF1E2024), Color(0xFF2B2E33), Color(0xFF121316)],
        ),
      ],
    ),
  ];

  static final _twoFolders = [
    PhotoReelFolderData(
      title: '冰岛 2024',
      photos: [
        PhotoReelPhotoData.tucked(
          index: 0,
          colors: const [Color(0xFFA9BC69), Color(0xFF3D4A2E)],
        ),
        PhotoReelPhotoData.tucked(
          index: 1,
          colors: const [Color(0xFF9FB6E8), Color(0xFF2B3542)],
        ),
      ],
    ),
    PhotoReelFolderData(
      title: '摩洛哥 2025',
      photos: [
        PhotoReelPhotoData.tucked(
          index: 0,
          colors: const [Color(0xFFF2CE5F), Color(0xFF8A5A2E)],
        ),
        PhotoReelPhotoData.tucked(
          index: 1,
          colors: const [Color(0xFFEFA9D9), Color(0xFF6B3A5A)],
        ),
        PhotoReelPhotoData.tucked(
          index: 2,
          colors: const [Color(0xFFE8833A), Color(0xFF4A2A18)],
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('3D 毛玻璃照片文件夹轮播')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('大尺寸（拖拽切换，点击中央文件夹展开照片）'),
                const SizedBox(height: 8),
                Center(
                  child: PhotoFolderReelCardWidget(
                    folders: _folders,
                    initialIndex: 1,
                    size: const Large3Size(),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('大尺寸（两个文件夹）'),
                const SizedBox(height: 8),
                Center(
                  child: PhotoFolderReelCardWidget(
                    folders: _twoFolders,
                    size: const LargeSize(),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('内联模式（撑满父容器）'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 420,
                  child: PhotoFolderReelCardWidget(
                    folders: _folders,
                    inline: true,
                    size: const Large3Size(),
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
