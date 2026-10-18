import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/notes/notes_plugin.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/plugins/notes/models/folder.dart';
import 'package:aboutme/plugins/notes/models/note.dart';
import 'package:aboutme/plugins/notes/screens/notes_screen.dart';

/// "已归档"虚拟目录 ID（根目录入口卡片进入，展示所有归档的文件夹/笔记/待办）
const String kArchivedFolderId = 'archived';

class NotesMainViewState extends State<NotesMainView> {
  late final EventManager _eventManager;
  @protected
  String currentFolderId = 'root';
  @protected
  Folder? currentFolder;
  @protected
  List<Folder> subFolders = [];
  @protected
  List<Note> notes = [];
  @protected
  bool isSearching = false;
  @protected
  final TextEditingController searchController = TextEditingController();
  // 多条件过滤状态（标签/日期），供搜索、过滤与路由上下文共享
  @protected
  String? selectedTag;
  @protected
  DateTime? selectedDate;

  late NotesPlugin plugin;

  @override
  void initState() {
    super.initState();
    plugin = NotesPlugin.instance;
    _eventManager = EventManager.instance;
    currentFolderId = widget.folderId;
    // 订阅同步刷新事件
    _eventManager.subscribe('notes_refresh', _handleSyncRefresh);
    loadCurrentFolder();
  }

  /// 处理同步刷新事件
  void _handleSyncRefresh(EventArgs args) {
    debugPrint('[NotesMainView] 收到同步刷新事件');
    loadCurrentFolder();
  }

  /// 当前是否处于"已归档"视图
  @protected
  bool get isArchivedView => currentFolderId == kArchivedFolderId;

  @protected
  void loadCurrentFolder() {
    // 面包屑 popUntil 会连带移除下层页面，push 的 Future 完成时
    // 本页面可能已销毁，此时不能再 setState
    if (!mounted) return;
    setState(() {
      if (isArchivedView) {
        // 已归档视图：平铺展示所有归档的文件夹与笔记
        currentFolder = Folder(
          id: kArchivedFolderId,
          name: 'notes_archived'.tr,
          parentId: 'root',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        subFolders = plugin.controller.getArchivedFolders();
        notes = plugin.controller.getArchivedNotes();
      } else {
        currentFolder = plugin.controller.getFolder(currentFolderId);
        // 普通视图隐藏已归档的子文件夹与笔记
        subFolders = plugin.controller
            .getFolderChildren(currentFolderId)
            .where((folder) => !folder.isArchived)
            .toList();
        notes = plugin.controller
            .getFolderNotes(currentFolderId)
            .where((note) => !note.isArchived)
            .toList();
      }
    });
  }

  /// 以子页面形式进入文件夹（含"已归档"虚拟目录），
  /// 返回手势/返回键回到上一级；返回后刷新本层列表（子项计数等）
  @protected
  void openFolderPage(String folderId) {
    NavigationHelper.push(
      context,
      NotesMainView(folderId: folderId),
    ).then((_) => loadCurrentFolder());
  }

  @protected
  void navigateToFolder(Folder folder) {
    openFolderPage(folder.id);
  }

  @protected
  void navigateBack() {
    if (currentFolder?.parentId != null) {
      setState(() {
        currentFolderId = currentFolder!.parentId!;
        loadCurrentFolder();
      });
    }
  }

  @protected
  void handleSearch(String query) {
    if (query.isEmpty) {
      loadCurrentFolder();
    } else {
      final searchResults = plugin.controller.searchNotes(query: query);
      setState(() {
        // 普通搜索不搜出已归档笔记；已归档视图内只搜已归档
        notes = searchResults
            .where((note) => note.isArchived == isArchivedView)
            .toList();
        subFolders = [];
      });
    }
  }

  @override
  void dispose() {
    _eventManager.unsubscribe('notes_refresh', _handleSyncRefresh);
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }
}
