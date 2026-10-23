/// Calendar 插件 - 客户端 Repository 实现
///
/// 通过适配现有的 CalendarController 来实现 ICalendarRepository 接口
library;

import 'package:flutter/material.dart';
import 'package:shared_models/repositories/calendar/calendar_repository.dart';
import 'package:shared_models/utils/result.dart';
import 'package:shared_models/utils/pagination.dart';
import '../controllers/calendar_controller.dart';
import '../models/event.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// 客户端 Calendar Repository 实现
class ClientCalendarRepository extends ICalendarRepository {
  final CalendarController controller;
  final Color pluginColor;

  ClientCalendarRepository({
    required this.controller,
    required this.pluginColor,
  });

  // ============ 事件操作 ============

  @override
  Future<Result<List<CalendarEventDto>>> getEvents({
    PaginationParams? pagination,
  }) async {
    try {
      await controller.reloadEvents();
      final events = controller.events;
      final dtos = events.map(_eventToDto).toList();

      if (pagination != null && pagination.hasPagination) {
        final paginated = PaginationUtils.paginate(
          dtos,
          offset: pagination.offset,
          count: pagination.count,
        );
        return Result.success(paginated.data);
      }

      return Result.success(dtos);
    } catch (e) {
      return Result.failure('获取事件列表失败: $e', code: ErrorCodes.serverError);
    }
  }

  @override
  Future<Result<CalendarEventDto?>> getEventById(String id) async {
    try {
      await controller.reloadEvents();
      final event = controller.events.firstOrNull((e) => e.id == id);
      if (event == null) {
        return Result.success(null);
      }
      return Result.success(_eventToDto(event));
    } catch (e) {
      return Result.failure('获取事件失败: $e', code: ErrorCodes.serverError);
    }
  }

  @override
  Future<Result<CalendarEventDto>> createEvent(CalendarEventDto dto) async {
    try {
      final event = _dtoToEvent(dto);
      await controller.addEvent(event);
      return Result.success(_eventToDto(event));
    } catch (e) {
      return Result.failure('创建事件失败: $e', code: ErrorCodes.serverError);
    }
  }

  @override
  Future<Result<CalendarEventDto>> updateEvent(
    String id,
    CalendarEventDto dto,
  ) async {
    try {
      final updatedEvent = _dtoToEvent(dto);
      await controller.updateEvent(updatedEvent);
      return Result.success(_eventToDto(updatedEvent));
    } catch (e) {
      return Result.failure('更新事件失败: $e', code: ErrorCodes.serverError);
    }
  }

  @override
  Future<Result<bool>> deleteEvent(String id) async {
    try {
      await controller.reloadEvents();
      final event = controller.events.firstOrNull((e) => e.id == id);
      if (event == null) {
        return Result.failure('事件不存在', code: ErrorCodes.notFound);
      }

      await controller.deleteEvent(event);
      return Result.success(true);
    } catch (e) {
      return Result.failure('删除事件失败: $e', code: ErrorCodes.serverError);
    }
  }

  @override
  Future<Result<CalendarEventDto>> completeEvent(
    String id,
    DateTime completedTime,
  ) async {
    try {
      await controller.reloadEvents();
      final event = controller.events.firstOrNull((e) => e.id == id);
      if (event == null) {
        return Result.failure('事件不存在', code: ErrorCodes.notFound);
      }

      final completedEvent = event.copyWith(completedTime: completedTime);
      await controller.completeEvent(completedEvent);
      return Result.success(_eventToDto(completedEvent));
    } catch (e) {
      return Result.failure('完成事件失败: $e', code: ErrorCodes.serverError);
    }
  }

  @override
  Future<Result<List<CalendarEventDto>>> searchEvents(
    CalendarEventQuery query,
  ) async {
    try {
      await controller.reloadEvents();
      final events = controller.events;
      final matches = <CalendarEvent>[];

      for (final event in events) {
        bool isMatch = true;

        // 按日期范围过滤
        if (query.startDate != null &&
            event.startTime.isBefore(query.startDate!)) {
          isMatch = false;
        }
        if (query.endDate != null && event.startTime.isAfter(query.endDate!)) {
          isMatch = false;
        }

        // 按来源过滤
        if (query.source != null && event.source != query.source) {
          isMatch = false;
        }

        // 按标题关键词过滤
        if (query.titleKeyword != null &&
            !event.title.toLowerCase().contains(
              query.titleKeyword!.toLowerCase(),
            )) {
          isMatch = false;
        }

        // 按完成状态过滤
        if (query.includeCompleted != null) {
          final isCompleted = event.completedTime != null;
          if (query.includeCompleted == false && isCompleted) {
            isMatch = false;
          }
          if (query.includeCompleted == true && !isCompleted) {
            isMatch = false;
          }
        }

        if (isMatch) {
          matches.add(event);
        }
      }

      final dtos = matches.map(_eventToDto).toList();

      if (query.pagination != null && query.pagination!.hasPagination) {
        final paginated = PaginationUtils.paginate(
          dtos,
          offset: query.pagination!.offset,
          count: query.pagination!.count,
        );
        return Result.success(paginated.data);
      }

      return Result.success(dtos);
    } catch (e) {
      return Result.failure('搜索事件失败: $e', code: ErrorCodes.serverError);
    }
  }

  // ============ 已完成事件操作 ============

  @override
  Future<Result<List<CalendarEventDto>>> getCompletedEvents({
    PaginationParams? pagination,
  }) async {
    try {
      await controller.reloadEvents();
      final events = controller.completedEvents;
      final dtos = events.map(_eventToDto).toList();

      if (pagination != null && pagination.hasPagination) {
        final paginated = PaginationUtils.paginate(
          dtos,
          offset: pagination.offset,
          count: pagination.count,
        );
        return Result.success(paginated.data);
      }

      return Result.success(dtos);
    } catch (e) {
      return Result.failure('获取已完成事件列表失败: $e', code: ErrorCodes.serverError);
    }
  }

  @override
  Future<Result<CalendarEventDto?>> getCompletedEventById(String id) async {
    try {
      await controller.reloadEvents();
      final event = controller.completedEvents.firstOrNull((e) => e.id == id);
      if (event == null) {
        return Result.success(null);
      }
      return Result.success(_eventToDto(event));
    } catch (e) {
      return Result.failure('获取已完成事件失败: $e', code: ErrorCodes.serverError);
    }
  }

  @override
  Future<Result<CalendarEventDto>> restoreCompletedEvent(String id) async {
    try {
      await controller.reloadEvents();
      final event = controller.completedEvents.firstOrNull((e) => e.id == id);
      if (event == null) {
        return Result.failure('已完成事件不存在', code: ErrorCodes.notFound);
      }

      await controller.restoreEvent(id);
      final restoredEvent = controller.events.firstWhere((e) => e.id == id);
      return Result.success(_eventToDto(restoredEvent));
    } catch (e) {
      return Result.failure('恢复事件失败: $e', code: ErrorCodes.serverError);
    }
  }

  @override
  Future<Result<bool>> deleteCompletedEvent(String id) async {
    try {
      final completedEvents = List<CalendarEvent>.from(
        controller.completedEvents,
      );
      final event = completedEvents.firstOrNull((e) => e.id == id);
      if (event == null) {
        return Result.failure('已完成事件不存在', code: ErrorCodes.notFound);
      }

      await controller.deleteEvent(event);

      return Result.success(true);
    } catch (e) {
      return Result.failure('删除已完成事件失败: $e', code: ErrorCodes.serverError);
    }
  }

  // ============ 转换方法 ============

  CalendarEventDto _eventToDto(CalendarEvent event) {
    return CalendarEventDto(
      id: event.id,
      title: event.title,
      description: event.description,
      startTime: event.startTime,
      endTime: event.endTime,
      icon: event.icon.codePoint,
      color: event.color.value,
      source: event.source,
      reminderMinutes: event.reminderMinutes,
      completedTime: event.completedTime,
      createdAt: DateTime.now(), // CalendarEvent 没有 createdAt 字段，使用当前时间
      updatedAt: DateTime.now(), // CalendarEvent 没有 updatedAt 字段，使用当前时间
    );
  }

  CalendarEvent _dtoToEvent(CalendarEventDto dto) {
    return CalendarEvent(
      id: dto.id,
      title: dto.title,
      description: dto.description,
      startTime: dto.startTime,
      endTime: dto.endTime,
      icon: dynamicIconData(dto.icon, fontFamily: 'MaterialIcons'),
      color: Color(dto.color),
      source: dto.source,
      reminderMinutes: dto.reminderMinutes,
      completedTime: dto.completedTime,
    );
  }
}

/// 扩展方法：获取列表中的第一个匹配元素或返回 null
extension _IterableExtensions<T> on Iterable<T> {
  T? firstOrNull([bool Function(T element)? test]) {
    for (final element in this) {
      if (test == null || test(element)) {
        return element;
      }
    }
    return null;
  }
}
