import 'package:flutter/material.dart';
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: DSThemeBridge(
        // DSFab 内部取 AppTheme，需包桥
        child: Builder(
          builder: (_) => DSFab(
            onPressed: () => _showQuickCreateDialog(context),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 日期横条：切换当前选中日期，日期卡片跟随刷新
            const HomeDateBar(),
            // 排序选项条
            const HomeDateSortBar(),
            // 底部留出悬浮导航栏的高度，最后一行卡片可完整滚出遮挡区
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom,
                ),
                child: const HomeDateViewGrid(),
              ),
            ),
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
