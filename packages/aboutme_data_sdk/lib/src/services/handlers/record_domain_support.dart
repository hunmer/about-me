import '../plugin_data.dart';
import '../types.dart';

/// Internal codecs. Missing files are empty; malformed persisted data is never empty.
Future<Map<String, dynamic>> readDomainFile(
  PluginData data,
  String plugin,
  String file,
  List<String> collections,
) async {
  final raw = await data.read(plugin, file);
  if (raw == null) return {for (final key in collections) key: <dynamic>[]};
  if (raw is! Map) throw const DomainFailure('CORRUPT_DATA', 'Expected object');
  final result = Map<String, dynamic>.from(raw);
  for (final key in collections) {
    final value = result[key];
    if (value != null &&
        (value is! List || value.any((e) => e is! Map || e['id'] is! String))) {
      throw DomainFailure('CORRUPT_DATA', 'Invalid $plugin/$key');
    }
    result[key] = value == null
        ? <dynamic>[]
        : value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  return result;
}

class DomainFailure implements Exception {
  const DomainFailure(this.code, this.message);
  final String code;
  final String message;
}

PluginHandler domainAction(
  Future<dynamic> Function(Map<String, dynamic>) run,
) => (_, params) async {
  try {
    return PluginResult.success(await run(params));
  } on DomainFailure catch (e) {
    return PluginResult.failure(e.message, e.code);
  } on FormatException catch (e) {
    return PluginResult.failure('$e', 'CORRUPT_DATA');
  } on ArgumentError catch (e) {
    return PluginResult.failure('$e', 'INVALID_PARAMS');
  }
};
Map<String, dynamic> domainPatch(Map<String, dynamic> params) =>
    Map<String, dynamic>.from(params)
      ..remove('expectedVersion')
      ..remove('clientMutationId')
      ..remove('sourceDeviceId');
List<Map<String, dynamic>> domainRows(Map<String, dynamic> file, String key) =>
    (file[key] as List).cast<Map<String, dynamic>>();
int domainIndex(List<Map<String, dynamic>> rows, dynamic id) {
  final index = rows.indexWhere((e) => e['id'] == id);
  if (index < 0) throw const DomainFailure('NOT_FOUND', 'Entity not found');
  return index;
}

num domainNumber(dynamic value) =>
    value is num ? value : num.tryParse('$value') ?? 0;
