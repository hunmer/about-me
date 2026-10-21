import 'dart:io';

import 'package:aboutme/core/js_bridge/platform/mobile_js_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Windows 测试需把 build/windows/x64/runner/Debug 加入 PATH，以加载 QuickJS DLL。
  group('QuickJS result polling', () {
    late MobileJSEngine engine;

    setUp(() async {
      engine = MobileJSEngine();
      await engine.initialize();
    });

    tearDown(() => engine.dispose());

    test('completed scripts return without the fixed warm-up delay', () async {
      final clock = Stopwatch()..start();
      final zero = await engine.evaluate('return 0;');
      final empty = await engine.evaluate('return "";');
      final object = await engine.evaluate('return {ok: true};');

      expect(zero.success, isTrue);
      expect(zero.result, 0);
      expect(empty.success, isTrue);
      expect(empty.result, '');
      expect(object.result, {'ok': true});
      expect(clock.elapsedMilliseconds, lessThan(500));
    });

    test('Dart callback can finish after the warm-up polling window', () async {
      await engine.registerFunction('delayedValue', () async {
        await Future<void>.delayed(const Duration(milliseconds: 650));
        return {'value': 42};
      });
      final result = await engine.evaluate(
        'return await delayedValue();',
        timeout: const Duration(seconds: 3),
      );

      expect(result.success, isTrue, reason: result.error);
      expect(result.result, {'value': 42});
    });

    test('script errors still propagate', () async {
      final result = await engine.evaluate('throw new Error("test failure");');
      expect(result.success, isFalse);
      expect(result.error, contains('test failure'));
    });

    test('pending promises still time out', () async {
      final result = await engine.evaluate(
        'return await new Promise(function() {});',
        timeout: const Duration(milliseconds: 100),
      );
      expect(result.success, isFalse);
      expect(result.error, contains('超时'));
    });
  }, skip: !Platform.isWindows);
}
