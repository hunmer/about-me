import 'storage_interface.dart';

class StorageMigrationResult {
  const StorageMigrationResult({required this.migrated, required this.skipped});
  final int migrated;
  final int skipped;
}

class StorageMigrationService {
  const StorageMigrationService();

  Future<StorageMigrationResult> migrate({
    required StorageInterface source,
    required StorageInterface destination,
    void Function(int completed, int total)? onProgress,
  }) async {
    final keys = await source.getKeysWithPrefix('');
    var migrated = 0;
    var skipped = 0;
    for (var index = 0; index < keys.length; index++) {
      try {
        final bytes = await source.readBytes(keys[index]);
        if (bytes == null) {
          skipped++;
        } else {
          await destination.writeBytes(keys[index].replaceAll('\\', '/'), bytes);
          migrated++;
        }
      } catch (_) {
        skipped++;
      }
      onProgress?.call(index + 1, keys.length);
    }
    return StorageMigrationResult(migrated: migrated, skipped: skipped);
  }
}
