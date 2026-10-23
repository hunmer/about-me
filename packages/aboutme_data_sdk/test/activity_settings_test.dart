import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

/// activity 通知/TTS 设置命令：旧文件布局、缺省空对象、合并更新。
void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('activity_settings_');
    data = AboutmeData.local(root.path);
  });
  tearDown(() async {
    await data.dispose();
    await root.delete(recursive: true);
  });

  dynamic ok(Map<String, dynamic> r) {
    expect(r['success'], true, reason: '$r');
    return r['data'];
  }

  Future<void> fixture(String path, dynamic value) async {
    final f = File(root.path + '/' + path);
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(value));
  }

  test('通知设置：缺省空对象、合并更新、旧数据保留', () async {
    // 文件缺失返回空对象（客户端字段兜底）
    expect(
      ok(await data.get('activity', 'getNotificationSettings', {})),
      isEmpty,
    );

    // 旧客户端写入的部分字段
    await fixture('activity/notification_settings.json', {
      'isEnabled': true,
      'minimumReminderInterval': 30,
    });

    final settings = ok(
      await data.get('activity', 'getNotificationSettings', {}),
    ) as Map;
    expect(settings['isEnabled'], true);
    expect(settings['minimumReminderInterval'], 30);

    // 合并更新：只改传入键，其余保留
    final updated = ok(await data.get(
      'activity',
      'updateNotificationSettings',
      {'updateInterval': 5},
    )) as Map;
    expect(updated['updateInterval'], 5);
    expect(updated['minimumReminderInterval'], 30);

    // 再次读取一致
    final reread = ok(
      await data.get('activity', 'getNotificationSettings', {}),
    ) as Map;
    expect(reread['updateInterval'], 5);
  });

  test('TTS 设置：缺省空对象、合并更新', () async {
    expect(ok(await data.get('activity', 'getTtsSettings', {})), isEmpty);

    await fixture('activity/tts_announcement_settings.json', {
      'isEnabled': true,
      'serviceId': 'tts1',
    });

    ok(await data.get('activity', 'updateTtsSettings', {'isEnabled': false}));
    final settings = ok(
      await data.get('activity', 'getTtsSettings', {}),
    ) as Map;
    expect(settings['isEnabled'], false);
    expect(settings['serviceId'], 'tts1');
  });
}
