import 'package:aboutme/plugins/calendar/services/calendar_api_params.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/repositories/calendar/calendar_repository.dart';
import 'package:shared_models/usecases/calendar/calendar_usecase.dart';
import 'package:shared_models/utils/result.dart';

class _Repository extends Fake implements ICalendarRepository {
  CalendarEventDto? event;

  @override
  Future<Result<CalendarEventDto>> createEvent(CalendarEventDto value) async {
    event = value;
    return Result.success(value);
  }

  @override
  Future<Result<CalendarEventDto?>> getEventById(String id) async => Result.success(event);

  @override
  Future<Result<CalendarEventDto>> updateEvent(String id, CalendarEventDto value) async {
    event = value;
    return Result.success(value);
  }

  @override
  Future<Result<CalendarEventDto>> completeEvent(String id, DateTime time) async =>
      Result.success(event!.copyWith(completedTime: time));
}

void main() {
  test('原始 ISO 参数经 API 转换后可通过真实日历业务层创建、更新、完成', () async {
    final repo = _Repository();
    final useCase = CalendarUseCase(repo);
    final args = {
      'title': '健身',
      'startTime': '2026-10-23T19:00:00.000+08:00',
      'endTime': '2026-10-23T20:30:00.000+08:00',
      'reminderMinutes': 30,
    };
    final created = await useCase.createEvent(normalizeCalendarApiParams(args));
    expect(created.isSuccess, isTrue, reason: created.errorOrNull?.message);
    expect(repo.event!.startTime.toUtc(), DateTime.utc(2026, 10, 23, 11));
    expect(repo.event!.endTime!.difference(repo.event!.startTime), const Duration(minutes: 90));
    expect(repo.event!.reminderMinutes, 30);
    expect(args['startTime'], isA<String>());
    final updated = await useCase.updateEvent(normalizeCalendarApiParams({
      'id': repo.event!.id, 'startTime': '2026-10-23T12:00:00Z',
    }));
    expect(updated.isSuccess, isTrue);
    expect(repo.event!.startTime.toUtc(), DateTime.utc(2026, 10, 23, 12));
    final completed = await useCase.completeEvent(normalizeCalendarApiParams({
      'id': repo.event!.id, 'completedTime': '2026-10-23T13:00:00Z',
    }));
    expect(completed.isSuccess, isTrue);
  });

  test('接受已有 DateTime 并拒绝非法日期，不将错误值静默替换', () {
    final now = DateTime(2026, 10, 19);
    expect(normalizeCalendarApiParams({'startDate': now})['startDate'], now);
    expect(() => normalizeCalendarApiParams({'startTime': 'invalid'}), throwsFormatException);
  });
}
