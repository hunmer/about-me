import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/store/controllers/store_controller.dart';
import 'package:aboutme/plugins/store/models/points_log.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/store/store_plugin.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';

/// 独立的积分历史页面（包含 Scaffold）
class PointsHistoryPage extends StatelessWidget {
  const PointsHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final plugin = PluginManager.instance.getPlugin('store') as StorePlugin?;
    if (plugin == null) {
      return Scaffold(
        appBar: AppBar(title: Text('store_name'.tr)),
        body: Center(child: Text('store_pluginNotAvailable'.tr)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('store_pointsHistory'.tr), elevation: 0),
      body: PointsHistoryContent(controller: plugin.controller),
    );
  }
}

/// 积分历史内容组件（不包含 Scaffold，用于 TabBarView）
class PointsHistoryContent extends StatefulWidget {
  final StoreController controller;

  const PointsHistoryContent({super.key, required this.controller});

  @override
  State<PointsHistoryContent> createState() => _PointsHistoryContentState();
}

class _PointsHistoryContentState extends State<PointsHistoryContent> {
  static const int _pageSize = 30;
  int _currentPage = 0;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  List<PointsLog> _displayedLogs = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_scrollListener);
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) {
      _loadInitialData();
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading) {
      _loadMoreData();
    }
  }

  void _loadInitialData() {
    setState(() {
      _currentPage = 0;
      _displayedLogs = [];
      _loadMoreData();
    });
  }

  void _loadMoreData() {
    if (_isLoading) return;
    if (_currentPage * _pageSize >= widget.controller.pointsLogs.length) return;

    setState(() {
      _isLoading = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          final start = _currentPage * _pageSize;
          final end =
              (start + _pageSize <= widget.controller.pointsLogs.length)
                  ? start + _pageSize
                  : widget.controller.pointsLogs.length;

          if (_currentPage == 0) {
            _displayedLogs = widget.controller.pointsLogs.sublist(start, end);
          } else {
            _displayedLogs.addAll(
              widget.controller.pointsLogs.sublist(start, end),
            );
          }

          _currentPage++;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    if (widget.controller.pointsLogs.isEmpty) {
      return Center(
        child: Text(
          'store_noRecords'.tr,
          style: DsTypography.body.copyWith(color: theme.textSub),
        ),
      );
    }

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return HandDrawnListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            itemCount:
                _displayedLogs.length +
                (_currentPage * _pageSize < widget.controller.pointsLogs.length
                    ? 1
                    : 0),
            tiltKeyOf: (index) =>
                index < _displayedLogs.length
                    ? _displayedLogs[index].id
                    : 'points_history_loading',
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              // 如果是最后一个项目且还有更多数据可加载，显示加载指示器
              if (index == _displayedLogs.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: DSLoadingDots(),
                  ),
                );
              }

              final log = _displayedLogs[index];
              final isEarn = log.type == '获得';
              return DSListItem(
                  leading: DsIcon(
                    isEarn ? DsIconKind.plus : DsIconKind.minus,
                    size: 22,
                    color: isEarn ? theme.success : theme.danger,
                  ),
                  title: 'store_pointsHistoryEntry'.tr
                      .replaceFirst('{value}', log.value.toString())
                      .replaceFirst('{type}', log.type),
                  subtitle: log.reason,
                  trailingText:
                      '${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}',
              );
            },
          );
        },
      ),
    );
  }
}
