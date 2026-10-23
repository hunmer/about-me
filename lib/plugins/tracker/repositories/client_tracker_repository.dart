library;

import 'dart:convert';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:shared_models/shared_models.dart';
import 'package:uuid/uuid.dart';

/// DTO adapter only: all authoritative reads and related updates run in the SDK.
class ClientTrackerRepository extends ITrackerRepository {
  final dynamic storage;
  final String pluginId;
  ClientTrackerRepository({required this.storage, this.pluginId = 'tracker'});
  int? _version;
  final _baseline = <String, Map<String, dynamic>>{};
  Future<T> _query<T>(
    String action,
    Map<String, dynamic> params,
    T Function(dynamic) decode,
  ) async {
    final response = await AboutmeDataService.instance.data.query(
      pluginId,
      action,
      params,
    );
    _version = response['version'] as int?;
    return decode(response['data']);
  }

  Future<T> _command<T>(
    String action,
    Map<String, dynamic> params,
    T Function(dynamic) decode, {
    bool versioned = false,
  }) async {
    final response = await AboutmeDataService.instance.data
        .call(pluginId, action, {
          ...params,
          'clientMutationId': const Uuid().v4(),
          if (versioned && _version != null) 'expectedVersion': _version,
        });
    if (response['success'] != true) throw QueryFailure(response);
    _version = response['version'] as int?;
    return decode(response['data']);
  }

  Future<Result<T>> _result<T>(Future<T> Function() run) async {
    try {
      return Result.success(await run());
    } on QueryFailure catch (e) {
      return Result.failure(
        '$e',
        code: e.result['code'] as String? ?? ErrorCodes.serverError,
      );
    } catch (e) {
      return Result.failure('$e', code: ErrorCodes.serverError);
    }
  }

  Map<String, dynamic> _page(PaginationParams? p) => {
    if (p?.offset != null) 'offset': p!.offset,
    if (p?.count != null) 'count': p!.count,
  };
  GoalDto _goal(dynamic raw) {
    final json = Map<String, dynamic>.from(raw as Map);
    final goal = GoalDto.fromJson(json);
    _baseline[goal.id] = goal.toJson();
    return goal;
  }

  RecordDto _record(dynamic raw) =>
      RecordDto.fromJson(Map<String, dynamic>.from(raw as Map));
  List<GoalDto> _goals(dynamic raw) =>
      ((raw as Map)['data'] as List).map(_goal).toList();
  List<RecordDto> _records(dynamic raw) =>
      ((raw as Map)['data'] as List).map(_record).toList();
  @override
  Future<Result<List<GoalDto>>> getGoals({
    String? status,
    String? group,
    PaginationParams? pagination,
  }) => _result(
    () => _query('getList', {
      if (status != null) 'status': status,
      if (group != null) 'group': group,
      ..._page(pagination),
    }, _goals),
  );
  @override
  Future<Result<GoalDto?>> getGoalById(String id) => _result(() async {
    final response = await AboutmeDataService.instance.data.get(
      pluginId,
      'getById',
      {'id': id},
    );
    if (response['code'] == 'NOT_FOUND') return null;
    if (response['success'] != true) throw QueryFailure(response);
    _version = response['version'] as int?;
    return _goal(response['data']);
  });
  @override
  Future<Result<GoalDto>> createGoal(GoalDto goal) =>
      _result(() => _command('create', goal.toJson(), _goal));
  @override
  Future<Result<GoalDto>> updateGoal(String id, GoalDto goal) =>
      _result(() async {
        final baseline = _baseline[id];
        if (baseline == null) throw StateError('Read goal before editing');
        final patch = {
          for (final e in goal.toJson().entries)
            if (jsonEncode(baseline[e.key]) != jsonEncode(e.value))
              e.key: e.value,
        };
        return _command('update', {...patch, 'id': id}, _goal, versioned: true);
      });
  @override
  Future<Result<bool>> deleteGoal(String id) => _result(
    () => _command('delete', {'id': id}, (_) => true, versioned: true),
  );
  @override
  Future<Result<List<GoalDto>>> searchGoals(GoalQuery q) => _result(
    () => _query('getList', {
      if (q.status != null) 'status': q.status,
      if (q.group != null) 'group': q.group,
      if (q.field != null) 'field': q.field,
      if (q.value != null) 'value': q.value,
      'fuzzy': q.fuzzy,
      ..._page(q.pagination),
    }, _goals),
  );
  @override
  Future<Result<List<String>>> getAllGroups() => _result(() async {
    final goals = await _query('getList', {}, _goals);
    return goals.map((g) => g.group).toSet().toList()..sort();
  });
  @override
  Future<Result<List<RecordDto>>> getRecordsForGoal(
    String goalId, {
    PaginationParams? pagination,
  }) => _result(
    () => _query('getRecords', {
      'goalId': goalId,
      ..._page(pagination),
    }, _records),
  );
  @override
  Future<Result<RecordDto>> addRecord(RecordDto record) =>
      _result(() => _command('addRecord', record.toJson(), _record));
  @override
  Future<Result<bool>> deleteRecord(String recordId) => _result(
    () => _command(
      'deleteRecord',
      {'id': recordId},
      (_) => true,
      versioned: true,
    ),
  );
  @override
  Future<Result<bool>> clearRecordsForGoal(String goalId) => _result(
    () => _command(
      'clearRecords',
      {'goalId': goalId},
      (_) => true,
      versioned: true,
    ),
  );
  @override
  Future<Result<List<RecordDto>>> searchRecords(RecordQuery q) => _result(
    () => _query('searchRecords', {
      if (q.goalId != null) 'goalId': q.goalId,
      if (q.startDate != null) 'startDate': q.startDate!.toIso8601String(),
      if (q.endDate != null) 'endDate': q.endDate!.toIso8601String(),
      if (q.field != null) 'field': q.field,
      if (q.value != null) 'value': q.value,
      'fuzzy': q.fuzzy,
      ..._page(q.pagination),
    }, _records),
  );
  @override
  Future<Result<TrackerStatsDto>> getStats() => _result(
    () => _query(
      'getStats',
      {},
      (raw) => TrackerStatsDto.fromJson(Map<String, dynamic>.from(raw as Map)),
    ),
  );
}
