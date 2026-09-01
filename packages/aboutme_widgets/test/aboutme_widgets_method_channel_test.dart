import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme_widgets/aboutme_widgets_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelAboutmeWidgets platform = MethodChannelAboutmeWidgets();
  const MethodChannel channel = MethodChannel('aboutme_widgets');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
