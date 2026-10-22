import 'package:aboutme/plugins/activity/models/activity_record.dart';
import 'package:aboutme/plugins/activity/repositories/client_activity_repository.dart';
import 'package:aboutme/plugins/activity/services/activity_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/usecases/activity/activity_usecase.dart';

class _ActivityStorage extends Fake implements ActivityService {
  final records = <ActivityRecord>[];
  DateTime? queriedDate;

  @override
  Future<List<ActivityRecord>> getActivitiesForDate(DateTime date) async {
    queriedDate = date;
    return records;
  }

  @override
  Future<void> saveActivity(ActivityRecord activity, {bool notify = true}) async {
    // 模拟持久化后重新读取，覆盖模型反序列化路径。
    records.add(ActivityRecord.fromJson(activity.toJson()));
  }

  @override
  Future<void> updateActivity(ActivityRecord old, ActivityRecord updated) async {
    records[records.indexOf(old)] = ActivityRecord.fromJson(updated.toJson());
  }
}

void main() {
  for (final suffix in ['+08:00', 'Z']) {
    test('创建并重读 $suffix 活动时保留真实时刻且模型为本地时间', () async {
      final storage = _ActivityStorage();
      final useCase = ActivityUseCase(ClientActivityRepository(activityService: storage));
      final result = await useCase.createActivity({
        'startTime': '2026-10-23T03:00:00$suffix',
        'endTime': '2026-10-23T08:00:00$suffix',
        'title': '睡觉',
        'tags': ['休息'],
      });
      expect(result.isSuccess, isTrue, reason: result.errorOrNull?.message);
      final expected = DateTime.parse('2026-10-23T03:00:00$suffix').toLocal();
      final record = storage.records.single;
      expect(record.startTime.isUtc, isFalse);
      expect(record.startTime, expected);
      expect(record.startTime.hour, expected.hour);
      expect(record.durationInMinutes, 300);
      expect(storage.queriedDate, DateTime(expected.year, expected.month, expected.day));

      final updated = await useCase.updateActivity({
        'id': record.id,
        'date': '${expected.year}-${expected.month.toString().padLeft(2, '0')}-${expected.day.toString().padLeft(2, '0')}',
        'startTime': '2026-10-23T04:00:00$suffix',
      });
      expect(updated.isSuccess, isTrue, reason: updated.errorOrNull?.message);
      expect(storage.records.single.startTime,
          DateTime.parse('2026-10-23T04:00:00$suffix').toLocal());
    });
  }

  test('旧 UTC 记录及 DTO 转入客户端时转换为设备本地时间', () {
    final record = ActivityRecord.fromJson({
      'id': 'old-sleep',
      'startTime': '2026-10-22T19:00:00.000Z',
      'endTime': '2026-10-23T00:00:00.000Z',
      'title': '睡觉',
    });
    final expected = DateTime.utc(2026, 10, 22, 19).toLocal();
    expect(record.startTime.isUtc, isFalse);
    expect(record.startTime.hour, expected.hour);
    expect(record.startTime.day, expected.day);
    expect(record.durationInMinutes, 300);
    expect(ActivityRecord(startTime: DateTime.utc(2026, 10, 22, 19),
        endTime: DateTime.utc(2026, 10, 23), title: '睡觉').startTime.isUtc, isFalse);
  });
}
