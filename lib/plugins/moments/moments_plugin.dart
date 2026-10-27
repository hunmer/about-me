import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/plugins/base_plugin.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'package:aboutme/plugins/openai/moments/models/moment_post.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/services/plugin_data_selector/index.dart';

import 'screens/moments_home_screen.dart';

part 'moments_data_selectors.dart';

/// 朋友圈插件：复刻 skygram 参考稿的两块 UI（动态流 + 个人主页），
/// 数据与 agent 朋友圈（活人感/MomentsService）完全打通
class MomentsPlugin extends BasePlugin {
  static MomentsPlugin? _instance;

  static MomentsPlugin get instance =>
      _instance ??= PluginManager.instance.getPlugin('moments')
          as MomentsPlugin;

  @override
  String get id => 'moments';

  @override
  IconData get icon => Icons.photo_camera_outlined;

  @override
  Color get color => const Color(0xFF0088FF);

  @override
  Future<void> initialize() async {
    await MomentsService.instance.loadPosts();

    // 注册数据选择器
    _registerDataSelectors();
  }

  @override
  String? getPluginName(context) => 'moments_name'.tr;

  @override
  Widget buildMainView(BuildContext context) {
    return const MomentsHomeScreen();
  }
}
