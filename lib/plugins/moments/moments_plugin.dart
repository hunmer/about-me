import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/plugins/base_plugin.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';

import 'screens/moments_home_screen.dart';

/// 朋友圈插件：复刻 skygram 参考稿的两块 UI（动态流 + 个人主页），
/// 数据与 agent 朋友圈（活人感/MomentsService）完全打通
class MomentsPlugin extends BasePlugin {
  @override
  String get id => 'moments';

  @override
  IconData get icon => Icons.photo_camera_outlined;

  @override
  Color get color => const Color(0xFF0088FF);

  @override
  Future<void> initialize() async {
    await MomentsService.instance.loadPosts();
  }

  @override
  String? getPluginName(context) => 'moments_name'.tr;

  @override
  Widget buildMainView(BuildContext context) {
    return const MomentsHomeScreen();
  }
}
