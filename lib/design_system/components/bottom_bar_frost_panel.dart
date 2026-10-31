import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

/// 底栏的背景磨砂层。顶部同时渐入模糊强度与纸色，避免完整模糊硬切入。
class BottomBarFrostPanel extends StatelessWidget {
  const BottomBarFrostPanel({
    super.key,
    required this.blurSigma,
    required this.featherRadius,
    required this.tintFade,
    required this.tintColor,
  });

  final double blurSigma;
  final double featherRadius;
  final double tintFade;
  final Color tintColor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final feather = featherRadius.clamp(0.0, height).toDouble();
          // 过渡带每段不超过 2 逻辑像素，主体只用一个滤镜。
          final bands = (feather / 2).ceil();
          final backdropKey = BackdropKey();
          Widget blurBand(double top, double bottom, double sigma) {
            return Positioned(
              top: top,
              bottom: bottom,
              left: 0,
              right: 0,
              child: ClipRect(
                clipBehavior: Clip.hardEdge,
                child: BackdropFilter(
                  // 各段共享原始背景，防止下一段再次采样已模糊的上一段。
                  backdropGroupKey: backdropKey,
                  enabled: sigma > 0,
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: const SizedBox.expand(),
                ),
              ),
            );
          }

          final tintLength = math.max(feather, height * tintFade);
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (var i = 0; i < bands; i++)
                  blurBand(
                    feather * i / bands,
                    height - feather * (i + 1) / bands,
                    blurSigma * Curves.easeInOut.transform((i + 0.5) / bands),
                  ),
                if (height > feather) blurBand(feather, 0, blurSigma),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: tintLength > 0
                          ? [tintColor.withValues(alpha: 0), tintColor]
                          : [tintColor, tintColor],
                      stops: [0, (tintLength / height).clamp(0.001, 1.0)],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
