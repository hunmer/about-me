import 'event_manager.dart';

/// 物品事件参数类
class ItemEventArgs extends EventArgs {
  /// 物品ID
  final String itemId;
  
  /// 物品标题
  final String title;
  
  /// 事件动作类型（如：added, completed等）
  final String action;

  /// 附加数据（事件特定，如签到扣分标记）
  final Map<String, dynamic>? data;

  /// 创建一个物品事件参数实例
  ItemEventArgs({
    required String eventName,
    required this.itemId,
    required this.title,
    required this.action,
    this.data,
  }) : super(eventName);
}