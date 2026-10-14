import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/models/tag.dart';
import 'package:aboutme/plugins/chat/screens/tags/tag_messages_screen.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/stacked_folder_card.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_builders.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';

/// 排序类型枚举
enum SortType {
  byMessageCount, // 按消息数量排序
  byLastUsed, // 按最后使用时间排序
}

/// 标签列表页面
/// 以堆叠文件夹卡片展示所有从消息中提取的标签，
/// 正背面便签为该标签最新的两条消息，支持搜索和排序
class TagsScreen extends StatefulWidget {
  final ChatPlugin chatPlugin;

  const TagsScreen({super.key, required this.chatPlugin});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  List<MessageTag> _tags = [];
  Map<String, List<Message>> _tagPreviews = {};
  String _searchQuery = '';
  SortType _sortType = SortType.byMessageCount; // 默认按消息数量排序
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  /// 加载标签数据与每个标签的最新消息预览
  Future<void> _loadTags() async {
    setState(() => _isLoading = true);
    try {
      // 清除缓存，确保获取最新的标签数据
      widget.chatPlugin.tagService.invalidateCache();
      final tags = await widget.chatPlugin.tagService.getAllTags();

      // 按标签分组消息，用于卡片便签预览（最新在前）
      final messages = await widget.chatPlugin.messageService.getAllMessages();
      final previews = <String, List<Message>>{};
      for (final message in messages) {
        if (message.type == MessageType.sent ||
            message.type == MessageType.received) {
          for (final tagName in widget.chatPlugin.tagService
              .extractTagsFromContent(message.content)) {
            previews.putIfAbsent(tagName, () => []).add(message);
          }
        }
      }
      for (final list in previews.values) {
        list.sort((a, b) => b.date.compareTo(a.date));
      }

      if (mounted) {
        setState(() {
          _tags = tags;
          _tagPreviews = previews;
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

    NavigationHelper.push(
      context,
      TagMessagesScreen(
        tagName: tag.name,
        messages: messages,
        chatPlugin: widget.chatPlugin,
      ),
    );
  }

  /// 排序选项（值 -> 标签）
  Map<String, String> get _sortOptions => {
    'count': 'chat_sortByCount'.tr,
    'time': 'chat_sortByTime'.tr,
  };

  /// 消息转便签文本行：用户名一行 + 内容一行（截断）
  List<String> _noteLines(Message message) {
    final content = message.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    return [
      message.user.username,
      content.length > 42 ? '${content.substring(0, 42)}…' : content,
    ];
  }

  /// 构建标签卡片网格（堆叠文件夹卡片，一行两列）
  Widget _buildTagsGrid() {
    return GridView.builder(
      // 格子纵横比与卡片内部设计稿(320x410)一致，inline 卡片撑满格子，
      // FittedBox 完全贴合，内容展示最大化
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 320 / 410,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      padding: EdgeInsets.fromLTRB(
        16, 8, 16, 8 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: _filteredTags.length,
      itemBuilder: (context, index) {
        final tag = _filteredTags[index];
        final previews = (_tagPreviews[tag.name] ?? const <Message>[])
            .take(2)
            .toList();
        final fallbackLines = <String>['#${tag.name}'];

        return HandDrawnStickyItem(
          tiltKey: tag.name,
          showTape: false,
          child: StackedFolderCardWidget(
            key: ValueKey(tag.name),
            inline: true,
            title: '#${tag.name}',
            subtitle: 'chat_messageCount'.trParams({
              'count': tag.messageCount.toString(),
            }),
            variant: StackedFolderVariant.notes,
            size: const MediumSize(),
            // 正面便签：最新一条消息；背面便签：第二条消息
            noteFrontLines: previews.isNotEmpty
                ? _noteLines(previews.first)
                : fallbackLines,
            noteBackLines: previews.length > 1
                ? _noteLines(previews.last)
                : fallbackLines,
            onCardTap: () => _openTagMessages(tag),
            onOpen: () => _openTagMessages(tag),
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
