import 'package:flutter/services.dart' show HapticFeedback;

/// 行为原语：触觉反馈（移动端轻微震动，桌面/网页端为静默空操作）
///
/// 交互浮层展开时统一在此收口，避免各组件直接散调 HapticFeedback；
/// 后续如需全局开关或强度分级只改这里。
abstract final class DsHaptics {
  /// 锚定浮层展开（菜单/下拉/Popover）：最轻的选中级反馈
  static void popup() => HapticFeedback.selectionClick();

  /// 表面级浮层展开（对话框/底部 Sheet）：轻冲击反馈
  static void surface() => HapticFeedback.lightImpact();
}
