import 'event_manager.dart';

/// 插件刷新事件参数
class PluginRefreshArgs extends EventArgs {
  final String pluginId;
  final bool success;

  PluginRefreshArgs({required this.pluginId, this.success = false})
    : super('plugin_refresh');
}

/// 同步数据更新事件参数
class SyncDataUpdatedArgs extends EventArgs {
  final String filePath;
  final String source;
  final String? pluginId;

  SyncDataUpdatedArgs({
    required this.filePath,
    required this.source,
    this.pluginId,
  }) : super('${pluginId ?? 'sync'}_data_updated');
}

/// 插件数据重载后的统一 UI 刷新广播入口
///
/// 约定：插件页面统一订阅 `{id}_refresh` 事件刷新自身（数据重载由
/// 各插件 refreshData 负责，本函数只负责通知 UI 重建）。目前由
/// RouteRefreshManager（文件同步）与 PluginBase.applySampleDataGroups
/// （引导页应用示例数据）在重载完成后调用，两处行为保持一致。
void broadcastPluginRefresh(String pluginId, {bool success = true}) {
  EventManager.instance.broadcast(
    '${pluginId}_refresh',
    PluginRefreshArgs(pluginId: pluginId, success: success),
  );
  EventManager.instance.broadcast(
    'sync_data_updated',
    SyncDataUpdatedArgs(
      filePath: '',
      source: 'plugin_refresh',
      pluginId: pluginId,
    ),
  );
}
