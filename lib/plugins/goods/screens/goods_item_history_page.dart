import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/goods/models/goods_item.dart';
import 'package:aboutme/plugins/goods/models/usage_record.dart';

class GoodsItemHistoryPage extends StatefulWidget {
  final GoodsItem item;
  final String warehouseId;

  const GoodsItemHistoryPage({
    super.key,
    required this.item,
    required this.warehouseId,
  });

  @override
  State<GoodsItemHistoryPage> createState() => _GoodsItemHistoryPageState();
}

class _GoodsItemHistoryPageState extends State<GoodsItemHistoryPage> {
  late GoodsItem _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;

    // 设置路由上下文
    _updateRouteContext();
  }

  /// 更新路由上下文,使"询问当前上下文"功能能获取到当前物品信息
  void _updateRouteContext() {
    RouteHistoryManager.updateCurrentContext(
      pageId: "/goods/item_history",
      title: '物品 - 使用记录: ${_item.title}',
      params: {
        'itemId': _item.id,
        'itemName': _item.title,
        'warehouseId': widget.warehouseId,
      },
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy年MM月dd日 HH:mm').format(date);
  }

  String _formatDuration(int? minutes) {
    if (minutes == null) return '-';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '$hours小时 $mins分钟';
    }
    return '$mins分钟';
  }

  @override
  Widget build(BuildContext context) {
    // Sort records descending
    final records = List<UsageRecord>.from(_item.usageRecords)
      ..sort((a, b) => b.date.compareTo(a.date));
    final theme = DSThemeBridge.resolve(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        title: Text('goods_usageHistory'.tr),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          32,
          16,
          16,
          16,
        ), // Left padding for timeline
        itemCount: records.length,
        itemBuilder: (context, index) {
          final record = records[index];
          return _buildRecordItem(record, index == records.length - 1);
        },
      ),
    );
  }

  Widget _buildRecordItem(UsageRecord record, bool isLast) {
    final theme = DSThemeBridge.resolve(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Timeline line
        if (!isLast)
          Positioned(
            left: -24, // Adjust based on dot position
            top: 24,
            bottom: -16, // Extend to next item
            width: 2,
            child: Container(color: theme.stroke),
          ),

        // Dot
        Positioned(
          left: -31,
          top: 12,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: theme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: theme.background, width: 4),
            ),
          ),
        ),

        // Card
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: JellyBox(
            color: theme.surface,
            radius: BorderRadius.circular(16),
            raised: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header (Date)
                  Row(
                    children: [
                      DsIcon(DsIconKind.clock, size: 16, color: theme.textSub),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(record.date),
                        style: DsTypography.body.copyWith(
                          color: theme.text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: theme.stroke.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),

                  // Duration
                  _buildInfoRow(
                    DsIconKind.clock,
                    '使用时长', // TODO: Localize
                    _formatDuration(record.duration),
                  ),
                  const SizedBox(height: 8),

                  // Location
                  _buildInfoRow(
                    DsIconKind.pin,
                    '使用地点', // TODO: Localize
                    record.location ?? '-',
                  ),
                  const SizedBox(height: 8),

                  // Note
                  _buildInfoRow(
                    DsIconKind.clipboard,
                    '备注', // TODO: Localize
                    record.note ?? '-',
                    isNote: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    DsIconKind icon,
    String label,
    String value, {
    bool isNote = false,
  }) {
    final theme = DSThemeBridge.resolve(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsIcon(icon, size: 16, color: theme.textSub),
        const SizedBox(width: 6),
        if (isNote)
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DsTypography.body.copyWith(color: theme.text),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(color: theme.textSub),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: Row(
              children: [
                Text(
                  '$label: ',
                  style: DsTypography.body.copyWith(color: theme.textSub),
                ),
                Text(
                  value,
                  style: DsTypography.body.copyWith(
                    color: theme.text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
