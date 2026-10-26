import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/base_plugin.dart';

import 'screens/personal_assistant_screen.dart';

/// 个人助手插件：手绘风快捷速记聊天（原果冻小屋助手页签），
/// 会话与消息数据复用 agent_chat 插件（内置「聊天助手」agent 的临时会话）
class PersonalAssistantPlugin extends BasePlugin {
  static PersonalAssistantPlugin? _instance;
  static PersonalAssistantPlugin get instance =>
      _instance ??= PluginManager.instance.getPlugin('personal_assistant')
          as PersonalAssistantPlugin;

  @override
  String get id => 'personal_assistant';

  @override
  IconData get icon => Icons.auto_awesome;

  @override
  Color get color => const Color(0xFF7C5CFF);

  @override
  Future<void> initialize() async {
    // 会话依赖 agent_chat 插件，视图内监听 plugin_loaded 事件自行初始化
  }

  @override
  String? getPluginName(context) => 'personal_assistant_name'.tr;

  @override
  Widget buildMainView(BuildContext context) {
    return const PersonalAssistantScreen();
  }
}
