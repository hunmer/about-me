/// 日记插件 - 日记日卡小组件注册（按日期聚合）
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Memento/screens/home_screen/managers/home_widget_registry.dart';
import 'package:Memento/screens/home_screen/managers/home_date_controller.dart';
import 'package:Memento/screens/home_screen/models/home_widget_size.dart';
import 'package:Memento/screens/home_screen/widgets/home_widget.dart';
import 'package:Memento/widgets/event_listener_container.dart';
import 'package:Memento/core/navigation/navigation_helper.dart';
import 'package:Memento/plugins/diary/diary_plugin.dart';
import 'package:Memento/plugins/diary/models/diary_entry.dart';
import 'package:Memento/plugins/diary/utils/diary_utils.dart';
import 'package:Memento/plugins/diary/widgets/diary_entry_card.dart';
import 'package:Memento/plugins/diary/screens/diary_editor_screen.dart';

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
      supportedSizes: const [
        Large3Size(),
        Wide2Size(),
        Wide3Size(),
      ],
      category: 'home_categoryRecord'.tr,
      isDateDriven: true,
      hasDateData: (date) async {
        try {
          return await DiaryUtils.loadDiaryEntry(date) != null;
        } catch (_) {
          return false;
        }
      },
      builder: (context, config) => const _DiaryDayCardHomeWidget(),
    ),
  );
}

/// 日记日卡内容：读取主页选中日期的日记并用 DiaryEntryCard 渲染
class _DiaryDayCardHomeWidget extends StatefulWidget {
  const _DiaryDayCardHomeWidget();

  @override
  State<_DiaryDayCardHomeWidget> createState() => _DiaryDayCardHomeWidgetState();
}

class _DiaryDayCardHomeWidgetState extends State<_DiaryDayCardHomeWidget> {
  DiaryEntry? _entry;
  DateTime? _loadingFor;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    HomeDateController().addListener(_loadEntry);
    _loadEntry();
  }

  @override
  void dispose() {
    HomeDateController().removeListener(_loadEntry);
    super.dispose();
  }

  /// 加载选中日期的日记（当前数据模型为一天一篇）
  Future<void> _loadEntry() async {
    final date = HomeDateController().date;
    _loadingFor = date;
    try {
      final entry = await DiaryUtils.loadDiaryEntry(date);
      if (!mounted || _loadingFor != date) return;
      setState(() {
        _entry = entry;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || _loadingFor != date) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EventListenerContainer(
      events: const [
        'diary_entry_created',
        'diary_entry_updated',
        'diary_entry_deleted',
        'diary_refresh',
      ],
      onEvent: _loadEntry,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final entry = _entry;
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
        onTap: () => _openEditor(entry),
      ),
    );
  }

  /// 打开日记编辑器（与插件页一致，带原文预填）
  void _openEditor(DiaryEntry entry) {
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
