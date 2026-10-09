import 'dart:math';

double computeJellyLive2DDisplaySize({
  required double savedSize,
  required double containerWidth,
  required double containerHeight,
  required double bottomReserve,
  required bool fill,
  required bool fitContainer,
  required double modelViewportAspectRatio,
  double fillBottomReserve = 92,
  double minSize = 200,
  double maxSize = 560,
}) {
  if (fitContainer && containerWidth.isFinite && containerHeight.isFinite) {
    final heightLimit = (containerHeight - bottomReserve).clamp(
      0.0,
      double.infinity,
    );
    final widthLimit = containerWidth / modelViewportAspectRatio;
    return min(heightLimit, widthLimit).toDouble();
  }
  if (fill && containerHeight.isFinite) {
    return (containerHeight - fillBottomReserve)
        .clamp(minSize, maxSize)
        .toDouble();
  }
  return savedSize;
}

({double viewportHeight, double scale}) computeJellyLive2DViewportLayout({
  required double displaySize,
  required double baseViewportHeight,
  required bool useResizableViewport,
}) {
  if (useResizableViewport) {
    return (viewportHeight: displaySize, scale: 1.0);
  }
  return (
    viewportHeight: baseViewportHeight,
    scale: displaySize / baseViewportHeight,
  );
}
