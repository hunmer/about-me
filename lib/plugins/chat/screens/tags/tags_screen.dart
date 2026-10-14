import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/tag.dart';
import 'package:aboutme/plugins/chat/screens/tags/widgets/tag_card.dart';
import 'package:aboutme/plugins/chat/screens/tags/tag_messages_screen.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_builders.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';

/// 排序类型枚举
enum SortType {
  byMessageCount, // 按消息数量排序
  byLastUsed, // 按最后使用时间排序
}

/// 标签列表页面
/// 显示所有从消息中提取的标签，支持搜索和排序
class TagsScreen extends StatefulWidget {
  final ChatPlugin chatPlugin;

  const TagsScreen({super.key, required this.chatPlugin});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  List<MessageTag> _tags = [];
  String _searchQuery = '';
  SortType _sortType = SortType.byMessageCount; // 默认按消息数量排序
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  /// 加载标签数据
  Future<void> _loadTags() async {
    setState(() => _isLoading = true);
    try {
      // 清除缓存，确保获取最新的标签数据
      widget.chatPlugin.tagService.invalidateCache();
      final tags = await widget.chatPlugin.tagService.getAllTags();
      if (mounted) {
        setState(() {
          _tags = tags;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error loading tags: $e');
    }
  }

  /// 获取过滤和排序后的标签列表
  List<MessageTag> get _filteredTags {
    var filtered =
        _tags.where((tag) {
          return tag.name.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

    // 应用排序
    if (_sortType == SortType.byMessageCount) {
      filtered.sort((a, b) => b.messageCount.compareTo(a.messageCount));
    } else {
      filtered.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    }

    return filtered;
  }

  /// 打开标签消息列表页面
  void _openTagMessages(MessageTag tag) async {
    final messages = await widget.chatPlugin.tagService.getMessagesByTag(
      tag.name,
    );
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => TagMessagesScreen(
              tagName: tag.name,
              messages: messages,
              chatPlugin: widget.chatPlugin,
            ),
      ),
    );
  }

  /// 排序选项（值 -> 标签）
  Map<String, String> get _sortOptions => {
    'count': 'chat_sortByCount'.tr,
    'time': 'chat_sortByTime'.tr,
  };

  /// 构建标签网格
  Widget _buildTagsGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      padding: EdgeInsets.fromLTRB(
        16, 8, 16, 8 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: _filteredTags.length,
      itemBuilder: (context, index) {
        // 挂载即播墨线描画入场（design.md §10）
        return WiredDraw(
          child: TagCard(
            tag: _filteredTags[index],
            onTap: () => _openTagMessages(_filteredTags[index]),
          ),
        );
      },
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    final message =
        _searchQuery.isEmpty ? 'chat_noTagsFound'.tr : 'chat_noMatchingTags'.tr;

    return Center(
      child: DSEmptyState(
        svgAsset: 'assets/icons/svg/tag.svg',
        title: message,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: SuperCupertinoNavigationWrapper(
        title: Text('chat_tagsTab'.tr),
        largeTitle: 'chat_tagsTab'.tr,
        enableSearchBar: true,
        searchPlaceholder: 'chat_searchTags'.tr,
        onSearchChanged: (query) {
          setState(() => _searchQuery = query);
        },
        onSearchSubmitted: (query) {
          setState(() => _searchQuery = query);
        },

        multiFilterItems: [
          FilterItem(
            id: 'sort',
            title: 'chat_sort'.tr,
            type: FilterType.custom,
            initialValue: 'count',
            builder:
                (context, value, onChanged) => FilterBuilders.buildSortFilter(
                  context: context,
                  currentValue: value,
                  onChanged: onChanged,
                  options: _sortOptions,
                ),
            getBadge: (value) => FilterBuilders.sortBadge(
              value,
              _sortOptions,
            ),
          ),
        ],
        onMultiFilterChanged: (filters) {
          setState(() {
            _sortType = filters['sort'] == 'time'
                ? SortType.byLastUsed
                : SortType.byMessageCount;
          });
        },

        body:
            _isLoading
                ? const Center(child: DSLoadingDots())
                : _filteredTags.isEmpty
                ? _buildEmptyState()
                : _buildTagsGrid(),
      ),
    );
  }
}
