import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/webview/screens/app_store/source_management_screen.dart';
import 'package:aboutme/plugins/webview/screens/app_store/app_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../models/app_store_models.dart';
import '../../services/app_store_manager.dart';
import '../../services/download_manager.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';

/// 小应用商场主界面
class AppStoreScreen extends StatefulWidget {
  const AppStoreScreen({super.key});

  @override
  State<AppStoreScreen> createState() => _AppStoreScreenState();
}

class _AppStoreScreenState extends State<AppStoreScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final manager = context.read<AppStoreManager>();
      if (!manager.isLoading && manager.apps.isEmpty) {
        manager.fetchApps();
      }
    });
  }

  final TextEditingController _searchController = TextEditingController();
  String _selectedTag = '';
  bool _showInstalledOnly = false;
  final Map<String, bool> _searchFilters = {
    'title': true,
    'desc': true,
    'author': true,
  };

  @override
  Widget build(BuildContext context) {
    final appStoreManager = context.watch<AppStoreManager>();
    final downloadManager = context.watch<DownloadManager>();

    return DSThemeBridge(
      child: SuperCupertinoNavigationWrapper(
        title: Text('webview_app_store'.tr),
        largeTitle: 'webview_app_store'.tr,
        // 内嵌于 WebViewMainScreen 宿主页（同一路由嵌套第二个 wrapper，
        // 必须关闭 hero 过渡，避免与卡片页签导航栏的 hero tag 冲突）
        transitionBetweenRoutes: false,
        enableLargeTitle: true,
        enableSearchBar: true,
        searchPlaceholder: 'core_search'.tr,
        onSearchChanged: (_) => setState(() {}),
        enableSearchFilter: true,
        filterLabels: {
          'title': 'webview_search_title'.tr,
          'desc': 'webview_search_desc'.tr,
          'author': 'webview_search_author'.tr,
        },
        onSearchFilterChanged: (filters) {
          setState(() {
            _searchFilters.addAll(filters);
          });
        },
        enableMultiFilter: true,
        multiFilterItems: _buildFilterItems(appStoreManager),
        onMultiFilterChanged: (filters) {
          setState(() {
            if (filters.containsKey('tag')) {
              _selectedTag = filters['tag'] as String? ?? '';
            }
            if (filters.containsKey('installed')) {
              _showInstalledOnly = filters['installed'] as bool? ?? false;
            }
          });
        },
        // SuperAppBar 的 actions 经 Overlay 渲染,脱离页面主题桥,
        // DS 按钮需自带 DSThemeBridge 提供 AppTheme
        actions: [
          // 源管理按钮
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.gear,
                  size: 36,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  tooltip: 'webview_manage_sources'.tr,
                  onPressed: () {
                    final appStoreManager = context.read<AppStoreManager>();
                    NavigationHelper.push(
                      context,
                      ChangeNotifierProvider.value(
                        value: appStoreManager,
                        child: const SourceManagementScreen(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
        body: Builder(
          builder: (context) {
            return Column(
              children: [
                // 应用列表
                Expanded(
                  child:
                      appStoreManager.isLoading
                          ? const Center(child: DSLoadingDots())
                          : appStoreManager.error != null
                          ? _buildErrorView(appStoreManager)
                          : _buildAppList(appStoreManager),
                ),

                // 安装进度条（宿主页 extendBody：避让弧形底部导航）
                if (downloadManager.isInstalling)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom,
                    ),
                    child: _buildInstallProgress(
                      downloadManager.currentTask!,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 构建多条件过滤配置
  List<FilterItem> _buildFilterItems(AppStoreManager manager) {
    final allTags = manager.getAllTags();

    return [
      // 分类过滤
      FilterItem(
        id: 'tag',
        title: 'webview_category'.tr,
        type: FilterType.tagsSingle,
        initialValue: _selectedTag,
        // 第三方过滤面板经 Overlay 展示,DS 组件需包主题桥
        builder: (context, value, onChanged) {
          return DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSChipBar(
                    labels: ['全部', ...allTags],
                    selected: (allTags.indexOf(value ?? '') + 1).clamp(
                      0,
                      allTags.length,
                    ),
                    onChanged: (index) =>
                        onChanged(index == 0 ? '' : allTags[index - 1]),
                  ),
            ),
          );
        },
        getBadge: (value) {
          if (value == null || value == '') return null;
          return value as String;
        },
      ),
      // 是否已安装过滤
      FilterItem(
        id: 'installed',
        title: 'webview_installed_only'.tr,
        type: FilterType.checkbox,
        initialValue: _showInstalledOnly,
        // 第三方过滤面板经 Overlay 展示,DS 组件需包主题桥
        builder: (context, value, onChanged) {
          return DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return Row(
                  children: [
                    DSCheckbox(
                      value: value as bool? ?? false,
                      onChanged: (newValue) => onChanged(newValue ?? false),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'webview_installed_only'.tr,
                      style: DsTypography.body.copyWith(color: theme.text),
                    ),
                  ],
                );
              },
            ),
          );
        },
        getBadge: (value) {
          if (value == true) return 'webview_installed_only'.tr;
          return null;
        },
      ),
    ];
  }

  /// 构建应用列表
  Widget _buildAppList(AppStoreManager appStoreManager) {
    final filteredApps = _filterApps(appStoreManager.apps);

    if (filteredApps.isEmpty) {
      return _buildEmptyView();
    }

    return MasonryGridView.count(
      // 宿主页 extendBody：底部留出弧形导航高度
      // 顶部 16：容纳便签贴条出血，避免首行贴条被视口裁剪
      padding: const EdgeInsets.all(8).copyWith(
        top: 16,
        bottom: MediaQuery.paddingOf(context).bottom + 8,
      ),
      crossAxisCount: 2,
      // ≥16：避免贴条出血被上一行遮挡
      mainAxisSpacing: 16,
      crossAxisSpacing: 8,
      itemCount: filteredApps.length,
      itemBuilder: (context, index) {
        return HandDrawnStickyItem(
          tiltKey: filteredApps[index].id,
          child: _buildAppCard(filteredApps[index]),
        );
      },
    );
  }

  /// 过滤应用列表
  List<MiniApp> _filterApps(List<MiniApp> apps) {
    final query = _searchController.text.toLowerCase();

    return apps.where((app) {
      // 搜索过滤
      if (query.isNotEmpty) {
        bool matches = false;

        if (_searchFilters['title'] == true) {
          matches = matches || app.title.toLowerCase().contains(query);
        }
        if (_searchFilters['desc'] == true && app.desc != null) {
          matches = matches || app.desc!.toLowerCase().contains(query);
        }
        if (_searchFilters['author'] == true && app.author != null) {
          matches = matches || app.author!.toLowerCase().contains(query);
        }

        if (!matches) return false;
      }

      // 分类过滤
      if (_selectedTag.isNotEmpty && !app.tags.contains(_selectedTag)) {
        return false;
      }

      // 已安装过滤
      if (_showInstalledOnly && !app.isInstalled) {
        return false;
      }

      return true;
    }).toList();
  }

  /// 应用卡片
  Widget _buildAppCard(MiniApp app) {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return DSCard(
          padding: const EdgeInsets.all(12.0),
          onTap: () => _showAppDetail(app),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：图标和版本信息
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧图标（小尺寸）
                  _buildAppIcon(app.icon, size: 48),
                  const Spacer(),
                  // 右侧版本信息
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (app.isInstalled) ...[
                            DsIcon(
                              DsIconKind.check,
                              size: 14,
                              color: theme.success,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            app.displayVersion,
                            style: DsTypography.caption.copyWith(
                              fontSize: 11,
                              color: theme.textSub,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (app.hasUpdate) ...[
                        const SizedBox(height: 4),
                        DSBadge(
                          label: 'webview_update'.tr,
                          color: theme.warning,
                          textColor: theme.onWarning,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 标题
              Text(
                app.title,
                style: DsTypography.body.copyWith(
                  color: theme.text,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // 描述
              Text(
                app.desc ?? '',
                style: DsTypography.caption.copyWith(color: theme.textSub),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // 标签（最多展示2个）
              if (app.tags.isNotEmpty)
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children:
                      app.tags.take(2).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.primary.mixWhite(0.9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: theme.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            tag,
                            style: DsTypography.label.copyWith(
                              fontSize: 10,
                              color: theme.primaryText,
                            ),
                          ),
                        );
                      }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 安装进度条
  Widget _buildInstallProgress(InstallTask task) {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        final isFailed = task.status == InstallTaskStatus.failed;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.surface,
            boxShadow: theme.shadows.soft,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isFailed
                          ? '${_getStatusText(task.status)} ${task.appName}'
                          : '${_getStatusText(task.status)} ${task.appName}...',
                      style: DsTypography.body.copyWith(
                        color: isFailed ? theme.danger : theme.text,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isFailed)
                    Text(
                      '${(task.progress * 100).toStringAsFixed(0)}%',
                      style: DsTypography.body.copyWith(color: theme.text),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              DSLinearProgress(
                value: task.progress,
                color: isFailed ? theme.danger : null,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isFailed
                          ? (task.error ?? '')
                          : '${task.completedFiles}/${task.totalFiles} files • ${_formatBytes(task.downloadedBytes)}/${_formatBytes(task.totalBytes)}',
                      style: DsTypography.caption.copyWith(
                        color: isFailed ? theme.danger : theme.textSub,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (task.status == InstallTaskStatus.downloading)
                    DSButton(
                      label: 'app_cancel'.tr,
                      variant: DSButtonVariant.ghost,
                      size: DSButtonSize.sm,
                      onPressed: () {
                        context.read<DownloadManager>().cancelInstall();
                      },
                    ),
                  if (isFailed)
                    DSButton(
                      label: 'app_close'.tr,
                      variant: DSButtonVariant.ghost,
                      size: DSButtonSize.sm,
                      onPressed: () {
                        context.read<DownloadManager>().dismissInstall();
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 错误视图
  Widget _buildErrorView(AppStoreManager manager) {
    return Center(
      child: DSEmptyState(
        emoji: '⚠️',
        title: manager.error!,
        actionLabel: 'app_retry'.tr,
        onAction: () => manager.fetchApps(),
      ),
    );
  }

  /// 空视图
  Widget _buildEmptyView() {
    return const Center(
      child: DSEmptyState(emoji: '🧩', title: 'No apps found'),
    );
  }

  /// 显示应用详情
  void _showAppDetail(MiniApp app) {
    final appStoreManager = context.read<AppStoreManager>();
    final downloadManager = context.read<DownloadManager>();

    SmoothBottomSheet.show(
      context: context,
      backgroundColor: DSThemeBridge.resolve(context).surface,
      builder:
          (sheetContext) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: appStoreManager),
                ChangeNotifierProvider.value(value: downloadManager),
              ],
              child: AppDetailSheet(app: app),
            ),
          ),
    );
  }

  /// 获取状态文本
  String _getStatusText(InstallTaskStatus status) {
    switch (status) {
      case InstallTaskStatus.downloading:
        return 'webview_downloading_files'.tr;
      case InstallTaskStatus.installing:
        return 'webview_installing'.tr;
      case InstallTaskStatus.completed:
        return 'Completed';
      case InstallTaskStatus.failed:
        return 'webview_install_failed'.tr;
    }
  }

  /// 格式化字节数
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 构建应用图标（支持网络图片、emoji文本、默认图标）
  Widget _buildAppIcon(String? icon, {double size = 48}) {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        // 判断是否为网络图片 URL
        final bool isNetworkImage =
            icon != null &&
            (icon.startsWith('http://') || icon.startsWith('https://'));

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isNetworkImage ? null : theme.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                isNetworkImage
                    ? Image.network(
                      icon,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: size,
                          height: size,
                          color: theme.surfaceAlt,
                          child: DsIcon(
                            DsIconKind.grid,
                            size: size / 2,
                            color: theme.textSub,
                          ),
                        );
                      },
                    )
                    : icon != null && icon.isNotEmpty
                    ? Center(
                      child: Text(
                        icon,
                        style: TextStyle(fontSize: size * 0.6),
                        textAlign: TextAlign.center,
                      ),
                    )
                    : DsIcon(
                      DsIconKind.grid,
                      size: size / 2,
                      color: theme.textSub,
                    ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
