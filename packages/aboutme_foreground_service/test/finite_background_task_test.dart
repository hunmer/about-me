import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme_foreground_service/aboutme_foreground_service.dart';

const _channelName = 'aboutme_foreground_service/background_task';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final task = FiniteBackgroundTask.instance;
  final codec = const StandardMethodCodec();

  final requests = <MethodCall>[];
  var beginResult = true;

  setUp(() {
    requests.clear();
    beginResult = true;
    messenger.setMockMessageHandler(_channelName, (ByteData? message) async {
      final call = codec.decodeMethodCall(message);
      requests.add(call);
      if (call.method == FiniteBackgroundTask.beginMethod) {
        return codec.encodeSuccessEnvelope(beginResult);
      }
      if (call.method == FiniteBackgroundTask.endMethod) {
        return codec.encodeSuccessEnvelope(null);
      }
      return codec.encodeMethodCall(call);
    });
  });

  tearDown(() async {
    messenger.setMockMessageHandler(_channelName, null);
    for (final listener in List<void Function(String)>.of(_listeners)) {
      task.removeExpirationListener(listener);
    }
    _listeners.clear();
  });

  test('begin 转发 taskId 并返回原生结果，重复 begin 可幂等转发', () async {
    expect(await task.begin('request-1'), isTrue);
    expect(await task.begin('request-1'), isTrue);

    expect(requests.map((call) => call.method), [
      FiniteBackgroundTask.beginMethod,
      FiniteBackgroundTask.beginMethod,
    ]);
    expect(requests.map((call) => call.arguments), ['request-1', 'request-1']);
  });

  test('begin 返回 false 时透传原生失败，end 可重复调用并转发 taskId', () async {
    beginResult = false;

    expect(await task.begin('request-2'), isFalse);
    await task.end('request-2');
    await task.end('request-2');

    expect(requests.map((call) => call.method), [
      FiniteBackgroundTask.beginMethod,
      FiniteBackgroundTask.endMethod,
      FiniteBackgroundTask.endMethod,
    ]);
    expect(requests.map((call) => call.arguments), [
      'request-2',
      'request-2',
      'request-2',
    ]);
  });

  test('expiration 按 taskId 分发给多个控制器监听器', () async {
    final received = <String>[];
    void first(String taskId) => received.add('first:$taskId');
    void second(String taskId) => received.add('second:$taskId');
    _addListener(first);
    _addListener(second);

    await _sendExpiration('request-3');

    expect(received, ['first:request-3', 'second:request-3']);
  });

  test('移除 listener 后不再收到 expiration', () async {
    final received = <String>[];
    void first(String taskId) => received.add('first:$taskId');
    void second(String taskId) => received.add('second:$taskId');
    _addListener(first);
    _addListener(second);
    task.removeExpirationListener(first);
    _listeners.remove(first);

    await _sendExpiration('request-4');

    expect(received, ['second:request-4']);
  });

  test('某个 listener 抛错不会阻断其他 listener', () async {
    final received = <String>[];
    void throwing(String _) => throw StateError('checkpoint failed');
    void healthy(String taskId) => received.add(taskId);
    _addListener(throwing);
    _addListener(healthy);

    await _sendExpiration('request-5');

    expect(received, ['request-5']);
  });
}

final _listeners = <void Function(String)>[];

void _addListener(void Function(String taskId) listener) {
  _listeners.add(listener);
  FiniteBackgroundTask.instance.addExpirationListener(listener);
}

Future<void> _sendExpiration(String taskId) async {
  final codec = const StandardMethodCodec();
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        _channelName,
        codec.encodeMethodCall(
          MethodCall(FiniteBackgroundTask.expirationMethod, taskId),
        ),
        (_) {},
      );
}
