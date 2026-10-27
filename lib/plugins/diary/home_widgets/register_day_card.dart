/// 日记插件 - 日记日卡小组件注册（按日期聚合）
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/managers/home_date_controller.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import '../widgets/diary_query_guard.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/diary/diary_plugin.dart';
import 'package:aboutme/plugins/diary/models/diary_entry.dart';
import 'package:aboutme/plugins/diary/utils/diary_utils.dart';
import 'package:aboutme/plugins/diary/widgets/diary_entry_card.dart';
import 'package:aboutme/plugins/diary/screens/diary_editor_screen.dart';

/// 注册日记日卡小组件（展示主页选中日期的日记）
void registerDayCardWidget(HomeWidgetRegistry registry) {
  registry.register(
    HomeWidget(
      id: 'diary_day_card',
      pluginId: 'diary',
      name: 'diary_dayCardName'.tr,
      description: 'diary_dayCardDesc'.tr,
      icon: Icons.menu_book,
      color: const Color(0xFFD8BFD8),
      defaultSize: const Wide2Size(),
      supportedSizes: const [Large3Size(), Wide2Size(), Wide3Size()],
      category: 'home_categoryRecord'.tr,
      isDateDriven: true,
      hasDateData: (date) async {
        try {
          return await DiaryUtils.loadDiaryEntry(date) != null;
        } catch (_) {
          // 查询失败时仍显示卡片，由 SDK watch 展示错误和重试。
          return true;
        }
      },
      builder: (context, config) => const _DiaryDayCardHomeWidget(),
    ),
  );
}

/// 日记日卡内容：读取主页选中日期的日记并用 DiaryEntryCard 渲染
class _DiaryDayCardHomeWidget extends StatelessWidget {
  const _DiaryDayCardHomeWidget();

  @override
  Widget build(BuildContext context) => DiarySnapshotBuilder(
    builder: (context, entries) => ListenableBuilder(
      listenable: HomeDateController(),
      builder: (context, _) {
        final date = HomeDateController().date;
        return _buildContent(
          context,
          entries[DateTime(date.year, date.month, date.day)],
        );
      },
    ),
  );

  Widget _buildContent(BuildContext context, DiaryEntry? entry) {
    final theme = Theme.of(context);
    if (entry == null) {
      // 空状态
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 32,
              color: theme.disabledColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 4),
            Text(
              'diary_dayCardEmpty'.tr,
              style: TextStyle(
                color: theme.disabledColor.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(4),
      child: DiaryEntryCard(
        entry: entry,
        onTap: () => _openEditor(context, entry),
      ),
    );
  }

  /// 打开日记编辑器（与插件页一致，带原文预填）
  void _openEditor(BuildContext context, DiaryEntry entry) {
    NavigationHelper.push(
      context,
      DiaryEditorScreen(
        date: entry.date,
        storage: DiaryPlugin.instance.storage,
        initialTitle: entry.title,
        initialContent: entry.content,
      ),
    );
  }
}
