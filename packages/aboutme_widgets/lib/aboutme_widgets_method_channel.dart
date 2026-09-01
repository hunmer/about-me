import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'aboutme_widgets_platform_interface.dart';

/// An implementation of [AboutmeWidgetsPlatform] that uses method channels.
class MethodChannelAboutmeWidgets extends AboutmeWidgetsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('aboutme_widgets');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
