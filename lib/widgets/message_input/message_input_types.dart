import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 输入框顶部图标工具栏的快捷动作
///
/// 顶部工具栏相当于底部抽屉工具栏（完整动作列表）的快捷方式，
/// 常用动作（上传图片/视频等）直接固定在此，免去打开抽屉。
class MessageInputQuickAction {
  const MessageInputQuickAction({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.onLongPress,
    this.active = false,
  });

  final DsIconKind icon;
  final String tooltip;

  /// 为 null 时图标置灰不可点
  final VoidCallback? onPressed;

  /// 长按附加行为（如图片/视频多选）
  final VoidCallback? onLongPress;

  /// 开关类动作的开启态（图标高亮，如"仅使用 JS"切换）
  final bool active;
}
