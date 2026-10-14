import 'dart:io';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import '../webview_plugin.dart';
import '../models/webview_card.dart';
import '../services/card_manager.dart';
import 'components/webview_card_item.dart';
import 'webview_browser_screen.dart';
import 'proxy_settings_screen.dart';
import '../../../core/navigation/navigation_helper.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';

/// WebView 已安装页签 - 网址卡片列表
class WebViewCardsScreen extends StatefulWidget {
  const WebViewCardsScreen({super.key});

  @override
  State<WebViewCardsScreen> createState() => _WebViewCardsScreenState();
}

/// 排序类型枚举
enum SortType { openTime, addTime }

class _WebViewCardsScreenState extends State<WebViewCardsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  CardType? _filterType;
  SortType _sortType = SortType.openTime;
  final Map<String, bool> _searchFilters = {'url': true, 'title': true};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 获取多条件过滤配置
  List<FilterItem> get _multiFilterItems => [
    // 卡片类型过滤
    FilterItem(
      id: 'cardType',
      title: 'webview_card_type'.tr,
      type: FilterType.tagsSingle,
      initialValue: _filterType?.name,
      // 第三方过滤面板经 Overlay 展示,DS 组件需包主题桥
      builder: (context, value, onChanged) {
        return DSThemeBridge(
          child: Builder(
            builder:
                (context) => DSChipBar(
                  labels: [
                    'webview_all_cards'.tr,
                    'webview_online_urls'.tr,
                    'webview_local_files'.tr,
                  ],
                  selected: value == CardType.url.name
                      ? 1
                      : value == CardType.localFile.name
                      ? 2
                      : 0,
                  onChanged: (index) => onChanged(
                    index == 1
                        ? CardType.url.name
                        : index == 2
                        ? CardType.localFile.name
                        : null,
                  ),
                ),
          ),
        );
      },
      getBadge: (value) {
        if (value == null) return null;
        if (value == CardType.url.name) {
          return 'webview_online_urls'.tr;
        }
        if (value == CardType.localFile.name) {
          return 'webview_local_files'.tr;
        }
        return null;
      },
    ),
    // 排序过滤
    FilterItem(
      id: 'sortType',
      title: 'webview_sort'.tr,
      type: FilterType.tagsSingle,
      initialValue: _sortType.name,
      // 第三方过滤面板经 Overlay 展示,DS 组件需包主题桥
      builder: (context, value, onChanged) {
        return DSThemeBridge(
          child: Builder(
            builder: (context) => DSChipBar(
              labels: [
                'webview_sort_by_open_time'.tr,
                'webview_sort_by_add_time'.tr,
              ],
              selected: value == SortType.addTime.name ? 1 : 0,
              onChanged: onChanged,
            ),
          ),
        );
      },
      getBadge: (value) {
        if (value == SortType.openTime.name) {
          return 'webview_sort_by_open_time'.tr;
        }
        if (value == SortType.addTime.name) {
          return 'webview_sort_by_add_time'.tr;
        }
        return null;
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: SuperCupertinoNavigationWrapper(
        title: Text('webview_name'.tr),
        largeTitle: 'webview_name'.tr,
        enableLargeTitle: true,
        enableSearchBar: true,
        searchPlaceholder: 'webview_search_placeholder'.tr,
        enableSearchFilter: true,
        filterLabels: {
          'url': 'webview_search_url'.tr,
          'title': 'webview_search_title'.tr,
        },
        onSearchFilterChanged: (filters) {
          setState(() {
            _searchFilters.addAll(filters);
          });
        },
        enableMultiFilter: true,
        multiFilterItems: _multiFilterItems,
        onSearchChanged: (query) {
          setState(() {
            _searchQuery = query;
          });
        },
        onSearchSubmitted: (value) {
          // 如果输入的是有效 URL，直接打开
          if (_isValidUrl(value)) {
            _openUrl(value);
          }
        },
        onMultiFilterChanged: (filters) {
          setState(() {
            // 更新卡片类型过滤
            if (filters.containsKey('cardType')) {
              final cardTypeStr = filters['cardType'] as String?;
              _filterType = cardTypeStr != null
                  ? CardType.values.firstWhere((e) => e.name == cardTypeStr)
                  : null;
            }
            // 更新排序类型
            if (filters.containsKey('sortType')) {
              final sortTypeStr = filters['sortType'] as String?;
              _sortType = sortTypeStr != null
                  ? SortType.values.firstWhere((e) => e.name == sortTypeStr)
                  : SortType.openTime;
            }
          });
        },
        actions: [
          // 代理设置按钮(第三方导航栏回调,DS 组件需包主题桥)
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.gear,
                  size: 40,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  tooltip: 'webview_proxy_settings'.tr,
                  onPressed: () {
                    NavigationHelper.push(context, const ProxySettingsScreen());
                  },
                );
              },
            ),
          ),
        ],
        body: _buildCardList(),
      ),
    );
  }

  /// 构建卡片列表
  Widget _buildCardList() {
    return Consumer<CardManager>(
      builder: (context, cardManager, child) {
        final theme = DSThemeBridge.resolve(context);
        var cards = cardManager.cards;

        // 应用搜索过滤
        if (_searchQuery.isNotEmpty) {
          cards = cards.where((c) {
            final queryLower = _searchQuery.toLowerCase();
            bool matches = false;

            // 根据搜索过滤器决定搜索范围
            if (_searchFilters['url'] == true) {
              matches = matches || c.url.toLowerCase().contains(queryLower);
            }
            if (_searchFilters['title'] == true) {
              matches =
                  matches ||
                  c.title.toLowerCase().contains(queryLower) ||
                  (c.description?.toLowerCase().contains(queryLower) ?? false);
            }

            return matches;
          }).toList();
        }

        // 应用类型过滤
        if (_filterType != null) {
          cards = cards.where((c) => c.type == _filterType).toList();
        }

        // 应用排序
        cards = _sortCards(cards);

        if (cards.isEmpty) {
          return Center(
            child: DSEmptyState(emoji: '🌐', title: 'webview_no_cards'.tr),
          );
        }

        // 分组显示：固定的卡片在前
        final pinnedCards = cards.where((c) => c.isPinned).toList();
        final unpinnedCards = cards.where((c) => !c.isPinned).toList();

        return ListView(
          // 宿主页 extendBody：底部留出弧形导航高度（Scaffold 注入的
          // MediaQuery.padding.bottom）+ 视觉缓冲
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ).copyWith(bottom: MediaQuery.paddingOf(context).bottom + 16),
          children: [
            // 固定的卡片
            if (pinnedCards.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'webview_pinned'.tr,
                  style: DsTypography.heading.copyWith(color: theme.textSub),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // 顶部 16：容纳便签贴条出血，避免首行贴条被视口裁剪
                padding: const EdgeInsets.only(top: 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 12,
                  // ≥16：避免贴条出血被上一行遮挡
                  mainAxisSpacing: 16,
                ),
                itemCount: pinnedCards.length,
                itemBuilder: (context, index) {
                  return HandDrawnStickyItem(
                    tiltKey: pinnedCards[index].id,
                    child: WebViewCardItem(
                      card: pinnedCards[index],
                      onTap: () => _openCard(pinnedCards[index]),
                      onLongPress: () => _showCardOptions(pinnedCards[index]),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // 普通卡片
            if (unpinnedCards.isNotEmpty) ...[
              if (pinnedCards.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'webview_all_cards'.tr,
                    style: DsTypography.heading.copyWith(color: theme.textSub),
                  ),
                ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // 顶部 16：容纳便签贴条出血，避免首行贴条被视口裁剪
                padding: const EdgeInsets.only(top: 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 12,
                  // ≥16：避免贴条出血被上一行遮挡
                  mainAxisSpacing: 16,
                ),
                itemCount: unpinnedCards.length,
                itemBuilder: (context, index) {
                  return HandDrawnStickyItem(
                    tiltKey: unpinnedCards[index].id,
                    child: WebViewCardItem(
                      card: unpinnedCards[index],
                      onTap: () => _openCard(unpinnedCards[index]),
                      onLongPress: () => _showCardOptions(unpinnedCards[index]),
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }

  /// 对卡片进行排序
  List<WebViewCard> _sortCards(List<WebViewCard> cards) {
    final sortedCards = List<WebViewCard>.from(cards);
    if (_sortType == SortType.openTime) {
      // 按最近打开时间排序（打开次数多的在前）
      sortedCards.sort((a, b) => b.openCount.compareTo(a.openCount));
    } else {
      // 按最近添加时间排序（这里假设 id 是基于时间的 UUID）
      // 实际项目中，你可能需要在 WebViewCard 模型中添加 createdAt 字段
      // 目前使用 id 字符串比较作为近似
      sortedCards.sort((a, b) => b.id.compareTo(a.id));
    }
    return sortedCards;
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 5;
    if (width > 900) return 4;
    if (width > 600) return 3;
    return 2;
  }

  bool _isValidUrl(String text) {
    try {
      final uri = Uri.parse(text);
      return uri.scheme == 'http' || uri.scheme == 'https';
    } catch (_) {
      return false;
    }
  }

  /// 将文件路径转换为正确的 URL 格式
  /// 优先使用 HTTP URL（Windows），否则使用 file:// URL
  String _formatFileUrl(String filePath) {
    // 使用插件的 filePathToUrl 方法
    return WebViewPlugin.instance.filePathToUrl(filePath);
  }

  void _openUrl(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WebViewBrowserScreen(initialUrl: url),
      ),
    );
  }

  void _openCard(WebViewCard card) async {
    // 增加打开次数
    WebViewPlugin.instance.cardManager.incrementOpenCount(card.id);

    final tabManager = WebViewPlugin.instance.tabManager;

    // 检查是否已经有该卡片的标签页
    final existingTab = tabManager.findTabByCardId(card.id);

    if (existingTab != null) {
      // 已存在，切换到该标签页
      await tabManager.switchToTab(existingTab.id);

      // 导航到浏览器界面
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const WebViewBrowserScreen()),
      );
    } else {
      // 不存在，创建新标签页并导航
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => WebViewBrowserScreen(
            initialUrl: card.url,
            initialTitle: card.title,
            cardId: card.id,
          ),
        ),
      );
    }
  }

  void _showCardOptions(WebViewCard card) {
    SmoothBottomSheet.show(
      context: context,
      backgroundColor: DSThemeBridge.resolve(context).surface,
      builder: (context) => DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetActionRow(
                  // DS 暂无"新窗口打开"图标,保留 Material
                  icon: Icon(Icons.open_in_new, size: 20, color: theme.primary),
                  label: 'webview_new_tab'.tr,
                  theme: theme,
                  onTap: () {
                    Navigator.pop(context);
                    _openCard(card);
                  },
                ),
                _SheetActionRow(
                  icon: DsIcon(DsIconKind.pin, size: 20, color: theme.primary),
                  label: card.isPinned ? 'webview_unpin'.tr : 'webview_pin'.tr,
                  theme: theme,
                  onTap: () {
                    Navigator.pop(context);
                    WebViewPlugin.instance.cardManager.togglePinned(card.id);
                  },
                ),
                _SheetActionRow(
                  icon: DsIcon(DsIconKind.copy, size: 20, color: theme.primary),
                  label: 'webview_copy_url'.tr,
                  theme: theme,
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: card.url));
                    Toast.success('webview_url_copied'.tr);
                  },
                ),
                // 同步复制（仅本地文件且有原始路径）
                if (card.type == CardType.localFile && card.sourcePath != null)
                  _SheetActionRow(
                    icon: DsIcon(
                      DsIconKind.refresh,
                      size: 20,
                      color: theme.primary,
                    ),
                    label: '同步复制',
                    subtitle: '从原始路径重新复制文件',
                    theme: theme,
                    onTap: () {
                      Navigator.pop(context);
                      _syncCopyCard(card);
                    },
                  ),
                _SheetActionRow(
                  icon: DsIcon(DsIconKind.edit, size: 20, color: theme.primary),
                  label: 'webview_edit_card'.tr,
                  theme: theme,
                  onTap: () {
                    Navigator.pop(context);
                    _showEditCardDialog(card);
                  },
                ),
                _SheetActionRow(
                  icon: DsIcon(DsIconKind.trash, size: 20, color: theme.danger),
                  label: 'webview_delete_card'.tr,
                  theme: theme,
                  danger: true,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteCard(card);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showEditCardDialog(WebViewCard card) {
    final titleController = TextEditingController(text: card.title);
    final urlController = TextEditingController(text: card.url);
    final descController = TextEditingController(text: card.description ?? '');

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return JellyBox(
              radius: theme.radii.xxl,
              padding: EdgeInsets.all(theme.spacing.xl),
              constraints: const BoxConstraints(maxWidth: 380),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'webview_edit_card'.tr,
                      textAlign: TextAlign.center,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                    SizedBox(height: theme.spacing.lg),
                    DSInput(
                      controller: titleController,
                      label: 'webview_card_title'.tr,
                    ),
                    SizedBox(height: theme.spacing.md),
                    DSInput(
                      controller: urlController,
                      label: 'webview_card_url'.tr,
                      suffix: buildFolderPickerSuffix(() async {
                        // 选择本地文件
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.any,
                          allowMultiple: false,
                        );

                        if (result != null &&
                            result.files.single.path != null) {
                          final filePath = result.files.single.path!;
                          // 将文件路径转换为正确的 file:// URL
                          final fileUrl = _formatFileUrl(filePath);
                          urlController.text = fileUrl;

                          // 如果标题为空，使用文件名作为标题
                          if (titleController.text.isEmpty) {
                            final fileName = result.files.single.name;
                            titleController.text = fileName;
                          }
                        }
                      }),
                    ),
                    SizedBox(height: theme.spacing.md),
                    DSInput(
                      controller: descController,
                      label: 'webview_card_description'.tr,
                      maxLines: 2,
                    ),
                    SizedBox(height: theme.spacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: DSButton(
                            label: 'app_cancel'.tr,
                            variant: DSButtonVariant.outline,
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ),
                        SizedBox(width: theme.spacing.md),
                        Expanded(
                          child: DSButton(
                            label: 'app_save'.tr,
                            onPressed: () async {
                              if (titleController.text.isNotEmpty &&
                                  urlController.text.isNotEmpty) {
                                final updatedCard = card.copyWith(
                                  title: titleController.text,
                                  url: urlController.text,
                                  description: descController.text.isNotEmpty
                                      ? descController.text
                                      : null,
                                );
                                await WebViewPlugin.instance.cardManager
                                    .updateCard(updatedCard);
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 同步复制卡片（从原始路径重新复制）
  Future<void> _syncCopyCard(WebViewCard card) async {
    if (card.sourcePath == null) {
      Toast.error('错误：未保存原始路径');
      return;
    }

    // 检查原始路径是否存在
    final sourceDir = Directory(card.sourcePath!);
    if (!await sourceDir.exists()) {
      Toast.error('错误：原始路径不存在\n${card.sourcePath}');
      return;
    }

    // 检查是否存在 index.html
    final indexHtmlPath = path.join(card.sourcePath!, 'index.html');
    final indexHtmlFile = File(indexHtmlPath);
    if (!await indexHtmlFile.exists()) {
      Toast.error('错误：原始目录中未找到 index.html');
      return;
    }

    // 显示加载提示
    if (!mounted) return;
    Toast.info('正在同步复制...');

    try {
      // 从卡片 URL 中提取项目名称
      // 例如：./projectName/index.html -> projectName
      final uri = Uri.parse(card.url);
      final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

      if (pathSegments.isEmpty) {
        throw Exception('无法从 URL 中提取项目名称');
      }

      final projectName = pathSegments.first;

      // 重新复制文件到 HTTP 服务器目录
      await WebViewPlugin.instance.copyToHttpServer(
        sourcePath: card.sourcePath!,
        projectName: projectName,
      );

      Toast.success('同步成功！文件已更新');
    } catch (e) {
      Toast.error('同步失败: $e');
    }
  }

  void _confirmDeleteCard(WebViewCard card) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => DSThemeBridge(
        child: Builder(
          builder: (context) => DSDialog(
            title: 'webview_delete_card'.tr,
            message: 'webview_confirm_delete'.tr,
            confirmText: 'app_delete'.tr,
            cancelText: 'app_cancel'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () async {
              await WebViewPlugin.instance.cardManager.deleteCard(card.id);
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }
}

/// 卡片长按菜单行(果冻风格操作行)
class _SheetActionRow extends StatelessWidget {
  const _SheetActionRow({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final Widget icon;
  final String label;
  final String? subtitle;
  final AppThemeData theme;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? theme.danger : theme.primary;
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Pressable(
        onPressed: onTap,
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return JellyBox(
            radius: theme.radii.lg,
            raised: false,
            color: pressed ? accent.mixWhite(0.9) : theme.surfaceAlt,
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.md,
            ),
            child: Row(
              children: [
                icon,
                SizedBox(width: theme.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: DsTypography.body.copyWith(
                          color: danger ? theme.danger : theme.text,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==================== 添加卡片对话框（宿主页底部导航圆钮调用） ====================

/// 弹出添加卡片对话框（在线 URL / 本地项目目录复制）
void showAddCardDialog(BuildContext context) {
  final titleController = TextEditingController();
  final urlController = TextEditingController();
  final descController = TextEditingController();
  final projectNameController = TextEditingController();
  CardType selectedType = CardType.url;
  bool isLocalFileMode = false;

  showDSDialog(
    context: context,
    theme: DSThemeBridge.resolve(context),
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return JellyBox(
              radius: theme.radii.xxl,
              padding: EdgeInsets.all(theme.spacing.xl),
              constraints: const BoxConstraints(maxWidth: 380),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'webview_add_card'.tr,
                      textAlign: TextAlign.center,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                    SizedBox(height: theme.spacing.lg),
                    DSInput(
                      controller: titleController,
                      label: 'webview_card_title'.tr,
                    ),
                    SizedBox(height: theme.spacing.md),

                    // 项目名称输入（本地文件模式）
                    if (isLocalFileMode) ...[
                      DSInput(
                        controller: projectNameController,
                        label: '项目名称（英文/数字/下划线）',
                      ),
                      SizedBox(height: theme.spacing.xs),
                      Text(
                        '文件将复制到 http_server/项目名称/ 目录',
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                      SizedBox(height: theme.spacing.md),
                    ],

                    DSInput(
                      controller: urlController,
                      label: 'webview_card_url'.tr,
                      // 本地文件模式下 URL 自动生成,只读展示
                      enabled: !isLocalFileMode,
                      suffix: buildFolderPickerSuffix(() async {
                        String? directoryPath;
                        List<String>? filesToCopy;

                        // macOS 使用目录选择，其他平台使用多文件选择
                        if (Theme.of(context).platform ==
                            TargetPlatform.macOS) {
                          // macOS: 使用目录选择
                          directoryPath = await FilePicker.platform
                              .getDirectoryPath(
                                dialogTitle: '选择项目目录（需包含 index.html）',
                              );
                        } else {
                          // Android/其他: 使用多文件选择
                          final result = await FilePicker.platform.pickFiles(
                            dialogTitle: '选择项目中的所有文件（包括 index.html）',
                            allowMultiple: true,
                            type: FileType.any,
                            withData: false,
                            withReadStream: false,
                          );

                          if (result == null || result.files.isEmpty) {
                            return;
                          }

                          // 找到包含 index.html 的目录
                          String? indexHtmlPath;
                          for (final file in result.files) {
                            if (file.path != null &&
                                file.name == 'index.html') {
                              indexHtmlPath = file.path;
                              break;
                            }
                          }

                          if (indexHtmlPath == null) {
                            Toast.error('错误：所选文件中未找到 index.html');
                            return;
                          }

                          // 获取目录路径和文件列表
                          directoryPath = path.dirname(indexHtmlPath);
                          filesToCopy = result.files
                              .where((f) => f.path != null)
                              .map((f) => f.path!)
                              .toList();
                        }

                        if (directoryPath == null) {
                          return;
                        }

                        // 检查目录中是否存在 index.html
                        final indexHtmlFile = File(
                          path.join(directoryPath, 'index.html'),
                        );
                        if (!await indexHtmlFile.exists()) {
                          Toast.error('错误：所选目录中未找到 index.html');
                          return;
                        }

                        final directoryName = path.basename(directoryPath);

                        // 将选中的文件列表保存到 WebViewPlugin 中以备后用
                        if (filesToCopy != null) {
                          WebViewPlugin.instance.pendingFilesToCopy =
                              filesToCopy;
                        } else {
                          // macOS: 扫描目录下所有文件
                          final dir = Directory(directoryPath);
                          WebViewPlugin.instance.pendingFilesToCopy = (await dir
                              .list(recursive: true)
                              .where((entity) => entity is File)
                              .map((entity) => entity.path)
                              .toList());
                        }

                        setDialogState(() {
                          isLocalFileMode = true;
                          selectedType = CardType.localFile;
                        });

                        // 如果标题为空，使用目录名作为标题
                        if (titleController.text.isEmpty) {
                          titleController.text = directoryName;
                        }

                        // 如果项目名称为空，生成默认名称
                        if (projectNameController.text.isEmpty) {
                          final projectName = directoryName
                              .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
                              .replaceAll(RegExp(r'_+'), '_');
                          projectNameController.text = projectName;
                        }

                        // 存储目录路径
                        urlController.text = directoryPath;
                      }),
                    ),
                    if (isLocalFileMode) ...[
                      SizedBox(height: theme.spacing.xs),
                      Text(
                        'URL 将自动生成为 ./项目名称/...',
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ],
                    SizedBox(height: theme.spacing.md),
                    DSInput(
                      controller: descController,
                      label: 'webview_card_description'.tr,
                      maxLines: 2,
                    ),
                    SizedBox(height: theme.spacing.md),
                    DSSegmentedControl(
                      options: [
                        'webview_card_type_url'.tr,
                        'webview_card_type_local'.tr,
                      ],
                      selected: selectedType == CardType.url ? 0 : 1,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedType = value == 0
                              ? CardType.url
                              : CardType.localFile;
                          isLocalFileMode = selectedType == CardType.localFile;
                          if (!isLocalFileMode) {
                            projectNameController.clear();
                          }
                        });
                      },
                    ),
                    SizedBox(height: theme.spacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: DSButton(
                            label: 'app_cancel'.tr,
                            variant: DSButtonVariant.outline,
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ),
                        SizedBox(width: theme.spacing.md),
                        Expanded(
                          child: DSButton(
                            label: 'app_save'.tr,
                            onPressed: () async {
                              if (titleController.text.isEmpty) {
                                Toast.warning('请输入卡片标题');
                                return;
                              }

                              if (isLocalFileMode) {
                                // 本地文件模式：复制文件并生成 ./ 路径
                                if (projectNameController.text.isEmpty) {
                                  Toast.warning('请输入项目名称');
                                  return;
                                }

                                try {
                                  final sourcePath = urlController.text;
                                  final projectName =
                                      projectNameController.text;

                                  // 复制文件到 HTTP 服务器目录
                                  final relativePath = await WebViewPlugin
                                      .instance
                                      .copyToHttpServer(
                                        sourcePath: sourcePath,
                                        projectName: projectName,
                                      );

                                  // 添加卡片（使用 ./ 相对路径，同时保存原始路径）
                                  await WebViewPlugin.instance.cardManager
                                      .addCard(
                                        title: titleController.text,
                                        url: relativePath,
                                        type: selectedType,
                                        description:
                                            descController.text.isNotEmpty
                                            ? descController.text
                                            : null,
                                        sourcePath: sourcePath, // 保存原始路径用于同步
                                      );

                                  if (dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop();
                                    Toast.success('本地项目已添加');
                                  }
                                } catch (e) {
                                  Toast.error('添加失败: $e');
                                }
                              } else {
                                // 在线 URL 模式
                                if (urlController.text.isEmpty) {
                                  Toast.warning('请输入 URL');
                                  return;
                                }

                                await WebViewPlugin.instance.cardManager
                                    .addCard(
                                      title: titleController.text,
                                      url: urlController.text,
                                      type: selectedType,
                                      description:
                                          descController.text.isNotEmpty
                                          ? descController.text
                                          : null,
                                    );

                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

/// 本地文件/目录选择按钮(DS 暂无文件夹图标,保留 Material IconButton)
Widget buildFolderPickerSuffix(VoidCallback onPressed) {
  return Builder(
    builder: (context) {
      final theme = DSThemeBridge.resolve(context);
      return Material(
        type: MaterialType.transparency,
        child: IconButton(
          icon: Icon(Icons.folder_open, color: theme.primary),
          tooltip: 'webview_select_local_file'.tr,
          onPressed: onPressed,
        ),
      );
    },
  );
}
