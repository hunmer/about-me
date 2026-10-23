import 'dart:async';
import 'dart:typed_data';

/// 仅供 SDK 受控迁移处理器访问分区外旧数据文件；不提供任意路径写入。
abstract class LegacyAssetData {
  Future<Uint8List?> readLegacyAsset(String path, int maxBytes);

  /// 受控迁移专用：在当前事务内删除分区外旧数据文件（如顶层 records_x）。
  Future<bool> removeLegacyAsset(String path);
}

/// 插件数据访问接口：业务 handler 通过它读写插件数据文件（明文 JSON）。
/// 由本地后端（直接文件 IO）或远程后端（REST）实现，业务逻辑完全不感知。
abstract class PluginData {
  /// 读取插件数据文件；不存在返回 null。
  Future<dynamic> read(String pluginId, String fileName);

  /// 写入插件数据文件（对象或数组）。
  Future<void> write(String pluginId, String fileName, dynamic data);

  /// 删除插件数据文件。
  Future<bool> delete(String pluginId, String fileName);

  /// 列出插件目录下的 JSON 文件名（支持 `*` 通配）。
  Future<List<String>> listFiles(String pluginId, [String? pattern]);

  /// 数据变更通知（写/删后由业务层调用；本地模式进事件流，服务端转 WS 广播）。
  void notifyChanged(String pluginId, String filePattern);
}

/// 统一数据变更事件。
class DataChangeEvent {
  const DataChangeEvent({
    required this.pluginId,
    required this.filePattern,
    required this.source,
    this.action,
    this.resource,
    this.entityId,
    this.version,
    this.mutationId,
    this.sourceDeviceId,
  });

  /// 变更的插件 ID
  final String pluginId;

  /// 变更影响的文件/前缀，如 `tasks.json` 或 `messages/abc.json`
  final String filePattern;

  /// 变更来源：`local`（本机 SDK）/ `rest`（REST API）/ `mcp`（AI 工具）
  final String source;

  /// 触发的业务动作（create/update/delete 等，文件层操作为 null）
  final String? action;

  final String? resource;
  final String? entityId;
  final int? version;
  final String? mutationId;
  final String? sourceDeviceId;

  Map<String, dynamic> toJson() => {
    'pluginId': pluginId,
    'filePattern': filePattern,
    'source': source,
    if (action != null) 'action': action,
    if (resource != null) 'resource': resource,
    if (entityId != null) 'entityId': entityId,
    if (version != null) 'version': version,
    if (mutationId != null) 'mutationId': mutationId,
    if (sourceDeviceId != null) 'sourceDeviceId': sourceDeviceId,
  };

  factory DataChangeEvent.fromJson(Map<String, dynamic> json) =>
      DataChangeEvent(
        pluginId: json['pluginId'] as String,
        filePattern: json['filePattern'] as String,
        source: json['source'] as String,
        action: json['action'] as String?,
        resource: json['resource'] as String?,
        entityId: json['entityId'] as String?,
        version: json['version'] as int?,
        mutationId: json['mutationId'] as String?,
        sourceDeviceId: json['sourceDeviceId'] as String?,
      );

  @override
  String toString() =>
      'DataChangeEvent($pluginId/$filePattern action=$action source=$source)';
}
