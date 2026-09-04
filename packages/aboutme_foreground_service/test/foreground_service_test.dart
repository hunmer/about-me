import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme_foreground_service/aboutme_foreground_service.dart';

/// flutter_foreground_task 只提供 Android/iOS 原生实现。
/// 测试宿主（Windows/Linux/macOS）上方法通道没有原生处理器，
/// 与应用在 Windows 桌面运行时的条件完全一致：
/// 任何未加平台判断的通道调用都会抛出 MissingPluginException。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initialize() 在无原生实现的平台上是安全的空操作', () async {
    await expectLater(
      AboutmeForegroundService.instance.initialize(),
      completes,
    );
  });

  test('isRunning 在不支持的平台返回 false', () async {
    expect(await AboutmeForegroundService.instance.isRunning, isFalse);
  });

  test('checkNotificationPermission 在不支持的平台返回 false', () async {
    expect(
      await AboutmeForegroundService.instance.checkNotificationPermission(),
      isFalse,
    );
  });
}
