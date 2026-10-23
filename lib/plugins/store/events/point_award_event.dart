import 'package:aboutme/core/event/event_args.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/item_event_args.dart';
import 'package:aboutme/plugins/store/store_plugin.dart';
import 'package:uuid/uuid.dart';

/// 积分奖励事件处理器
class PointAwardEvent {
  /// 各奖励事件写入积分记录的 reason 文案
  /// （积分历史按 reason 反查事件分组，修改需同步两端）
  static const Map<String, String> eventReasons = {
    'activity_added': '添加活动奖励',
    'checkin_completed': '签到完成奖励',
    'task_completed': '完成任务奖励',
    'note_added': '添加笔记奖励',
    'goods_added': '添加物品奖励',
    'chat_message_sent': '发送消息奖励',
    'onRecordAdded': '添加记录奖励',
    'diary_entry_created': '添加日记奖励',
    'bill_added': '添加账单奖励',
  };

  final StorePlugin _storePlugin;

  PointAwardEvent(this._storePlugin) {
    _initializeEventHandlers();
  }

  /// 获取事件对应的积分值
  int _getPointsForEvent(String eventName) {
    return _storePlugin.pointAwardSettings[eventName] ?? 0;
  }

  /// 初始化事件处理器
  void _initializeEventHandlers() {
    final eventManager = EventManager.instance;

    // 监听活动添加事件
    eventManager.subscribe('activity_added', _handleActivityAdded);

    // 监听签到完成事件
    eventManager.subscribe('checkin_completed', _handleCheckinCompleted);

    // 监听任务完成事件
    eventManager.subscribe('task_completed', _handleTaskCompleted);

    // 监听笔记添加事件
    eventManager.subscribe('note_added', _handleNoteAdded);

    // 监听物品添加事件
    eventManager.subscribe('goods_item_added', _handleGoodsAdded);

    // 监听消息发送事件
    eventManager.subscribe('chat_message_sent', _handleMessageSent);

    // 监听记录添加事件
    eventManager.subscribe('onRecordAdded', _handleRecordAdded);

    // 监听日记添加事件
    eventManager.subscribe('diary_entry_created', _handleDiaryAdded);

    eventManager.subscribe('bill_added', _handleBillAdded);
  }

  /// 积分发放幂等键：同一奖励发生（如同一实体创建、同一天同一打卡项）
  /// 只入账一次，事件重试/重复广播不重复加分。
  /// 事件不带实体 ID 时（如 activity_added 的空参数）退化为按次发放。
  String _dedupeKey(String eventName, EventArgs args) {
    if (args is ItemEventArgs) {
      if (eventName == 'checkin_completed') {
        // 打卡按天发放：同一天同一打卡项（区分扣分标记）只奖一次
        final penalty = args.data?['isPenalty'] == true;
        final now = DateTime.now();
        final day =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        return 'store:award:checkin:${args.itemId}:$day:${penalty ? 'p' : 'n'}';
      }
      return 'store:award:$eventName:${args.itemId}';
    }
    if (args is Value) {
      // Value<Message>/Value<Record> 等携带实体的事件按实体 ID 去重
      final entityId = (args as dynamic).value?.id;
      if (entityId != null) return 'store:award:$eventName:$entityId';
    }
    return 'store:award:$eventName:${const Uuid().v4()}';
  }

  /// 处理活动添加事件
  Future<void> _handleActivityAdded(EventArgs args) async {
    await _award('activity_added', args);
  }

  /// 处理签到完成事件（扣分项取反积分）
  Future<void> _handleCheckinCompleted(EventArgs args) async {
    final isPenalty =
        args is ItemEventArgs && args.data?['isPenalty'] == true;
    final points = _getPointsForEvent('checkin_completed');
    await _awardPoints(
      isPenalty ? -points : points,
      eventReasons['checkin_completed']!,
      clientMutationId: _dedupeKey('checkin_completed', args),
    );
  }

  /// 处理任务完成事件
  Future<void> _handleTaskCompleted(EventArgs args) async {
    await _award('task_completed', args);
  }

  /// 处理笔记添加事件
  Future<void> _handleNoteAdded(EventArgs args) async {
    await _award('note_added', args);
  }

  /// 处理物品添加事件
  Future<void> _handleGoodsAdded(EventArgs args) async {
    await _award('goods_item_added', args);
  }

  /// 处理消息发送事件
  Future<void> _handleMessageSent(EventArgs args) async {
    await _award('chat_message_sent', args);
  }

  /// 处理记录添加事件
  Future<void> _handleRecordAdded(EventArgs args) async {
    await _award('onRecordAdded', args);
  }

  /// 处理日记添加事件
  Future<void> _handleDiaryAdded(EventArgs args) async {
    await _award('diary_entry_created', args);
  }

  Future<void> _handleBillAdded(EventArgs args) async {
    await _award('bill_added', args);
  }

  /// 按事件名发放积分（reason 取 [eventReasons] 统一文案）
  Future<void> _award(String eventName, EventArgs args) async {
    await _awardPoints(
      _getPointsForEvent(eventName),
      eventReasons[eventName]!,
      clientMutationId: _dedupeKey(eventName, args),
    );
  }

  /// 添加积分（负数为扣分）；带幂等键时同一奖励重试不重复入账
  Future<void> _awardPoints(int points, String reason,
      {String? clientMutationId}) async {
    if (points != 0) {
      await _storePlugin.controller.addPoints(
        points,
        reason,
        clientMutationId: clientMutationId,
      );
    }
  }

  /// 清理事件订阅
  void dispose() {
    final eventManager = EventManager.instance;
    eventManager.unsubscribe('activity_added', _handleActivityAdded);
    eventManager.unsubscribe('checkin_completed', _handleCheckinCompleted);
    eventManager.unsubscribe('task_completed', _handleTaskCompleted);
    eventManager.unsubscribe('note_added', _handleNoteAdded);
    eventManager.unsubscribe('goods_item_added', _handleGoodsAdded);
    eventManager.unsubscribe('chat_message_sent', _handleMessageSent);
    eventManager.unsubscribe('onRecordAdded', _handleRecordAdded);
    eventManager.unsubscribe('diary_entry_created', _handleDiaryAdded);
    eventManager.unsubscribe('bill_added', _handleBillAdded);
  }
}
