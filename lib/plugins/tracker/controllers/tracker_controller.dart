import 'dart:async';
import 'dart:convert';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter/material.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/services/plugin_widget_sync_helper.dart';
import '../utils/date_utils.dart' as tracker_date_utils;
import 'package:aboutme/plugins/tracker/tracker_plugin.dart';

class TrackerController with ChangeNotifier {
  List<Goal> _goals = [];
  List<Record> _records = [];
  StreamSubscription<QuerySnapshot>? _subscription;
  QueryStatus queryStatus = QueryStatus.loading;
  Object? loadError;
  int? _version;
  Map<String, Map<String, dynamic>> _baseline = {};

  void _apply(Map<String, dynamic> response) {
    final snapshot = Map<String, dynamic>.from(response['data'] as Map);
    final goals = (snapshot['goals'] as List)
        .map((g) => Goal.fromJson({...Map<String, dynamic>.from(g),'_sdkVersion':response['version']}))
        .toList();
    final records = (snapshot['records'] as List)
        .map((r) => Record.fromJson(Map<String, dynamic>.from(r)))
        .toList();
    _goals = goals;
    _records = records;
    _version = response['version'] as int?;
    _baseline = {for (final goal in goals) goal.id: goal.toJson()};
    queryStatus = QueryStatus.data;
    loadError = null;
    notifyListeners();
    eventManager.broadcast(
      'tracker_cache_updated',
      TrackerCacheUpdatedEventArgs(goals: _goals, cacheDate: DateTime.now()),
    );
  }

  Future<void> loadInitialData() async {
    await reloadData();
    if (_goals.isEmpty && _records.isEmpty) {
      await _command('seedExamples', {});
    }
    _subscription ??= AboutmeDataService.instance.data
        .watch('tracker', 'getSnapshot')
        .listen((snapshot) {
          queryStatus = snapshot.status;
          loadError = snapshot.error;
          if (snapshot.status == QueryStatus.data && snapshot.result != null)
            _apply(snapshot.result!);
          else
            notifyListeners();
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> reloadData() async {
    queryStatus = _goals.isEmpty ? QueryStatus.loading : QueryStatus.stale;
    notifyListeners();
    try {
      _apply(
        await AboutmeDataService.instance.data.query('tracker', 'getSnapshot'),
      );
    } catch (e) {
      queryStatus = QueryStatus.error;
      loadError = e;
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _command(
    String action,
    Map<String, dynamic> params, {
    bool versioned = false,
    int? expectedVersion,
  }) async {
    final response = await AboutmeDataService.instance.data
        .call('tracker', action, {
          ...params,
          'clientMutationId': const Uuid().v4(),
          if (versioned && _version != null) 'expectedVersion': expectedVersion ?? _version,
        });
    if (response['success'] != true) throw QueryFailure(response);
    await reloadData();
    await PluginWidgetSyncHelper.instance.syncTracker();
    return Map<String, dynamic>.from(response['data'] as Map);
  }

  List<Goal> get goals => _goals;
  List<Record> get records => _records;

  // 获取所有分组
  List<String> getAllGroups() {
    final groups = _goals.map((goal) => goal.group).toSet().toList();
    groups.sort(); // 排序
    return groups;
  }

  // 目标管理
  Future<void> addGoal(Goal goal) async {
    _validateGoalDates(goal);
    await _command('create', goal.toJson());
  }

  Future<void> updateGoal(String id, Goal newGoal) async {
    _validateGoalDates(newGoal);
    final before = newGoal.originalJson ?? _baseline[id] ?? <String, dynamic>{};
    final patch = <String, dynamic>{
      for (final entry in newGoal.toJson().entries)
        if (jsonEncode(before[entry.key]) != jsonEncode(entry.value))
          entry.key: entry.value,
    };
    await _command('update', {...patch, 'id': id}, versioned: true, expectedVersion:newGoal.sdkVersion);
  }

  Future<void> toggleGoalCompletion(String id) async {
    await _command('toggleCompletion', {'id': id}, versioned: true);
  }

  Future<void> deleteGoal(String id) async {
    await _command('delete', {'id': id}, versioned: true);
  }

  // 进度计算
  double calculateProgress(Goal goal) {
    return goal.currentValue / goal.targetValue;
  }

  // 日期验证
  void _validateGoalDates(Goal goal) {
    final settings = goal.dateSettings;
    if (settings.type == 'range' &&
        settings.startDate != null &&
        settings.endDate != null &&
        settings.startDate!.isAfter(settings.endDate!)) {
      throw ArgumentError('End date must be after start date');
    }
    // 其他验证规则...
  }

  // 获取今日记录数
  int getTodayRecordCount() {
    final today = tracker_date_utils.DateUtils.startOfDay(DateTime.now());
    return _records.where((r) => r.recordedAt.isAfter(today)).length;
  }

  // 获取所有目标
  Future<List<Goal>> getAllGoals() async {
    await reloadData();
    return _goals;
  }

  // 按状态筛选目标
  Future<List<Goal>> getGoalsByStatus(String status) async {
    await reloadData();
    switch (status) {
      case 'active':
        return _goals.where((g) => !g.isCompleted).toList();
      case 'completed':
        return _goals.where((g) => g.isCompleted).toList();
      default:
        return _goals;
    }
  }

  // 计算总体进度
  double calculateOverallProgress() {
    if (_goals.isEmpty) return 0;

    final completedGoals = _goals.where((g) => g.isCompleted).length;
    return completedGoals / _goals.length;
  }

  // 获取目标总数
  int getGoalCount() {
    return _goals.length;
  }

  // 获取特定目标的记录流
  Stream<List<Record>> watchRecordsForGoal(String goalId) => AboutmeDataService
      .instance
      .data
      .watch('tracker', 'getSnapshot')
      .map((snapshot) {
        if (snapshot.error != null) throw snapshot.error!;
        if (snapshot.result == null)
          return _records.where((r) => r.goalId == goalId).toList();
        final body = snapshot.result!['data'] as Map;
        return (body['records'] as List)
            .map((r) => Record.fromJson(Map<String, dynamic>.from(r)))
            .where((r) => r.goalId == goalId)
            .toList();
      });

  // 获取特定目标的记录
  Future<List<Record>> getRecordsForGoal(String goalId) async {
    await reloadData();
    return _records.where((r) => r.goalId == goalId).toList();
  }

  // 获取今日完成的目标数
  int getTodayCompletedGoals() {
    final today = tracker_date_utils.DateUtils.startOfDay(DateTime.now());
    return _goals
        .where((g) => g.isCompleted && g.createdAt.isAfter(today))
        .length;
  }

  // 获取本月完成的目标数
  int getMonthCompletedGoals() {
    final firstDayOfMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      1,
    );
    return _goals
        .where((g) => g.isCompleted && g.createdAt.isAfter(firstDayOfMonth))
        .length;
  }

  // 获取本月新增的目标数
  int getMonthAddedGoals() {
    final firstDayOfMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      1,
    );
    return _goals.where((g) => g.createdAt.isAfter(firstDayOfMonth)).length;
  }

  // 清空特定目标的所有记录
  Future<void> clearRecordsForGoal(String goalId) async {
    await _command('clearRecords', {'goalId': goalId}, versioned: true);
  }

  // 删除单条记录
  Future<void> deleteRecord(String recordId) async {
    await _command('deleteRecord', {'id': recordId}, versioned: true);
  }

  // 添加记录并更新目标值
  Future<void> addRecord(Record record, Goal goal) async {
    Record.validate(record, goal);
    final wasCompleted =
        _goals.where((g) => g.id == record.goalId).firstOrNull?.isCompleted ??
        false;
    final committed = await _command('addRecord', record.toJson());
    if (!wasCompleted &&
        (_goals.where((g) => g.id == record.goalId).firstOrNull?.isCompleted ??
            false))
      eventManager.broadcast(
        'tracker_goal_completed',
        EventArgs('tracker_goal_completed'),
      );
    eventManager.broadcast(
      'onRecordAdded',
      Value<Record>(Record.fromJson(committed)),
    );
  }
}
