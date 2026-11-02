/// Returns whether a native tap identified a declared Live2D hit area.
bool hasJellyLive2DHitArea(String? hitAreaId, String? hitAreaName) {
  return (hitAreaId != null && hitAreaId.isNotEmpty) ||
      (hitAreaName != null && hitAreaName.trim().isNotEmpty);
}

/// Converts native view coordinates (-1..1, y-up) to top-left normalized space.
({double x, double y}) normalizeJellyLive2DViewPoint(double x, double y) => (
  x: ((x + 1) / 2).clamp(0.0, 1.0).toDouble(),
  y: ((1 - y) / 2).clamp(0.0, 1.0).toDouble(),
);
