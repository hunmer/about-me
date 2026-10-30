library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/plugins/todo/controllers/task_controller.dart';
import 'package:aboutme/plugins/todo/models/task.dart';
import 'package:aboutme/plugins/todo/models/subtask.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

class ClientTodoRepository implements ITodoRepository {
  ClientTodoRepository(TaskController taskController);
  int? _version;
  final _baseline = <String, Map<String, dynamic>>{};
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
  TaskDto _decode(dynamic raw) {
    final task = Task.fromJson(Map<String, dynamic>.from(raw as Map));
    _baseline[task.id] = task.toJson();
    return _taskToDto(task);
  }

  Future<List<TaskDto>> _list(
    String action,
    Map<String, dynamic> params,
  ) async {
    final response = await AboutmeDataService.instance.data.query(
      'todo',
      action,
      params,
    );
    _version = response['version'] as int?;
    return ((response['data'] as Map)['data'] as List).map(_decode).toList();
  }

  Future<dynamic> _command(
    String action,
    Map<String, dynamic> params, {
    bool versioned = false,
  }) async {
    final response = await AboutmeDataService.instance.data
        .call('todo', action, {
          ...params,
          'clientMutationId': const Uuid().v4(),
          if (versioned && _version != null) 'expectedVersion': _version,
        });
    if (response['success'] != true) throw QueryFailure(response);
    _version = response['version'] as int?;
    return response['data'];
  }

  @override
  Future<Result<List<TaskDto>>> getTasks({PaginationParams? pagination}) =>
      _result(() => _list('getList', _page(pagination)));
  @override
  Future<Result<TaskDto?>> getTaskById(String id) => _result(() async {
    final response = await AboutmeDataService.instance.data.get(
      'todo',
      'getById',
      {'id': id},
    );
    if (response['code'] == 'NOT_FOUND') return null;
    if (response['success'] != true) throw QueryFailure(response);
    _version = response['version'] as int?;
    return _decode(response['data']);
  });
  @override
  Future<Result<TaskDto>> createTask(TaskDto dto) => _result(
    () async => _decode(
      await _command('create', {
        ..._dtoToTask(dto).toJson(),
        if (dto.metadata != null) 'metadata': dto.metadata,
      }),
    ),
  );
  @override
  Future<Result<TaskDto>> updateTask(String id, TaskDto dto) => _result(
    () async {
      final before = _baseline[id];
      if (before == null) throw StateError('Read task before editing');
      final native = _dtoToTask(dto).toJson();
      final patch = <String, dynamic>{
        for (final e in native.entries)
          if (jsonEncode(before[e.key]) != jsonEncode(e.value)) e.key: e.value,
      };
      return _decode(
        await _command('update', {...patch, 'id': id}, versioned: true),
      );
    },
  );
  @override
  Future<Result<bool>> deleteTask(String id) => _result(() async {
    await _command('delete', {'id': id}, versioned: true);
    return true;
  });
  @override
  Future<Result<TaskDto>> completeTask(String id) => _result(
    () async => _decode(
      await _command('setStatus', {'id': id, 'status': 2}, versioned: true),
    ),
  );
  @override
  Future<Result<TaskDto>> uncompleteTask(String id) => _result(
    () async => _decode(
      await _command('setStatus', {'id': id, 'status': 0}, versioned: true),
    ),
  );
  @override
  Future<Result<List<TaskDto>>> searchTasks(TaskQuery q) => _result(
    () => _list('search', {
      if (q.keyword != null) 'keyword': q.keyword,
      if (q.tags != null) 'tags': q.tags,
      if (q.isCompleted != null) 'isCompleted': q.isCompleted,
      if (q.dueBefore != null) 'dueBefore': q.dueBefore!.toIso8601String(),
      if (q.dueAfter != null) 'dueAfter': q.dueAfter!.toIso8601String(),
      if (q.field != null) 'field': q.field,
      if (q.value != null) 'value': q.value,
      'fuzzy': q.fuzzy,
      'findAll': q.findAll,
      ..._page(q.pagination),
    }),
  );
  @override
  Future<Result<List<TaskDto>>> getTodayTasks({PaginationParams? pagination}) =>
      _result(() => _list('getTodayTasks', _page(pagination)));
  @override
  Future<Result<List<TaskDto>>> getOverdueTasks({
    PaginationParams? pagination,
  }) => _result(() => _list('getOverdueTasks', _page(pagination)));
  @override
  Future<Result<List<TaskDto>>> getUpcomingTasks({
    int days = 7,
    PaginationParams? pagination,
  }) => _result(
    () => _list('search', {
      'isCompleted': false,
      'dueAfter': DateTime.now().toIso8601String(),
      'dueBefore': DateTime.now().add(Duration(days: days)).toIso8601String(),
      ..._page(pagination),
    }),
  );
  @override
  Future<Result<List<TaskDto>>> getCompletedTasks({
    PaginationParams? pagination,
  }) => _result(
    () => _list('getList', {'completed': true, ..._page(pagination)}),
  );
  @override
  Future<Result<List<TaskDto>>> getPendingTasks({
    PaginationParams? pagination,
  }) => _result(
    () => _list('getList', {'completed': false, ..._page(pagination)}),
  );
  @override
  Future<Result<TaskStatsDto>> getStats() => _result(() async {
    final response = await AboutmeDataService.instance.data.query(
      'todo',
      'getStats',
    );
    final stats = response['data'] as Map;
    return TaskStatsDto(
      total: stats['total'] as int,
      completed: stats['completed'] as int,
      pending: stats['pending'] as int,
      overdue: stats['overdue'] as int,
      dueToday: stats['dueToday'] as int,
    );
  });
  // ============ 转换方法 ============

  /// 将 Task 模型转换为 TaskDto
  TaskDto _taskToDto(Task task) {
    // 构建 metadata
    final metadata = <String, dynamic>{};
    if (task.subtasks.isNotEmpty) {
      metadata['subtasks'] = task.subtasks.map((s) => s.toJson()).toList();
    }
    if (task.reminders.isNotEmpty) {
      metadata['reminders'] = task.reminders
          .map((r) => r.toIso8601String())
          .toList();
    }
    if (task.icon != null) {
      metadata['icon'] = {
        'codePoint': task.icon!.codePoint,
        'fontFamily': task.icon!.fontFamily,
      };
    }
    if (task.startTime != null) {
      metadata['startTime'] = task.startTime!.toIso8601String();
    }
    if (task.duration != null) {
      metadata['duration'] = task.duration!.inMilliseconds;
    }

    return TaskDto(
      id: task.id,
      title: task.title,
      description: task.description,
      isCompleted: task.status == TaskStatus.done,
      priority: task.priority.index,
      dueDate: task.dueDate,
      createdAt: task.createdAt,
      updatedAt: task.startDate ?? task.createdAt, // 使用 startDate 作为 updatedAt
      completedAt: task.completedDate,
      tags: task.tags,
      metadata: metadata.isNotEmpty ? metadata : null,
    );
  }

  /// 将 TaskDto 转换为 Task 模型
  Task _dtoToTask(TaskDto dto) {
    // 从 metadata 中提取额外字段
    final subtasks = <Subtask>[];
    final reminders = <DateTime>[];
    IconData? icon;
    DateTime? startTime;
    Duration? duration;

    if (dto.metadata != null) {
      final metadata = dto.metadata!;

      // 提取子任务
      if (metadata.containsKey('subtasks') && metadata['subtasks'] is List) {
        for (final subtask in metadata['subtasks']) {
          if (subtask is Map<String, dynamic>) {
            subtasks.add(Subtask.fromJson(subtask));
          }
        }
      }

      // 提取提醒
      if (metadata.containsKey('reminders') && metadata['reminders'] is List) {
        for (final reminder in metadata['reminders']) {
          if (reminder is String) {
            reminders.add(parseIsoDateTime(reminder));
          }
        }
      }

      // 提取图标
      if (metadata.containsKey('icon') &&
          metadata['icon'] is Map<String, dynamic>) {
        final iconData = metadata['icon'] as Map<String, dynamic>;
        if (iconData.containsKey('codePoint') &&
            iconData.containsKey('fontFamily')) {
          icon = dynamicIconData(
            iconData['codePoint'] as int,
            fontFamily: iconData['fontFamily'] as String,
          );
        }
      }

      // 提取开始时间
      if (metadata.containsKey('startTime') &&
          metadata['startTime'] is String) {
        startTime = parseIsoDateTime(metadata['startTime'] as String);
      }

      // 提取持续时间
      if (metadata.containsKey('duration') && metadata['duration'] is int) {
        duration = Duration(milliseconds: metadata['duration'] as int);
      }
    }

    return Task(
      id: dto.id,
      title: dto.title,
      description: dto.description,
      createdAt: dto.createdAt,
      startDate: dto.updatedAt != dto.createdAt ? dto.updatedAt : null,
      dueDate: dto.dueDate,
      priority: TaskPriority.values[dto.priority.clamp(0, 3)],
      status: dto.isCompleted ? TaskStatus.done : TaskStatus.todo,
      tags: List<String>.from(dto.tags),
      subtasks: subtasks,
      reminders: reminders,
      completedDate: dto.completedAt,
      startTime: startTime,
      duration: duration,
      icon: icon,
    );
  }
}
