import 'package:aboutme/plugins/activity/models/activity_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/repositories/activity/activity_repository.dart';

void main() {
  for (final mood in [4, 4.5, '😊', null]) {
    test('活动模型及 DTO 可加载 mood=$mood', () {
      final json = <String, dynamic>{
        'id': 'ef2c8b85-51c1-4cde-a4b1-d50671a4ae03',
        'title': 'scn-act-updated',
        'startTime': '2026-10-24T10:00:00',
        'endTime': '2026-10-24T11:00:00',
        'mood': mood,
      };
      final record = ActivityRecord.fromJson(json);
      final dto = ActivityDto.fromJson(json);
      expect(record.mood, mood?.toString());
      expect(dto.mood, mood?.toString());
      expect(record.durationInMinutes, 60);
      expect(ActivityRecord.fromJson(record.toJson()).mood, record.mood);
      expect(ActivityDto.fromJson(dto.toJson()).mood, dto.mood);
    });
  }
}
