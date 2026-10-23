import 'package:shared_models/shared_models.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';

class ClientDiaryRepository extends IDiaryRepository {
  AboutmeData get _data => AboutmeDataService.instance.data;
  dynamic _value(Map<String, dynamic> result) {
    if (result['success'] != true) throw QueryFailure(result);
    return result['data'];
  }

  Future<Result<T>> _run<T>(Future<T> Function() operation) async {
    try {
      return Result.success(await operation());
    } on QueryFailure catch (error) {
      return Result.failure(
        error.toString(),
        code: error.result['code']?.toString() ?? ErrorCodes.serverError,
      );
    } catch (error) {
      return Result.failure(error.toString(), code: ErrorCodes.serverError);
    }
  }

  DiaryEntryDto _entry(Map<String, dynamic> response) =>
      DiaryEntryDto.fromJson({
        ...Map<String, dynamic>.from(_value(response) as Map),
        '_sdkVersion': response['version'],
      });
  List<DiaryEntryDto> _entries(Map<String, dynamic> response) =>
      ((_value(response) as Map)['data'] as List)
          .map(
            (raw) => DiaryEntryDto.fromJson({
              ...Map<String, dynamic>.from(raw as Map),
              '_sdkVersion': response['version'],
            }),
          )
          .toList();
  @override
  Future<Result<List<DiaryEntryDto>>> getEntries({
    String? startDate,
    String? endDate,
    PaginationParams? pagination,
  }) => _run(
    () async => _entries(
      await _data.get('diary', 'getList', {
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (pagination != null) 'offset': pagination.offset,
        if (pagination != null) 'count': pagination.count,
      }),
    ),
  );
  @override
  Future<Result<DiaryEntryDto?>> getEntryByDate(String date) => _run(() async {
    final result = await _data.get('diary', 'getByDate', {'date': date});
    return result['code'] == 'NOT_FOUND' ? null : _entry(result);
  });
  @override
  Future<Result<DiaryEntryDto>> createEntry(DiaryEntryDto entry) => _run(
    () async => _entry(await _data.call('diary', 'create', entry.toJson())),
  );
  @override
  Future<Result<DiaryEntryDto>> updateEntry(String date, DiaryEntryDto entry) =>
      _run(
        () async => _entry(
          await _data.call('diary', 'updateByDate', {
            ...entry.toJson(),
            'date': date,
            if (entry.version != null) 'expectedVersion': entry.version,
          }),
        ),
      );
  @override
  Future<Result<DiaryEntryDto>> patchEntry(
    String date,
    Map<String, dynamic> patch, {
    int? expectedVersion,
  }) => _run(
    () async => _entry(
      await _data.call('diary', 'updateByDate', {
        ...patch,
        'date': date,
        if (expectedVersion != null) 'expectedVersion': expectedVersion,
      }),
    ),
  );
  @override
  Future<Result<bool>> deleteEntry(String date, {int? expectedVersion}) =>
      _run(() async {
        final result = await _data.call('diary', 'deleteByDate', {
          'date': date,
          if (expectedVersion != null) 'expectedVersion': expectedVersion,
        });
        if (result['code'] == 'NOT_FOUND') return false;
        _value(result);
        return true;
      });
  @override
  Future<Result<List<DiaryEntryDto>>> searchEntries(DiaryQuery query) => _run(
    () async => _entries(
      await _data.get('diary', 'search', {
        if (query.startDate != null) 'startDate': query.startDate,
        if (query.endDate != null) 'endDate': query.endDate,
        if (query.keyword != null) 'keyword': query.keyword,
        if (query.mood != null) 'mood': query.mood,
        if (query.pagination != null) 'offset': query.pagination!.offset,
        if (query.pagination != null) 'count': query.pagination!.count,
      }),
    ),
  );
  @override
  Future<Result<DiaryStatsDto>> getStats() => _run(
    () async => DiaryStatsDto.fromJson(
      Map<String, dynamic>.from(
        _value(await _data.get('diary', 'getStats')) as Map,
      ),
    ),
  );
  @override
  Future<Result<int>> getTodayWordCount() => _run(() async {
    final response = await _data.get('diary', 'getByDate', {
      'date': DiaryCodec.formatDate(DateTime.now()),
    });
    return response['code'] == 'NOT_FOUND'
        ? 0
        : DiaryCodec.plainText(_entry(response).content).trim().length;
  });
  Future<List<DiaryEntryDto>> _month() async {
    final now = DateTime.now();
    return _entries(
      await _data.get('diary', 'getList', {
        'startDate': DiaryCodec.formatDate(DateTime(now.year, now.month)),
        'endDate': DiaryCodec.formatDate(DateTime(now.year, now.month + 1, 0)),
      }),
    );
  }

  @override
  Future<Result<int>> getMonthWordCount() => _run(
    () async => (await _month()).fold<int>(
      0,
      (sum, e) => sum + DiaryCodec.plainText(e.content).trim().length,
    ),
  );
  @override
  Future<Result<Map<String, int>>> getMonthProgress() => _run(
    () async => {
      'completedDays': (await _month()).length,
      'totalDays': DateTime(
        DateTime.now().year,
        DateTime.now().month + 1,
        0,
      ).day,
    },
  );
}
