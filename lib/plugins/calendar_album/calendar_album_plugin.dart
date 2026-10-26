// ignore_for_file: unintended_html_in_doc_comment

import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/config_manager.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/js_bridge/js_bridge_plugin.dart';
import 'package:aboutme/plugins/base_plugin.dart';
import 'package:shared_models/usecases/calendar_album/calendar_album_usecase.dart';
import 'widgets/calendar_album_bottom_bar.dart';
import 'controllers/calendar_controller.dart';
import 'controllers/tag_controller.dart';
import 'repositories/client_calendar_album_repository.dart';
import 'screens/entry_editor/calendar_album_entry_form.dart';

// HTTP 服务器导入
import 'package:aboutme/plugins/webview/services/local_http_server.dart';
import 'calendar_album_widget_methods.dart';

part 'calendar_album_js_api.dart';

/// 日历相册插件主视图
class CalendarAlbumMainView extends StatelessWidget {
  const CalendarAlbumMainView({super.key});

  @override
  Widget build(BuildContext context) {
    return CalendarAlbumBottomBar(plugin: CalendarAlbumPlugin.instance);
  }
}

class CalendarAlbumPlugin extends BasePlugin
    with JSBridgePlugin, CalendarAlbumWidgetMethods {
  static CalendarAlbumPlugin? _instance;
  static CalendarAlbumPlugin get instance {
    if (_instance == null) {
      _instance =
          PluginManager.instance.getPlugin('calendar_album')
              as CalendarAlbumPlugin?;
      if (_instance == null) {
        throw StateError('CalendarAlbumPlugin has not been initialized');
      }
    }
    return _instance!;
  }

  /// 支持刷新的文件路径前缀
  static const List<String> _refreshableFiles = [
    'calendar_album/',
  ];

  @override
  bool supportsFileRefresh(String filePath) {
    return _refreshableFiles.any((f) => filePath.startsWith(f));
  }

  @override
  Future<bool> refreshData([PluginRefreshDataArgs? args]) async {
    try {
      debugPrint('[CalendarAlbumPlugin] 开始刷新数据, 文件: ${args?.filePath}');
      // 重新加载日记数据
      await _calendarController?.reloadEntries();
      debugPrint('[CalendarAlbumPlugin] 数据刷新成功');
      return true;
    } catch (e) {
      debugPrint('[CalendarAlbumPlugin] 数据刷新失败: $e');
      return false;
    }
  }

  CalendarController? _calendarController;
  @override
  CalendarController? get calendarController => _calendarController;

  @override
  VoidCallback? buildCreatedDetailOpener(
    BuildContext context,
    String method,
    Map<String, dynamic> created,
  ) {
    if (method != 'addEntry' && method != 'createPhoto') return null;
    final id = created['id'];
    if (id is! String || id.isEmpty) return null;
    return () {
      final calendar = calendarController;
      final tags = tagController;
      final entry = calendar?.getEntryById(id);
      if (calendar == null || tags == null || entry == null) return;
      CalendarAlbumEntryForm.show(
        context,
        entry: entry,
        calendarController: calendar,
        tagController: tags,
      );
    };
  }

  @override
  List<PluginSampleDataGroup> getSampleDataGroups() => [
    PluginSampleDataGroup(
      id: 'entries',
      title: 'calendarAlbum_sampleEntriesTitle'.tr,
      description: 'calendarAlbum_sampleEntriesDesc'.tr,
      apply: () async {
        final controller = _calendarController;
        if (controller == null) return;
        await controller.loadSampleData();
      },
    ),
  ];

  TagController? _tagController;
  @override
  TagController? get tagController => _tagController;

  CalendarAlbumUseCase? _useCase;
  CalendarAlbumUseCase get useCase {
    if (_useCase == null) {
      throw StateError('CalendarAlbumUseCase has not been initialized');
    }
    return _useCase!;
  }

  @override
  String get id => 'calendar_album';

  @override
  Color get color => const Color.fromARGB(255, 245, 210, 52);

  @override
  IconData get icon => Icons.notes_rounded;

  @override
  Future<void> initialize() async {
    _calendarController = CalendarController();
    _tagController = TagController(onTagsChanged: () {});

    // 初始化 UseCase
    _useCase = CalendarAlbumUseCase(
      ClientCalendarAlbumRepository(
        calendarController: _calendarController!,
        tagController: _tagController!,
      ),
    );

    await initializeDefaultData();

    // 注册 JS API（最后一步）
    await registerJSAPI();
  }

  @override
  String? getPluginName(context) {
    return 'calendar_album_name'.tr;
  }

  @override
  Future<void> registerToApp(
    PluginManager pluginManager,
    ConfigManager configManager,
  ) async {
    // 插件已在 initialize() 中完成初始化
    // 这里可以添加额外的应用级注册逻辑
  }

  @override
  Widget buildMainView(BuildContext context) {
    return const CalendarAlbumMainView();
  }

  @override
  Widget? buildCardView(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部图标和标题
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                'calendar_album_name'.tr,

                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 统计信息卡片
          Column(
            children: [
              // 第一行 - 今日日记和七日日记
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 今日日记
                  Column(
                    children: [
                      Text(
                        'calendar_album_today_diary'.tr,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '${calendarController?.getTodayEntriesCount() ?? 0}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  // 七日日记
                  Column(
                    children: [
                      Text(
                        'calendar_album_seven_days_diary'.tr,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '${calendarController?.getLast7DaysEntriesCount() ?? 0} ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 第二行 - 所有日记和标签
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 所有日记
                  Column(
                    children: [
                      Text(
                        'calendar_album_all_diaries'.tr,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '${calendarController?.getAllEntriesCount() ?? 0} ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  // 标签数量
                  Column(
                    children: [
                      Text(
                        'calendar_album_tag_count'.tr,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '${tagController?.tags.length ?? 0} ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== JS API 定义 ====================

  @override
  Map<String, Function> defineJSAPI() {
    return {

      // 日记相关
      'getEntries': _jsGetEntries,
      'getEntriesForDate': _jsGetEntriesForDate,
      'addEntry': _jsAddEntry,
      'updateEntry': _jsUpdateEntry,
      'deleteEntry': _jsDeleteEntry,
      'getEntryById': _jsGetEntryById,

      // 标签相关
      'getTags': _jsGetTags,
      'getEntriesByTag': _jsGetEntriesByTag,
      'getEntriesByTags': _jsGetEntriesByTags,

      // 照片相关
      'getPhotos': _jsGetPhotos,
      'getPhotosByDateRange': _jsGetPhotosByDateRange,
      'createPhoto': _jsCreatePhoto,

      // 统计相关
      'getStatistics': _jsGetStatistics,

      // 日记查找方法
      'findEntryBy': _jsFindEntryBy,
      'findEntryById': _jsFindEntryById,
      'findEntryByTitle': _jsFindEntryByTitle,
    };
  }
}
