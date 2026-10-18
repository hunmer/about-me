import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/stacked_folder_card.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 堆叠文件夹卡片示例
///
/// 每个尺寸分节内通过左右切换光标循环展示不同变体，
/// 而非一次列举所有变体。
class StackedFolderCardExample extends StatelessWidget {
  const StackedFolderCardExample({super.key});

  static final _networkPhotos = [
    'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?auto=format&fit=crop&w=600&q=85',
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=600&q=85',
    'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=600&q=85',
  ];

  static final _assetPhotos = [
    'asset://assets/images/default_avatar.jpg',
    'assets/live2d_backgrounds/Live2D背景·冬日窗边.jpg',
    'assets/images/image_not_found.jpg',
  ];

  static final _demos = [
    (
      label: 'Gallery · 网络图源',
      title: 'Gallery',
      subtitle: '15 photos',
      variant: StackedFolderVariant.gallery,
      photos: _networkPhotos,
    ),
    (
      label: 'Gallery · 本地图源',
      title: 'Local Gallery',
      subtitle: '3 assets',
      variant: StackedFolderVariant.gallery,
      photos: _assetPhotos,
    ),
    (
      label: 'Quick Notes · 便签',
      title: 'Quick Notes',
      subtitle: '7 notes',
      variant: StackedFolderVariant.notes,
      photos: <String>[],
    ),
    (
      label: 'Drafts · 文档',
      title: 'Drafts',
      subtitle: '4 files',
      variant: StackedFolderVariant.drafts,
      photos: <String>[],
    ),
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
                _buildSectionTitle('大高尺寸（Large3Size，点击卡片扇出）'),
                const SizedBox(height: 8),
                _SwitchableFolderCard(
                  demos: _demos,
                  width: 320,
                  height: 410,
                  size: const Large3Size(),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('小尺寸（SmallSize，口袋精简版）'),
                const SizedBox(height: 8),
                _SwitchableFolderCard(
                  demos: _demos,
                  width: 170,
                  height: 110,
                  size: const SmallSize(),
                  arrowDimension: 32,
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('中尺寸（MediumSize，2x1 宽格）'),
                const SizedBox(height: 8),
                _SwitchableFolderCard(
                  demos: _demos,
                  width: 384,
                  height: 190,
                  size: const MediumSize(),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('大尺寸（LargeSize）'),
                const SizedBox(height: 8),
                _SwitchableFolderCard(
                  demos: _demos,
                  width: 320,
                  height: 390,
                  size: const LargeSize(),
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

/// 带左右切换光标的变体展示器：同一位置循环切换不同变体
class _SwitchableFolderCard extends StatefulWidget {
  final List<({
    String label,
    String title,
    String subtitle,
    StackedFolderVariant variant,
    List<String> photos,
  })> demos;

  final double width;
  final double height;
  final HomeWidgetSize size;

  /// 左右切换按钮直径
  final double arrowDimension;

  const _SwitchableFolderCard({
    required this.demos,
    required this.width,
    required this.height,
    required this.size,
    this.arrowDimension = 40,
  });

  @override
  State<_SwitchableFolderCard> createState() => _SwitchableFolderCardState();
}

class _SwitchableFolderCardState extends State<_SwitchableFolderCard> {
  int _index = 0;
  bool _forward = true;

  void _change(int delta) {
    setState(() {
      _forward = delta > 0;
      _index = (_index + delta + widget.demos.length) % widget.demos.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final demo = widget.demos[_index];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _arrowButton(Icons.chevron_left, isDark, () => _change(-1)),
            SizedBox(width: widget.arrowDimension * 0.35),
            SizedBox(
              width: widget.width,
              height: widget.height,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) {
                  final dx = _forward ? 1.0 : -1.0;
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(dx * 0.25, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_index),
                  child: StackedFolderCardWidget(
                    title: demo.title,
                    subtitle: demo.subtitle,
                    variant: demo.variant,
                    photos: demo.photos,
                    size: widget.size,
                  ),
                ),
              ),
            ),
            SizedBox(width: widget.arrowDimension * 0.35),
            _arrowButton(Icons.chevron_right, isDark, () => _change(1)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${demo.label}（${_index + 1}/${widget.demos.length}）',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF8C8C96),
          ),
        ),
      ],
    );
  }

  /// 圆形切换光标（与组件口袋卡箭头按钮同风格）
  Widget _arrowButton(IconData icon, bool isDark, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: widget.arrowDimension,
          height: widget.arrowDimension,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFEBEBF0),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: widget.arrowDimension * 0.45,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF8C8C96),
          ),
        ),
      ),
    );
  }
}
