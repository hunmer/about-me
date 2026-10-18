import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'notes_screen_state.dart';

mixin NotesRouteContext on NotesMainViewState {
  /// 更新路由上下文，使"询问当前上下文"功能能获取到当前笔记列表的过滤状态
  void updateRouteContext() {
    final folderName = currentFolder?.name ?? 'Root';
    final params = <String, String>{
      'folderId': currentFolderId,
      'folderName': folderName,
    };

    // 构建标题描述
    final titleParts = <String>['笔记列表 - $folderName'];

    // 添加标签过滤
    if (selectedTag != null) {
      params['tag'] = selectedTag!;
      titleParts.add('标签: $selectedTag');
    }

    // 添加日期过滤
    if (selectedDate != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
      params['date'] = dateStr;
      titleParts.add('日期: $dateStr');
    }

    // 添加搜索关键词
    if (isSearching && searchController.text.isNotEmpty) {
      params['searchQuery'] = searchController.text;
      titleParts.add('搜索: ${searchController.text}');
    }

    final title = titleParts.join(' | ');

    RouteHistoryManager.updateCurrentContext(
      pageId: '/notes_list',
      title: title,
      params: params,
    );
  }

  @override
  void initState() {
    super.initState();
    // 延迟执行以确保 currentFolder 已初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateRouteContext();
    });
  }

  @override
  void loadCurrentFolder() {
    super.loadCurrentFolder();
    updateRouteContext();
  }
}
