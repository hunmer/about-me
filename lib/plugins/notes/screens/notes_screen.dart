import '../widgets/sdk_query_status.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'notes_screen/folder_operations.dart';
import 'notes_screen/folder_selection_dialog.dart';
import 'notes_screen/note_operations.dart';
import 'notes_screen/notes_body.dart';
import 'notes_screen/notes_fab.dart';
import 'notes_screen/notes_filtering.dart';
import 'notes_screen/notes_route_context.dart';
import 'notes_screen/notes_screen_state.dart';

class NotesMainView extends StatefulWidget {
  /// 初始打开的文件夹（'root' 根目录，kArchivedFolderId 已归档视图）
  final String folderId;

  const NotesMainView({super.key, this.folderId = 'root'});

  @override
  State<NotesMainView> createState() => _NotesMainViewState();
}

class _NotesMainViewState extends NotesMainViewState
    with
        FolderOperations,
        NoteOperations,
        FolderSelectionDialog,
        NotesRouteContext,
        NotesFiltering,
        NotesFab,
        NotesBody {
  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return SuperCupertinoNavigationWrapper(
      title: Text(
        currentFolder?.name ?? 'notes_defaultFolderName'.tr,
        style: DsTypography.title.copyWith(color: theme.text, fontSize: 16),
      ),
      largeTitle: 'notes_myNotes'.tr,

      body: NotesQueryStatus(
        status: plugin.controller.queryStatus,
        error: plugin.controller.queryError,
        retry: plugin.controller.reloadData,
        child: DSThemeBridge(child: buildBody()),
      ),
      enableLargeTitle: true,
      enableSearchBar: true,
      enableMultiFilter: true,
      multiFilterItems: buildFilterItems(),
      multiFilterBarHeight: 50,
      onMultiFilterChanged: applyMultiFilters,
      searchPlaceholder: 'notes_searchPlaceholder'.tr,
      onSearchChanged: handleSearchChanged,
      onSearchSubmitted: handleSearchSubmitted,
      actions: [
        // 第三方导航栏回调：DS 组件需包 DSThemeBridge
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: isSearching ? DsIconKind.close : DsIconKind.more,
                size: 38,
                color: theme.surface,
                iconColor: theme.text,
                onPressed: () {
                  if (isSearching) {
                    setState(() {
                      searchController.clear();
                      loadCurrentFolder();
                      isSearching = false;
                    });
                  }
                },
              );
            },
          ),
        ),
      ],
      largeTitleActions: [],
    );
  }
}
