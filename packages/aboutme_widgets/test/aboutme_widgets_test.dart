import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme_widgets/aboutme_widgets.dart';
import 'package:aboutme_widgets/aboutme_widgets_platform_interface.dart';
import 'package:aboutme_widgets/aboutme_widgets_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAboutmeWidgetsPlatform
    with MockPlatformInterfaceMixin
    implements AboutmeWidgetsPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final AboutmeWidgetsPlatform initialPlatform = AboutmeWidgetsPlatform.instance;

  test('$MethodChannelAboutmeWidgets is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAboutmeWidgets>());
  });

  test('getPlatformVersion', () async {
    AboutmeWidgets aboutmeWidgetsPlugin = AboutmeWidgets();
    MockAboutmeWidgetsPlatform fakePlatform = MockAboutmeWidgetsPlatform();
    AboutmeWidgetsPlatform.instance = fakePlatform;

    expect(await aboutmeWidgetsPlugin.getPlatformVersion(), '42');
  });
}
