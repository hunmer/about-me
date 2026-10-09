/// Returns whether a native tap identified a declared Live2D hit area.
bool hasJellyLive2DHitArea(String? hitAreaId, String? hitAreaName) {
  return (hitAreaId != null && hitAreaId.isNotEmpty) ||
      (hitAreaName != null && hitAreaName.trim().isNotEmpty);
}
