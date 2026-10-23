import 'handlers/assets.dart';
import 'plugin_data.dart';
import '../storage_errors.dart';

Future<Set<String>> readAssetReferences(PluginData data, String assetId) async {
  final value = await data.read('asset_references', '${checkedAssetId(assetId)}.json');
  if (value == null) return {};
  if (value is! List || value.any((entry) => entry is! String)) {
    throw const StorageException(StorageErrorKind.invalidData, '资源引用索引损坏');
  }
  return value.cast<String>().toSet();
}

/// 在业务命令的同一事务中维护资源引用，删除资源时不能破坏已有业务数据。
Future<void> updateAssetReferences(PluginData data,
    Map<String, Set<String>> previous, Map<String, Set<String>> next) async {
  for (final assetId in {...previous.keys, ...next.keys}) {
    final before = previous[assetId] ?? <String>{};
    final after = next[assetId] ?? <String>{};
    if (before.length == after.length && before.containsAll(after)) continue;
    final record = await readAsset(data, assetId);
    if (record == null) {
      if (previous.containsKey(assetId)) {
        throw const StorageException(StorageErrorKind.invalidData, '已有业务引用的资源缺失');
      }
      throw const FormatException('业务引用的资源不存在');
    }
    final linked = await readAssetReferences(data, assetId)
      ..removeAll(previous[assetId] ?? {})
      ..addAll(next[assetId] ?? {});
    await data.write('asset_references', '$assetId.json', linked.toList()..sort());
  }
}

/// 只对调用方明确传入的资源字段递归扫描，不扫描用户正文。
Set<String> assetIdsIn(dynamic fields) {
  final result = <String>{};
  void scan(dynamic value) {
    if (value is String) {
      final reference = value.startsWith('./') ? value.substring(2) : value;
      if (reference.startsWith('asset://')) result.add(checkedAssetId(reference.substring(8)));
    } else if (value is List) {
      for (final child in value) { scan(child); }
    } else if (value is Map) {
      for (final child in value.values) { scan(child); }
    }
  }
  scan(fields);
  return result;
}
