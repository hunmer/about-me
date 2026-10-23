import '../plugin_data.dart';
import '../types.dart';
import 'record_domain_support.dart';

/// 单文件快照域：客户端持有全量缓存 + 串行保存链（与 bill saveAccounts
/// 同一语义），SDK 只提供整文件读写两命令，保持各域原有文件布局。
///
/// 适用 timer(tasks.json)/achievement(progress.json)/
/// reminder(reminders.json)/live2d(archives.json)/tts(services.json)。
PluginHandlers createSnapshotDomainHandlers(
  PluginData data, {
  required String pluginId,
  required String fileName,
  Set<String> listKeys = const {},
}) {
  return {
    'getSnapshot': domainAction((_) async {
      final raw = await data.read(pluginId, fileName);
      if (raw == null) return <String, dynamic>{};
      if (raw is! Map)
        throw const DomainFailure('CORRUPT_DATA', 'Expected object');
      return Map<String, dynamic>.from(raw);
    }),
    'saveSnapshot': domainAction((p) async {
      final snapshot = p['snapshot'];
      if (snapshot is! Map) throw ArgumentError('snapshot required');
      for (final key in listKeys) {
        final value = snapshot[key];
        if (value != null && value is! List)
          throw ArgumentError('$key must be a list');
      }
      await data.write(pluginId, fileName, snapshot);
      return snapshot;
    }),
  };
}
