// 端到端验证 Aboutme 接入：复刻 main.dart 的 setupLoggerFromEnv 初始化，
// 并用第二个成员订阅 $procm/log 验证日志确实进入全局 7331 的 aboutme 房间。
// 用法：dart run tool/procm_room_check.dart
import 'dart:async';

import 'package:procm_sdk_dart/procm_sdk_dart.dart';

Future<void> main() async {
  const url = 'ws://127.0.0.1:7331/room';
  const room = 'aboutme';

  // 模拟 main.dart 中由 procm-commands.json 注入的环境变量
  final app = ProcmClient(ProcmClientOptions(
    url: url,
    roomId: room,
    clientName: 'aboutme-app',
    reconnect: false,
  ));
  final opened = Completer<void>();
  app.onState((state) {
    if (state == ProcmConnectionState.open && !opened.isCompleted) opened.complete();
  });
  await opened.future.timeout(const Duration(seconds: 5));

  final logger = createLogger(LoggerOptions(client: app, clientName: 'aboutme-app'));

  // 观察者订阅日志主题
  final seen = <StructuredLog>[];
  final observer = ProcmClient(ProcmClientOptions(
    url: url,
    roomId: room,
    clientName: 'observer',
    reconnect: false,
  ));
  final observerOpen = Completer<void>();
  observer.onState((state) {
    if (state == ProcmConnectionState.open && !observerOpen.isCompleted) observerOpen.complete();
  });
  await observerOpen.future.timeout(const Duration(seconds: 5));
  final off = subscribeLogs(observer, (entry, message) => seen.add(entry));

  logger.info('Aboutme 启动', {'platform': 'verify'});
  logger.error('Uncaught Exception: simulated', {'stack': '#0 main'});

  for (var i = 0; i < 20 && seen.length < 2; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  off();
  app.close();
  observer.close();

  final infoOk = seen.any((e) => e.message == 'Aboutme 启动' && e.level == LogLevel.info);
  final errorOk = seen.any((e) => e.message.startsWith('Uncaught') && e.level == LogLevel.error);
  print('${infoOk ? 'PASS' : 'FAIL'}: aboutme-app info log reached room aboutme');
  print('${errorOk ? 'PASS' : 'FAIL'}: error log reached room aboutme');
  if (!infoOk || !errorOk) {
    throw StateError('room check failed (seen=${seen.length})');
  }

  // 再验证 HTTP 侧可回收（collectLogs 走全局 7331）
  final collector = ProcmClient(ProcmClientOptions(
    url: url,
    roomId: room,
    clientName: 'collector',
    reconnect: false,
  ));
  final collectorOpen = Completer<void>();
  collector.onState((state) {
    if (state == ProcmConnectionState.open && !collectorOpen.isCompleted) collectorOpen.complete();
  });
  await collectorOpen.future.timeout(const Duration(seconds: 5));
  final collected = await collectLogs(collector, CollectLogsOptions(
    startTime: DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
    clientNames: const ['aboutme-app'],
  ));
  collector.close();
  print('${collected.isNotEmpty ? 'PASS' : 'FAIL'}: collectLogs over 7331 returns aboutme-app entries');
}
