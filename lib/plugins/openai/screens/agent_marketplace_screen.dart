import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_builders.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/services/agent_marketplace_service.dart';
import 'package:aboutme/plugins/openai/widgets/marketplace_agent_grid_view.dart';
import 'package:aboutme/plugins/openai/widgets/marketplace_agent_list_view.dart';

/// Agent 商场页面
/// 从远程服务器获取并展示可安装的 Agent
class AgentMarketplaceScreen extends StatefulWidget {
  final String? marketplaceUrl;

  const AgentMarketplaceScreen({super.key, this.marketplaceUrl});

  @override
  State<AgentMarketplaceScreen> createState() => _AgentMarketplaceScreenState();
}

class _AgentMarketplaceScreenState extends State<AgentMarketplaceScreen> {
  final AgentMarketplaceService _marketplaceService = AgentMarketplaceService();
  final AgentController _agentController = AgentController();

  bool _isGridView = true;
  List<String> _allTags = [];
  List<String> _allProviders = [];

  // 搜索相关状态
  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _searchFilters = {
    'name': true,
    'description': true,
    'tags': true,
  };
  String _searchQuery = '';

  // MultiFilter 过滤值
  Map<String, dynamic> _multiFilterValues = {};

  // 商场数据
  List<AIAgent> _marketplaceAgents = [];
  List<AIAgent> _localAgents = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMarketplaceData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 加载商场数据
  Future<void> _loadMarketplaceData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 并行加载商场 Agent 和本地 Agent
      final results = await Future.wait([
        _marketplaceService.fetchMarketplaceAgents(url: widget.marketplaceUrl),
        _agentController.loadVisibleAgents(),
      ]);

      _marketplaceAgents = results[0];
      _localAgents = results[1];

      // 提取所有标签与服务商
      _allTags =
          _marketplaceAgents.expand((agent) => agent.tags).toSet().toList()
            ..sort();
      _allProviders =
          _marketplaceAgents
              .map((agent) => agent.serviceProviderId)
              .toSet()
              .toList()
            ..sort();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'openai_loadFailed'.trParams({'error': e.toString()});
      });
    }
  }

  /// 刷新本地 Agent 列表（安装后调用）
  Future<void> _refreshLocalAgents() async {
    try {
      _localAgents = await _agentController.loadVisibleAgents();
      setState(() {});
    } catch (e) {
      // 静默失败，不影响用户体验
    }
  }

  /// 处理搜索查询变化
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  /// 处理搜索过滤器变化
  void _onSearchFilterChanged(Map<String, bool> filters) {
    setState(() {
      _searchFilters.addAll(filters);
    });
  }

  /// 处理 MultiFilter 变化
  void _onMultiFilterChanged(Map<String, dynamic> filters) {
    setState(() {
      _multiFilterValues = filters;
    });
  }

  /// 构建 MultiFilter 过滤项
  List<FilterItem> _buildMultiFilterItems() {
    return [
      // 服务商筛选
      if (_allProviders.isNotEmpty)
        FilterItem(
          id: 'providers',
          title: 'openai_serviceProvider'.tr,
          type: FilterType.tagsMultiple,
          builder: (context, currentValue, onChanged) {
            return FilterBuilders.buildTagsFilter(
              context: context,
              currentValue: currentValue,
              onChanged: onChanged,
              availableTags: _allProviders,
            );
          },
          getBadge: FilterBuilders.tagsBadge,
          initialValue: <String>[],
        ),
      // 标签筛选
      if (_allTags.isNotEmpty)
        FilterItem(
          id: 'tags',
          title: 'openai_tags'.tr,
          type: FilterType.tagsMultiple,
          builder: (context, currentValue, onChanged) {
            return FilterBuilders.buildTagsFilter(
              context: context,
              currentValue: currentValue,
              onChanged: onChanged,
              availableTags: _allTags,
            );
          },
          getBadge: FilterBuilders.tagsBadge,
          initialValue: <String>[],
        ),
    ];
  }

  /// 获取过滤后的 Agent 列表
  List<AIAgent> _getFilteredAgents() {
    return _marketplaceAgents.where((agent) {
      // 服务商筛选 - 从 MultiFilter 获取
      final selectedProviders =
          _multiFilterValues['providers'] as List<String>? ?? [];
      bool providerMatch =
          selectedProviders.isEmpty ||
          selectedProviders.contains(agent.serviceProviderId);

      // 标签筛选 - 从 MultiFilter 获取
      final selectedTags = _multiFilterValues['tags'] as List<String>? ?? [];
      bool tagMatch =
          selectedTags.isEmpty ||
          agent.tags.any((tag) => selectedTags.contains(tag));

      // 搜索筛选
      bool searchMatch = true;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = agent.name.toLowerCase().contains(query);
        final descriptionMatch = agent.description.toLowerCase().contains(
          query,
        );
        final tagsMatch = agent.tags.any(
          (tag) => tag.toLowerCase().contains(query),
        );

        // 根据启用的搜索过滤器进行匹配
        final enabledFilters =
            _searchFilters.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList();

        final matches = <bool>[];
        if (enabledFilters.contains('name')) {
          matches.add(nameMatch);
        }
        if (enabledFilters.contains('description')) {
          matches.add(descriptionMatch);
        }
        if (enabledFilters.contains('tags')) {
          matches.add(tagsMatch);
        }

        // 如果有启用的过滤器，只要有一个匹配就算匹配
        searchMatch = matches.isEmpty ? true : matches.any((match) => match);
      }

      return providerMatch && tagMatch && searchMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: SuperCupertinoNavigationWrapper(
        title: Text('openai_marketplaceTitle'.tr),
        largeTitle: 'openai_marketplaceTitle'.tr,
        body: _buildBody(),
        enableLargeTitle: false,
        automaticallyImplyLeading: true,

        // 启用搜索栏
        enableSearchBar: true,
        searchPlaceholder: 'openai_searchAgent'.tr,
        onSearchChanged: _onSearchChanged,

        // 启用搜索过滤器
        enableSearchFilter: true,
        filterLabels: {
          'name': 'openai_agentName'.tr,
          'description': 'openai_description'.tr,
          'tags': 'openai_tags'.tr,
        },
        onSearchFilterChanged: _onSearchFilterChanged,

        // 启用 MultiFilter（服务商 + 标签统一走过滤栏）
        enableMultiFilter: true,
        multiFilterItems: _buildMultiFilterItems(),
        multiFilterBarHeight: 50,
        onMultiFilterChanged: _onMultiFilterChanged,

        // SuperAppBar 的 actions 经 Overlay 渲染,DS 按钮需自带 DSThemeBridge
        actions: [
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.refresh,
                  size: 36,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  onPressed: _loadMarketplaceData,
                  tooltip: 'openai_refresh'.tr,
                );
              },
            ),
          ),
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: _isGridView ? DsIconKind.list : DsIconKind.grid,
                  size: 36,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                  tooltip: 'openai_toggleView'.tr,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: DSLoadingDots());
    }

    if (_errorMessage != null) {
      return Center(
        child: DSEmptyState(
          emoji: '⚠️',
          title: _errorMessage!,
          actionLabel: 'openai_retry'.tr,
          onAction: _loadMarketplaceData,
        ),
      );
    }

    if (_marketplaceAgents.isEmpty) {
      return Center(
        child: DSEmptyState(
          emoji: '🏪',
          title: 'openai_marketplaceEmpty'.tr,
        ),
      );
    }

    return Expanded(
      child:
          _isGridView
              ? MarketplaceAgentGridView(
                marketplaceAgents: _getFilteredAgents(),
                localAgents: _localAgents,
                onAgentChanged: _refreshLocalAgents,
              )
              : MarketplaceAgentListView(
                marketplaceAgents: _getFilteredAgents(),
                localAgents: _localAgents,
                onAgentChanged: _refreshLocalAgents,
              ),
    );
  }
}
