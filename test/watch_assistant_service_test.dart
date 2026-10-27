import 'dart:async';

import 'package:aboutme/plugins/personal_assistant/services/watch_assistant_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/watch_assistant');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('拒绝缺少转写文字的请求', () {
    final service = WatchAssistantService(channel);
    expect(
      () => service.accept({
        'requestId': 'one',
        'sessionId': 'session',
        'transcription': ' ',
      }),
      throwsArgumentError,
    );
  });

  test('重复请求只处理一次，桥接失败仍回传失败终态', () async {
    final updates = <Map<dynamic, dynamic>>[];
    final failed = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      final data = call.arguments as Map;
      updates.add(data);
      if (data['status'] == 'processing') {
        throw PlatformException(code: 'UNAVAILABLE', message: '原生桥接暂不可用');
      }
      if (data['status'] == 'failed') failed.complete();
      return null;
    });
    final service = WatchAssistantService(channel);
    final request = {
      'requestId': 'one',
      'sessionId': 'session',
      'transcription': '记一下今天喝了水',
    };
    expect(service.accept(request), {'accepted': true});
    expect(service.accept(request), {'accepted': true});
    await failed.future.timeout(const Duration(seconds: 5));
    expect(updates.map((data) => data['status']), ['processing', 'failed']);
    expect(updates.last['requestId'], 'one');
    expect(updates.last['transcription'], '记一下今天喝了水');
    expect(updates.last['error'], contains('UNAVAILABLE'));
  });

  test('上一请求失败后继续处理下一请求', () async {
    final failures = <String>[];
    final finished = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      final data = call.arguments as Map;
      if (data['status'] == 'processing') {
        throw PlatformException(code: 'UNAVAILABLE');
      }
      failures.add(data['requestId'] as String);
      if (failures.length == 2) finished.complete();
      return null;
    });
    final service = WatchAssistantService(channel);
    for (final id in ['one', 'two']) {
      service.accept({
        'requestId': id,
        'sessionId': 'session',
        'transcription': '记录喝水',
      });
    }
    await finished.future.timeout(const Duration(seconds: 5));
    expect(failures, ['one', 'two']);
  });
}
