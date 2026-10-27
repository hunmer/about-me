import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/base_plugin.dart';
import 'package:aboutme/core/services/plugin_data_selector/index.dart';

import 'models/scrapbook_page.dart';
import 'services/scrapbook_repository.dart';
import 'screens/scrapbook_list_screen.dart';

part 'scrapbook_data_selectors.dart';

/// 手账插件：手绘拼贴画布（贴纸/文字/涂鸦），
/// 列表用空间清单卡片，编辑走无限画布，内容自动保存
class ScrapbookPlugin extends BasePlugin {
  static ScrapbookPlugin? _instance;
  static ScrapbookPlugin get instance =>
      _instance ??= PluginManager.instance.getPlugin('scrapbook')
          as ScrapbookPlugin;

  @override
  String get id => 'scrapbook';

  @override
  IconData get icon => Icons.auto_stories;

  @override
  Color get color => const Color(0xFFD9388A);

  @override
  Future<void> initialize() async {
    // 数据按需经 ScrapbookRepository 读写，无需启动时初始化

    // 注册数据选择器
    _registerDataSelectors();
  }

  @override
  String? getPluginName(context) => 'scrapbook_name'.tr;

  @override
  Widget buildMainView(BuildContext context) {
    return const ScrapbookListScreen();
  }
}
