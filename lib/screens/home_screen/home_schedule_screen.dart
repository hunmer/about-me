import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/managers/home_date_controller.dart';
import 'package:aboutme/screens/home_screen/widgets/date_view_grid.dart';
import 'package:aboutme/screens/home_screen/widgets/home_date_bar.dart';
import 'package:aboutme/screens/home_screen/widgets/home_date_sort_bar.dart';
import 'package:aboutme/screens/home_screen/widgets/quick_create_dialog.dart';

/// 日程页（日期数据视图）
///
/// 与主屏幕（看板，[HomeScreenView]）完全独立：
/// 日期横条 + 排序选项 + 日期数据卡片网格，无 AppBar，
/// 选中日期统一存放在 [HomeDateController]。
class HomeScheduleScreen extends StatelessWidget {
  const HomeScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickCreateDialog(context),
        tooltip: 'home_quickCreateTitle'.tr,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: const [
            // 日期横条：切换当前选中日期，日期卡片跟随刷新
            HomeDateBar(),
            // 排序选项条
            HomeDateSortBar(),
            Expanded(child: HomeDateViewGrid()),
          ],
        ),
      ),
    );
  }

  /// 弹出快速新建对话框
  ///
  /// 编辑界面以日程当前选中日期为默认日期
  void _showQuickCreateDialog(BuildContext context) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => QuickCreateDialog(
            onSelected: (item) {
              item.onCreate(context, HomeDateController().date);
            },
          ),
    );
  }
}
