import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'package:aboutme/utils/image_utils.dart';

/// 全屏图片浏览器（黑底 + 左右翻页 + 缩放）
class PhotoViewerScreen extends StatefulWidget {
  final List<String> imageRelativePaths;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.imageRelativePaths,
    this.initialIndex = 0,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_current + 1}/${widget.imageRelativePaths.length}',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
      body: PhotoViewGallery.builder(
        itemCount: widget.imageRelativePaths.length,
        pageController: _pageController,
        onPageChanged: (index) => setState(() => _current = index),
        builder: (context, index) {
          return PhotoViewGalleryPageOptions.customChild(
            child: FutureBuilder<String>(
              future: ImageUtils.getAbsolutePath(
                widget.imageRelativePaths[index],
              ),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  final file = File(snapshot.data!);
                  if (file.existsSync()) {
                    return Image.file(file, fit: BoxFit.contain);
                  }
                }
                return const Icon(
                  Icons.broken_image,
                  color: Colors.white24,
                  size: 64,
                );
              },
            ),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
          );
        },
      ),
    );
  }
}
