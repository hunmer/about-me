import 'file_plugin_persistence.dart';
import 'persistent_plugin_backend.dart';
import 'plugin_data.dart';

class LocalPluginBackend extends PersistentPluginBackend {
  LocalPluginBackend(
    this.rootDir, {
    String source = 'local',
    void Function(DataChangeEvent)? onEvent,
    String? sourceDeviceId,
  }) : super(
         FilePluginPersistence(rootDir),
         source: source,
         onEvent: onEvent,
         sourceDeviceId: sourceDeviceId,
       );
  final String rootDir;
}
