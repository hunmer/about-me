double computeJellyLive2DDisplaySize({
  required double savedSize,
  required double containerHeight,
  required double bottomReserve,
  required bool fill,
  required bool fitContainer,
  double fillBottomReserve = 92,
  double minSize = 200,
  double maxSize = 560,
}) {
  if (fitContainer && containerHeight.isFinite) {
    return (containerHeight - bottomReserve)
        .clamp(0.0, double.infinity)
        .toDouble();
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
