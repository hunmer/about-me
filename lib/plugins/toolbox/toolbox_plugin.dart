import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:aboutme/core/js_bridge/js_bridge_plugin.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/plugins/base_plugin.dart';
import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/plugins/toolbox/screens/toolbox_home_screen.dart';
import 'package:aboutme/plugins/toolbox/services/ai_image_service.dart';
import 'package:aboutme/plugins/toolbox/services/image_search_service.dart';

part 'toolbox_js_api.dart';

/// 工具箱插件：聚合轻量小工具（原内置 JS 脚本 image_search / ai_image
/// 于 2026-10 迁入为原生小工具，各自拥有独立界面与控制器）
class ToolboxPlugin extends BasePlugin with JSBridgePlugin {
  static ToolboxPlugin? _instance;

  static ToolboxPlugin get instance {
    if (_instance == null) {
      _instance = PluginManager.instance.getPlugin('toolbox') as ToolboxPlugin?;
      if (_instance == null) {
        throw StateError('ToolboxPlugin has not been initialized');
      }
    }
    return _instance!;
  }

  ImageSearchService get imageSearch => ImageSearchService.instance;
  AiImageService get aiImage => AiImageService.instance;

  @override
  String get id => 'toolbox';

  @override
  Color? get color => const Color(0xFF7A9E7E);

  @override
  IconData? get icon => Icons.home_repair_service_outlined;

  @override
  Future<void> initialize() async {
    // 预载配置（含旧脚本配置迁移）
    await imageSearch.ensureLoaded();
    await aiImage.ensureLoaded();
    // 注册 JS API（最后一步）
    await registerJSAPI();
  }

  @override
  Widget buildMainView(BuildContext context) {
    return const DSThemeBridge(child: ToolboxHomeScreen());
  }

  @override
  Map<String, Function> defineJSAPI() {
    return {'searchImages': jsSearchImages, 'generateImages': jsGenerateImages};
  }
}
