import 'package:aboutme/widgets/adaptive_image.dart';
import 'package:flutter/widgets.dart';

class JellyConfigurableImage extends StatelessWidget {
  const JellyConfigurableImage({
    super.key,
    required this.path,
    this.fit = BoxFit.contain,
  });

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: fit);
    }
    return AdaptiveImage(imagePath: path, fit: fit, borderRadius: 0);
  }
}
