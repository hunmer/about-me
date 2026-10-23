import 'persistent_plugin_backend.dart';
import 'plugin_data.dart';

class LocalPluginBackend extends PersistentPluginBackend {
  LocalPluginBackend(
    String rootDir, {
    String source = 'local',
    void Function(DataChangeEvent)? onEvent,
  }) : super(_unsupported(), source: source, onEvent: onEvent);

  static PluginPersistence _unsupported() => throw UnsupportedError(
    '浏览器请使用 AboutmeData.withPersistence(StoragePluginPersistence(...))',
  );
}
