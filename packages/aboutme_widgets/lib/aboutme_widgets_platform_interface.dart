import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'aboutme_widgets_method_channel.dart';

abstract class AboutmeWidgetsPlatform extends PlatformInterface {
  /// Constructs a AboutmeWidgetsPlatform.
  AboutmeWidgetsPlatform() : super(token: _token);

  static final Object _token = Object();

  static AboutmeWidgetsPlatform _instance = MethodChannelAboutmeWidgets();

  /// The default instance of [AboutmeWidgetsPlatform] to use.
  ///
  /// Defaults to [MethodChannelAboutmeWidgets].
  static AboutmeWidgetsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AboutmeWidgetsPlatform] when
  /// they register themselves.
  static set instance(AboutmeWidgetsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
