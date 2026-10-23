import 'dart:convert';
import 'dart:typed_data';

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:test/test.dart';

/// 内存后端，模拟本地存储以验证 DataStore 的缓存与读写语义。
class MemoryStorage implements StorageInterface {
  final files = <String, dynamic>{};

  @override
  Future<void> clearWithPrefix(String prefix) async {
    files.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<void> deleteFile(String path) async => files.remove(path);

  @override
  Future<List<String>> getKeysWithPrefix(String prefix) async =>
      files.keys.where((key) => key.startsWith(prefix)).toList();

  @override
  Future<List<StorageFileInfo>> listFileInfos(String prefix) async => [
    for (final key in await getKeysWithPrefix(prefix))
      StorageFileInfo(path: key),
  ];

  @override
  Future<bool> hasData(String key) async => files.containsKey(key);

  @override
  Future<dynamic> loadJson(String key, [dynamic defaultValue]) async {
    final value = files[key];
    if (value is! String || value.isEmpty) return defaultValue ?? {};
    return jsonDecode(value);
  }

  @override
  Future<String?> loadData(String key) async => files[key] as String?;

  @override
  Future<Uint8List?> readBytes(String path) async =>
      files[path] is Uint8List ? files[path] as Uint8List : null;

  @override
  Future<String> readString(String path) async {
    final value = files[path];
    if (value is! String) throw Exception('数据不存在: $path');
    return value;
  }

  @override
  Future<void> removeData(String key) async => files.remove(key);

  @override
  Future<void> saveData(String key, String value) async => files[key] = value;

  @override
  Future<void> saveJson(String key, dynamic data) async =>
      files[key] = data;

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async =>
      files[path] = bytes;

  @override
  Future<void> writeString(String path, String content) async =>
      files[path] = content;
}

void main() {
  late MemoryStorage backend;
  late DataStore store;

  setUp(() {
    backend = MemoryStorage();
    store = DataStore(storage: backend);
  });

  test('save/load JSON 往返 + 默认值', () async {
    await store.save('misc/list.json', {'items': [1, 2]});
    expect(await store.load('misc/list.json'), {
      'items': [1, 2],
    });
    expect(await store.load('missing.json', 'fallback'), 'fallback');
    expect(await store.exists('misc/list.json'), isTrue);
  });

  test('插件数据路径与读写', () async {
    await store.savePluginData('misc', 'list.json', {'a': 1});
    expect(await store.loadPluginData('misc', 'list.json'), {'a': 1});
    expect(store.getPluginPath('misc'), 'misc');
    expect(backend.files.containsKey('misc/list.json'), isTrue);
  });

  test('remove / clearPrefix / getKeysWithPrefix', () async {
    await store.save('misc/1.json', 'a');
    await store.save('misc/2.json', 'b');
    await store.save('misc/3.json', 'c');

    expect(
      await store.getKeysWithPrefix('misc/'),
      allOf(contains('misc/1.json'), contains('misc/2.json')),
    );

    await store.remove('misc/1.json');
    expect(await store.exists('misc/1.json'), isFalse);

    await store.clearPrefix('misc/');
    expect(await store.getKeysWithPrefix('misc/'), isEmpty);
  });

  test('readSafeJson 容错非 Map 数据', () async {
    await store.save('scalar.json', [1, 2, 3]);
    expect(await store.readSafeJson('scalar.json'), isEmpty);
    await store.save('map.json', {'k': 'v'});
    expect(await store.readSafeJson('map.json'), {'k': 'v'});
  });

  test('readFile 缺失时返回默认值', () async {
    expect(await store.readFile('nope.json'), '');
    expect(await store.readFile('nope.json', 'def'), 'def');
  });
}
