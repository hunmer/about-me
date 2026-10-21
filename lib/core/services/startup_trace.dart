import 'package:flutter/foundation.dart';

/// 启动诊断直接写终端，供 procm 捕获；不依赖尚未就绪的存储/日志服务。
class StartupTrace {
  static const enabled = bool.fromEnvironment(
    'STARTUP_TRACE',
    defaultValue: !kReleaseMode,
  );
  static final _clock = Stopwatch();

  static void start() {
    _clock.reset();
    _clock.start();
    mark('main');
  }

  static void mark(String stage) {
    if (!enabled) return;
    debugPrintSynchronously(
      '[Startup] +${_clock.elapsedMilliseconds}ms $stage',
    );
  }

  static Future<T> measure<T>(String stage, Future<T> Function() action) async {
    if (!enabled) return action();
    final timer = Stopwatch()..start();
    mark('$stage begin');
    try {
      final result = await action();
      mark('$stage done duration=${timer.elapsedMilliseconds}ms');
      return result;
    } catch (error) {
      mark(
        '$stage failed duration=${timer.elapsedMilliseconds}ms error=$error',
      );
      rethrow;
    }
  }
}
