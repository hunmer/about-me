import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';

import '../../../core/navigation/navigation_helper.dart';
import '../models/webview_card.dart';
import 'components/webview_card_actions.dart';
import 'components/webview_card_list.dart';
import 'components/webview_card_options_sheet.dart';
import 'proxy_settings_screen.dart';

/// WebView 已安装页签 - 网址卡片列表
///
/// 列表渲染见 [WebViewCardList]，长按菜单/编辑/删除/同步复制见
/// components 下对应文件
class WebViewCardsScreen extends StatefulWidget {
  const WebViewCardsScreen({super.key});

  @override
  State<WebViewCardsScreen> createState() => _WebViewCardsScreenState();
}

class _WebViewCardsScreenState extends State<WebViewCardsScreen> {
  String _searchQuery = '';
  CardType? _filterType;
  SortType _sortType = SortType.openTime;
  final Map<String, bool> _searchFilters = {'url': true, 'title': true};

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
          if (isValidUrl(value)) {
            openUrl(context, value);
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
        body: WebViewCardList(
          searchQuery: _searchQuery,
          searchFilters: _searchFilters,
          filterType: _filterType,
          sortType: _sortType,
          onCardTap: (card) => openCard(context, card),
          onCardLongPress: (card) => showCardOptionsSheet(context, card),
        ),
      ),
    );
  }
}
