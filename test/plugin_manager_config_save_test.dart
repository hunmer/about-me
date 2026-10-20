import 'dart:async';
import 'dart:convert';

import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnusedBackend implements StorageInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedStorage extends StorageManager {
  _DelayedStorage() : super(storage: _UnusedBackend());

  final firstWriteStarted = Completer<void>();
  final releaseFirstWrite = Completer<void>();
  final writesFinished = Completer<void>();
  int writeCount = 0;
  String saved = '{}';
  bool failFirstWrite = false;

  @override
  Future<String> readFile(String path, [String defaultValue = '']) async => saved;

  @override
  Future<void> writeFile(String path, String content) async {
    writeCount++;
    if (writeCount == 1) {
      firstWriteStarted.complete();
      await releaseFirstWrite.future;
      if (failFirstWrite) throw StateError('simulated write failure');
    }
    saved = content;
    if (writeCount == 2) writesFinished.complete();
  }
}

void main() {
  for (final failFirstWrite in [false, true]) {
    test('configuration writes stay ordered (first fails: $failFirstWrite)',
        () async {
      final storage = _DelayedStorage()..failFirstWrite = failFirstWrite;
      final manager = PluginManager.instance;
      await manager.setStorageManager(storage);

      manager.autoOpenLastPlugin = false;
      await storage.firstWriteStarted.future;
      manager.autoOpenLastPlugin = true;
      // 让第二次保存有机会启动：第一次未结束时不应并发写入。
      await Future<void>.delayed(Duration.zero);
      final writesWhileBlocked = storage.writeCount;
      storage.releaseFirstWrite.complete();
      await storage.writesFinished.future;

      expect(writesWhileBlocked, 1);
      final config = jsonDecode(storage.saved) as Map<String, dynamic>;
      expect(config['settings']['autoOpenLastPlugin'], isTrue);
    });
  }
}
