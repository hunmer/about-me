import 'package:flutter/foundation.dart';

/// 插件 settings 的运行时镜像；舞台无需依赖插件初始化或负责持久化。
class VideoPetPreferences {
  VideoPetPreferences._();

  static final randomWalkEnabled = ValueNotifier<bool>(false);
}
