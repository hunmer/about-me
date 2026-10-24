import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:get/get.dart';
import 'package:aboutme/plugins/checkin/models/checkin_item.dart';
import 'package:aboutme/plugins/checkin/controllers/checkin_list_controller.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/event/event_manager.dart';

class CheckinRecordScreen extends StatefulWidget {
  final CheckinItem checkinItem;
  final CheckinListController controller;

  const CheckinRecordScreen({
    super.key,
    required this.checkinItem,
    required this.controller,
  });

  @override
  State<CheckinRecordScreen> createState() => _CheckinRecordScreenState();
}

class _CheckinRecordScreenState extends State<CheckinRecordScreen> {
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _timeFormat = DateFormat('HH:mm');

  // 保存/同步会替换项目对象，始终按 ID 读取最新快照。
  CheckinItem? get _currentItem => widget.controller.checkinItems
      .firstWhereOrNull((item) => item.id == widget.checkinItem.id);

  @override
  void initState() {
    super.initState();
    EventManager.instance.subscribe('checkin_refresh', _handleRefresh);
    // 初始化时设置路由上下文
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateRouteContext();
    });
  }

  @override
  void dispose() {
    EventManager.instance.unsubscribe('checkin_refresh', _handleRefresh);
    super.dispose();
  }

  void _handleRefresh(EventArgs args) {
    if (mounted) setState(() {});
  }

  /// 更新路由上下文，使"询问当前上下文"功能能获取到当前查看的打卡项目
  void _updateRouteContext() {
    final itemName = (_currentItem ?? widget.checkinItem).name;
    RouteHistoryManager.updateCurrentContext(
      pageId: "/checkin_record",
      title: '打卡记录 - $itemName',
      params: {'itemName': itemName},
    );
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    // 按日期分组打卡记录
    final recordsByDate = <DateTime, List<CheckinRecord>>{};
    final currentRecords = _currentItem?.checkInRecords ??
        <String, List<CheckinRecord>>{};
    debugPrint('[CheckinRecordScreen] item=${widget.checkinItem.id}, '
        '找到项目=${_currentItem != null}, 记录日期数=${currentRecords.length}');
    for (var entry in currentRecords.entries) {
      // 解析日期字符串为DateTime
      final dateParts = entry.key.split('-');
      if (dateParts.length == 3) {
        final date = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );
        recordsByDate.putIfAbsent(date, () => []).addAll(entry.value);
      }
    }

    // 对日期进行排序（降序）
    final sortedDates =
        recordsByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: Text('checkin_checkinRecordsTitle'.tr)),
      body:
          sortedDates.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                itemCount: sortedDates.length,
                itemBuilder: (context, index) {
                  final date = sortedDates[index];
                  final records = recordsByDate[date]!;
                  records.sort(
                    (a, b) => b.checkinTime.compareTo(a.checkinTime),
                  ); // 按打卡时间降序排序

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: DSThemeBridge(
                      child: Builder(
                        builder: (context) {
                          final theme = DSThemeBridge.resolve(context);
                          return DSCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 日期标题
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.surfaceAlt,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        _dateFormat.format(date),
                                        style: DsTypography.heading.copyWith(
                                          color: theme.text,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${records.length}次打卡',
                                        style: DsTypography.body.copyWith(
                                          color: theme.textSub,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // 打卡记录列表
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: records.length,
                                  itemBuilder: (context, recordIndex) {
                                    final record = records[recordIndex];
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${_timeFormat.format(record.startTime)} - ${_timeFormat.format(record.endTime)}',
                                                style: DsTypography.body
                                                    .copyWith(
                                                      color: theme.text,
                                                    ),
                                              ),
                                              Text(
                                                '打卡时间：${_timeFormat.format(record.checkinTime)}',
                                                style: DsTypography.caption
                                                    .copyWith(
                                                      color: theme.textSub,
                                                    ),
                                              ),
                                              if (record.note != null)
                                                Text(
                                                  record.note!,
                                                  style: DsTypography.caption
                                                      .copyWith(
                                                        color: theme.textSub,
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        DSIconButton(
                                          icon: DsIconKind.trash,
                                          size: 36,
                                          color: theme.surfaceAlt,
                                          iconColor: theme.danger,
                                          onPressed:
                                              () => _showDeleteConfirmDialog(
                                                records[recordIndex]
                                                    .checkinTime,
                                              ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: DSEmptyState(
        icon: DsIconKind.eventBusy,
        title: 'checkin_noRecords'.tr,
        message: 'checkin_startRecordingHint'.tr,
      ),
    );
  }

  void _showDeleteConfirmDialog(DateTime recordTime) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSDialog(
            title: 'checkin_deleteCheckinRecordTitle'.tr,
            message: 'checkin_deleteCheckinRecordMessage'.tr,
            cancelText: 'app_cancel'.tr,
            confirmText: 'app_delete'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () async {
              Navigator.pop(context);
              // 使用 controller 处理取消打卡记录
              await widget.controller.cancelCheckinRecord(
                _currentItem ?? widget.checkinItem,
                recordTime,
              );
              if (mounted) {
                setState(() {});
              }
            },
          ),
    );
  }
}
