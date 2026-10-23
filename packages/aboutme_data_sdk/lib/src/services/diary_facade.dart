import 'package:shared_models/shared_models.dart';

import 'aboutme_data.dart';
import 'query_store.dart';

/// 共享 DTO 的类型门面；不复制日期、统计或持久化业务规则。
class DiaryFacade {
  const DiaryFacade(this.data);
  final AboutmeData data;

  Future<({DiaryEntryDto? entry, int? version})> getEntry(String date) async {
    final response = await data.get('diary', 'getByDate', {'date': date});
    if (response['code'] == 'NOT_FOUND')
      return (entry: null, version: response['version'] as int?);
    return (entry: _entry(response), version: response['version'] as int?);
  }

  DiaryEntryDto _entry(Map<String, dynamic> response) {
    if (response['success'] != true) throw QueryFailure(response);
    return DiaryEntryDto.fromJson({
      ...response['data'] as Map,
      '_sdkVersion': response['version'],
    });
  }

  Future<PaginatedResult<DiaryEntryDto>> listEntries({
    DiaryQuery query = const DiaryQuery(),
  }) async {
    final response = await data.query('diary', 'getList', {
      if (query.startDate != null) 'startDate': query.startDate,
      if (query.endDate != null) 'endDate': query.endDate,
      if (query.keyword != null) 'keyword': query.keyword,
      if (query.mood != null) 'mood': query.mood,
      if (query.pagination != null) 'offset': query.pagination!.offset,
      if (query.pagination != null) 'count': query.pagination!.count,
    });
    return PaginatedResult.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
      (raw) => DiaryEntryDto.fromJson({
        ...raw as Map,
        '_sdkVersion': response['version'],
      }),
    );
  }

  Future<DiaryEntryDto> save(
    String date,
    Map<String, dynamic> patch, {
    int? expectedVersion,
  }) async => _entry(
    await data.call('diary', 'save', {
      ...patch,
      'date': date,
      if (expectedVersion != null) 'expectedVersion': expectedVersion,
    }),
  );

  Future<bool> delete(String date, {int? expectedVersion}) async {
    final response = await data.call('diary', 'deleteByDate', {
      'date': date,
      if (expectedVersion != null) 'expectedVersion': expectedVersion,
    });
    if (response['code'] == 'NOT_FOUND') return false;
    if (response['success'] != true) throw QueryFailure(response);
    return true;
  }

  /// 日历与统计的完整、单版本快照，避免将默认分页的前 100 条视为全量。
  Stream<QuerySnapshot> watchEntries() => data.watch('diary', 'getSnapshot');
}
