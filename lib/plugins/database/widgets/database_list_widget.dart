import 'dart:io' show File;

import 'package:get/get.dart';
import 'package:aboutme/plugins/database/controllers/database_controller.dart';
import 'package:aboutme/plugins/database/widgets/database_detail_widget.dart';
import 'package:aboutme/plugins/database/widgets/database_edit_widget.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/arc_context_menu.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:skribble/skribble.dart';
import 'package:uuid/uuid.dart';
import '../../../../widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/plugins/database/models/database_model.dart';
import 'package:aboutme/plugins/database/services/database_service.dart';
import 'package:aboutme/core/event/event_manager.dart';

class DatabaseListWidget extends StatefulWidget {
  final DatabaseService service;

  const DatabaseListWidget({super.key, required this.service});

  @override
  State<DatabaseListWidget> createState() => _DatabaseListWidgetState();
}

class _DatabaseListWidgetState extends State<DatabaseListWidget> {
  late Future<List<DatabaseModel>> _databasesFuture;
  String _searchQuery = '';
  List<DatabaseModel> _allDatabases = [];

  @override
  void initState() {
    super.initState();
    final events = EventManager.instance;
    events.subscribe('database_added', _onDatabaseChanged);
    events.subscribe('database_updated', _onDatabaseChanged);
    events.subscribe('database_deleted', _onDatabaseChanged);
    events.subscribe('database_refresh', _onDatabaseChanged);
    _loadDatabases();
  }

  void _onDatabaseChanged(EventArgs _) {
    if (!mounted) return;
    _loadDatabases();
  }

  @override
  void dispose() {
    final events = EventManager.instance;
    events.unsubscribe('database_added', _onDatabaseChanged);
    events.unsubscribe('database_updated', _onDatabaseChanged);
    events.unsubscribe('database_deleted', _onDatabaseChanged);
    events.unsubscribe('database_refresh', _onDatabaseChanged);
    super.dispose();
  }

  Future<void> _loadDatabases() async {
    _databasesFuture = widget.service.getAllDatabases();
    _allDatabases = await _databasesFuture;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return SuperCupertinoNavigationWrapper(
      title: Text('database_database_list_title'.tr),
      largeTitle: 'database_database_list_title'.tr,
      enableLargeTitle: true,

      // 启用搜索栏
      enableSearchBar: true,
      searchPlaceholder: 'database_search_databases'.tr,
      onSearchChanged: (query) {
        setState(() {
          _searchQuery = query;
        });
      },

      // 添加新建按钮
      // SuperAppBar 的 actions 经 Overlay 渲染,DS 组件需自带 DSThemeBridge
      actions: [
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              return DSIconButton(
                icon: DsIconKind.plus,
                size: 40,
                tooltip: 'database_add_database'.tr,
                onPressed: () => _showAddDatabaseDialog(context),
              );
            },
          ),
        ),
      ],

      // 列表内容用 DS 组件,统一经桥接取手绘主题
      body: DSThemeBridge(
        child: FutureBuilder<List<DatabaseModel>>(
          future: _databasesFuture,
          builder: (context, snapshot) {
            final theme = DSThemeBridge.resolve(context);

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: DSLoadingDots(color: theme.textSub));
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DsIcon(DsIconKind.warning, size: 64, color: theme.danger),
                    const SizedBox(height: 16),
                    Text(
                      'database_load_failed_message'.tr,
                      style: DsTypography.title.copyWith(color: theme.danger),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    DSButton(
                      label: 'app_retry'.tr,
                      icon: DsIconKind.refresh,
                      onPressed: _loadDatabases,
                    ),
                  ],
                ),
              );
            }

            // 保存到本地变量并应用搜索过滤
            _allDatabases = snapshot.data ?? [];
            final databases = _searchQuery.isEmpty
                ? _allDatabases
                : _allDatabases.where((db) {
                    return db.name.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    );
                  }).toList();

            if (databases.isEmpty) {
              return Center(
                child: DSEmptyState(
                  icon: DsIconKind.inbox,
                  title: 'database_no_databases_message'.tr,
                  message: 'database_add_database_hint'.tr,
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                await _loadDatabases();
              },
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: databases.length,
                itemBuilder: (context, index) {
                  final database = databases[index];
                  // 手绘便签倾斜 + 贴条（角度由数据库 id 哈希确定），
                  // 挂载即播墨线描画入场（design.md §10/§11）
                  return HandDrawnStickyItem(
                    tiltKey: database.id,
                    child: WiredDraw(child: _buildDatabaseCard(database)),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  /// 数据库卡片：手绘纸底面板 + 封面 + 名称
  Widget _buildDatabaseCard(DatabaseModel database) {
    final theme = DSThemeBridge.resolve(context);

    // 长按弹圆盘快捷菜单（编辑/复制/删除；tap 由 DSCard 内部 Pressable 处理）
    return ArcContextMenu.actions(
      actions: _databaseActions(database),
      showMore: () => _showBottomSheet(context, database),
      child: DSCard(
        padding: EdgeInsets.zero,
        onTap: () {
          NavigationHelper.pushAnimated(
            context,
            DatabaseDetailWidget(
              controller: DatabaseController(widget.service),
              databaseId: database.id,
            ),
            routeName: '/database_detail',
          ).then((_) => _loadDatabases());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: database.coverImage != null
                  ? FutureBuilder<String>(
                      future: ImageUtils.getAbsolutePath(database.coverImage!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: DSLoadingDots(color: theme.textSub),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return _buildCoverPlaceholder(theme);
                        }
                        return _buildImageWidget(snapshot.data!, theme);
                      },
                    )
                  : _buildCoverPlaceholder(theme),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                database.name,
                style: DsTypography.heading.copyWith(color: theme.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 无封面时的手绘占位
  Widget _buildCoverPlaceholder(AppThemeData theme) {
    return Container(
      color: theme.surfaceAlt,
      child: Center(
        child: DsIcon(DsIconKind.storage, size: 48, color: theme.textSub),
      ),
    );
  }

  /// 长按快捷菜单项（圆盘与底部 sheet 共用）
  List<ArcMenuItem> _databaseActions(DatabaseModel database) => [
        ArcMenuItem(
          icon: DsIconKind.edit,
          label: 'app_edit'.tr,
          onTap: () => _showDatabaseEditor(context, database),
        ),
        ArcMenuItem(
          icon: DsIconKind.copy,
          label: 'app_copy'.tr,
          onTap: () async {
            final newDatabase = database.copyWith(id: Uuid().v4());
            await widget.service.createDatabase(newDatabase);
            if (mounted) {
              Toast.success('database_copy_success'.tr);
              _loadDatabases();
            }
          },
        ),
        ArcMenuItem(
          icon: DsIconKind.trash,
          label: 'database_delete_action'.tr,
          destructive: true,
          onTap: () => _confirmDeleteDatabase(database),
        ),
      ];

  Future<void> _showBottomSheet(
    BuildContext context,
    DatabaseModel database,
  ) {
    return SmoothBottomSheet.showActionList(
      context: context,
      actions: _databaseActions(database),
    );
  }

  /// 删除数据库（确认弹窗），长按圆盘与底部 sheet 共用
  Future<void> _confirmDeleteDatabase(DatabaseModel database) async {
    final confirm = await showDSDialog<bool>(
      context: context,
      builder: (context) => DSDialog(
        title: 'database_confirm_delete_title'.tr,
        message: 'database_confirm_delete_message'.trParams({
          'name': database.name,
        }),
        confirmText: 'database_delete'.tr,
        cancelText: 'app_cancel'.tr,
        confirmVariant: DSButtonVariant.destructive,
      ),
    );
    if (confirm != true) return;
    try {
      await widget.service.deleteDatabase(database.id);
      if (mounted) {
        Toast.success('database_delete_success_message'.tr);
        _loadDatabases();
      }
    } catch (e) {
      if (mounted) {
        Toast.error(
          'database_delete_failed_message'.trParams({'error': e.toString()}),
        );
      }
    }
  }

  Widget _buildImageWidget(String imageUrl, AppThemeData theme) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      // 网络图片
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('网络图片加载失败: $error');
          return _buildCoverPlaceholder(theme);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    } else {
      // 本地图片
      try {
        final file = File(imageUrl);
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('本地图片加载失败: $error\n路径: $imageUrl');
            return _buildCoverPlaceholder(theme);
          },
        );
      } catch (e) {
        debugPrint('创建File对象失败: $e\n路径: $imageUrl');
        return _buildCoverPlaceholder(theme);
      }
    }
  }

  /// 显示新建数据库对话框
  Future<void> _showAddDatabaseDialog(BuildContext context) async {
    // 创建一个空的新数据库模型（ID 为空，保存时才会生成）
    final now = DateTime.now();
    final newDatabase = DatabaseModel(
      id: '', // 新建时 ID 为空，在 DatabaseEditWidget 保存时生成
      name: '',
      fields: [],
      createdAt: now,
      updatedAt: now,
    );

    await _showDatabaseEditor(context, newDatabase);
  }

  /// 数据库新建/编辑：全页展示（design.md §5 平台路由转场）
  Future<void> _showDatabaseEditor(
    BuildContext context,
    DatabaseModel database,
  ) async {
    final result = await NavigationHelper.pushAnimated<bool>(
      context,
      DatabaseEditWidget(
        controller: DatabaseController(widget.service),
        database: database,
      ),
      routeName: '/database_edit',
    );

    if (result == true && mounted) {
      _loadDatabases();
    }
  }
}
