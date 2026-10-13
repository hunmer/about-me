import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';
import 'package:aboutme/core/services/toast_service.dart';

import 'package:aboutme/plugins/contact/contact_plugin.dart';
import 'package:aboutme/plugins/contact/controllers/contact_controller.dart';
import 'package:aboutme/plugins/contact/models/contact_model.dart';
import 'package:aboutme/plugins/contact/models/filter_sort_config.dart';
import 'package:aboutme/plugins/contact/widgets/contact_form.dart';
import 'package:aboutme/plugins/contact/widgets/contact_list_tile.dart';

class ContactMainView extends StatefulWidget {
  const ContactMainView({super.key});

  @override
  State<ContactMainView> createState() => ContactMainViewState();
}

class ContactMainViewState extends State<ContactMainView> {
  late ContactPlugin _plugin;

  late ContactController _controller;

  List<Contact> _searchResults = [];
  String _currentSearchQuery = '';
  bool _isSearching = false;

  // 多条件过滤参数
  Map<String, dynamic> _multiFilters = {};
  List<String> _availableTags = [];

  // GlobalKey for OpenContainer animation
  final GlobalKey _addButtonKey = GlobalKey();

  // 字母分组列表滚动控制（索引条跳转）
  final ScrollController _listController = ScrollController();
  final Map<String, double> _letterOffsets = {};
  String? _activeIndexLetter;

  /// 持久化过滤配置是否已加载（加载完成后重建过滤栏回显初值）
  bool _filterConfigLoaded = false;

  static const double _headerHeight = 44;
  static const List<String> _indexLetters = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#',
  ];

  @override
  void initState() {
    super.initState();

    _plugin = PluginManager().getPlugin('contact') as ContactPlugin;

    _controller = _plugin.controller;

    // 订阅同步刷新事件
    EventManager.instance.subscribe('contact_refresh', _handleSyncRefresh);

    // 加载标签（用于多条件过滤）
    _loadAvailableTags();

    // 加载持久化过滤配置（回显到多条件过滤栏）
    _loadInitialFilters();
  }

  @override
  void dispose() {
    // 取消订阅，避免内存泄漏
    EventManager.instance.unsubscribe('contact_refresh', _handleSyncRefresh);
    _listController.dispose();
    super.dispose();
  }

  /// 处理同步刷新事件
  void _handleSyncRefresh(EventArgs args) {
    debugPrint('[ContactMainView] 收到同步刷新事件');
    if (mounted) {
      _loadAvailableTags();
    }
  }

  /// 加载持久化过滤配置并回显到过滤栏
  Future<void> _loadInitialFilters() async {
    final config = await _controller.getFilterConfig();
    if (!mounted) return;

    setState(() {
      _multiFilters = {
        if (config.nameKeyword != null && config.nameKeyword!.isNotEmpty)
          'keyword': config.nameKeyword,
        if (config.startDate != null && config.endDate != null)
          'createdRange': DateTimeRange(
            start: config.startDate!,
            end: config.endDate!,
          ),
        if (config.uncontactedDays != null)
          'uncontacted': config.uncontactedDays.toString(),
        if (config.selectedTags.isNotEmpty) 'tag': config.selectedTags,
      };
      _filterConfigLoaded = true;
    });
  }

  /// 搜索联系人（按姓名和备注搜索）
  Future<void> _searchContacts(String query) async {
    _currentSearchQuery = query;

    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final allContacts = await _controller.getAllContacts();
      final normalizedQuery = query.toLowerCase();

      final results =
          allContacts.where((contact) {
            // 搜索姓名
            final nameMatch = contact.name.toLowerCase().contains(
              normalizedQuery,
            );

            // 搜索备注
            final notesMatch =
                contact.notes != null &&
                contact.notes!.toLowerCase().contains(normalizedQuery);

            // 搜索电话（精确匹配和模糊匹配）
            final phoneMatch = contact.phone.contains(query);

            // 搜索组织/公司
            final orgMatch =
                contact.organization != null &&
                contact.organization!.toLowerCase().contains(normalizedQuery);

            // 搜索邮箱
            final emailMatch =
                contact.email != null &&
                contact.email!.toLowerCase().contains(normalizedQuery);

            // 搜索地址
            final addressMatch =
                contact.address != null &&
                contact.address!.toLowerCase().contains(normalizedQuery);

            // 搜索标签
            final tagsMatch = contact.tags.any(
              (tag) => tag.toLowerCase().contains(normalizedQuery),
            );

            return nameMatch ||
                notesMatch ||
                phoneMatch ||
                orgMatch ||
                emailMatch ||
                addressMatch ||
                tagsMatch;
          }).toList();

      if (mounted && _currentSearchQuery == query) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  /// 构建搜索结果列表
  Widget _buildSearchResults() {
    final theme = DSThemeBridge.resolve(context);

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentSearchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DsIcon(
              DsIconKind.search,
              size: 64,
              color: theme.textSub.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'contact_searchHintEmpty'.tr,
              style: DsTypography.title.copyWith(color: theme.textSub),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DsIcon(
              DsIconKind.search,
              size: 64,
              color: theme.textSub.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'contact_searchNoResults'.tr,
              style: DsTypography.title.copyWith(color: theme.textSub),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final contact = _searchResults[index];
        return ContactListTile(
          key: ValueKey(contact.id),
          contact: contact,
          seed: index,
          onTap: () => _addOrEditContact(contact),
          onLongPress: () => _showItemActions(contact),
          onToggleFavorite: () => _toggleFavorite(contact),
        );
      },
    );
  }

  Future<void> _addOrEditContact([Contact? contact]) async {
    await NavigationHelper.push(
      context,
      ContactForm(
        contact: contact,
        onSave: (savedContact) async {
          try {
            if (contact == null) {
              await _controller.addContact(savedContact);
            } else {
              await _controller.updateContact(savedContact);
            }
            if (mounted) {
              setState(() {});
              _loadAvailableTags();
            }
          } catch (e) {
            ToastService.instance.showToast('contact_saveFailedMessage'.tr);
          }
        },
        onDelete: () async {
          // 删除联系人，导航由 ContactForm 处理
          if (contact != null) {
            await _controller.deleteContact(contact.id);
            _loadAvailableTags();
          }
        },
      ),
    );
  }

  /// 加载所有标签（用于多条件过滤）
  Future<void> _loadAvailableTags() async {
    final tags = await _controller.getAllTags();
    tags.sort();
    if (mounted) {
      setState(() {
        _availableTags = tags;
      });
    }
  }

  /// 构建多条件过滤项：关键词 / 创建日期范围 / 未联系天数 / 标签
  List<FilterItem> _buildFilterItems() {
    final dayOptions = {
      '7': '7 ${'contact_days'.tr}',
      '30': '30 ${'contact_days'.tr}',
      '90': '90 ${'contact_days'.tr}',
    };

    return [
      FilterItem(
        id: 'keyword',
        title: 'contact_nameKeyword'.tr,
        type: FilterType.input,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildKeywordFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
            placeholder: 'contact_nameKeyword'.tr,
          );
        },
        getBadge: FilterBuilders.keywordBadge,
        initialValue: _multiFilters['keyword'],
      ),
      FilterItem(
        id: 'createdRange',
        title: 'contact_dateRange'.tr,
        type: FilterType.dateRange,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildDateRangeFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
          );
        },
        getBadge: FilterBuilders.dateRangeBadge,
        initialValue: _multiFilters['createdRange'],
      ),
      FilterItem(
        id: 'uncontacted',
        title: 'contact_uncontactedDays'.tr,
        type: FilterType.tagsSingle,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildSingleChoiceFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
            options: dayOptions,
            allItemsKey: 'all',
            allItemsLabel: 'contact_noLimit'.tr,
          );
        },
        getBadge: (value) =>
            FilterBuilders.singleChoiceBadge(value, dayOptions),
        initialValue: _multiFilters['uncontacted'],
      ),
      if (_availableTags.isNotEmpty)
        FilterItem(
          id: 'tag',
          title: 'contact_tags'.tr,
          type: FilterType.tagsMultiple,
          builder: (context, currentValue, onChanged) {
            return FilterBuilders.buildTagsFilter(
              context: context,
              currentValue: currentValue,
              onChanged: onChanged,
              availableTags: _availableTags,
            );
          },
          getBadge: FilterBuilders.tagsBadge,
          initialValue:
              (_multiFilters['tag'] as List<String>?)?.toList(),
        ),
    ];
  }

  /// 应用多条件过滤：先持久化为 FilterConfig，再刷新列表
  void _applyMultiFilters(Map<String, dynamic> filters) {
    // 使用 addPostFrameCallback 避免在 build 阶段调用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _persistFilterConfig(filters);
      if (mounted) {
        setState(() {
          _multiFilters = filters;
        });
      }
    });
  }

  /// 把过滤栏的值映射为 FilterConfig 并持久化
  Future<void> _persistFilterConfig(Map<String, dynamic> filters) async {
    final keyword = filters['keyword'] as String?;
    final range = filters['createdRange'] as DateTimeRange?;
    final days = filters['uncontacted'] as String?;
    final tags = (filters['tag'] as List<String>?) ?? const <String>[];

    await _controller.saveFilterConfig(
      FilterConfig(
        nameKeyword: (keyword == null || keyword.isEmpty) ? null : keyword,
        startDate: range?.start,
        endDate: range?.end,
        uncontactedDays:
            (days == null || days.isEmpty) ? null : int.tryParse(days),
        selectedTags: tags,
      ),
    );
  }

  /// 获取过滤排序后的联系人（筛选统一由 controller 消费 FilterConfig）
  Future<List<Contact>> _getFilteredContacts() {
    return _controller.getFilteredAndSortedContacts();
  }

  /// 取姓名首字母分组键：英文直接取，中文转拼音首字母，其余归入 # 组
  String _letterOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '#';

    final first = trimmed.substring(0, 1);
    if (RegExp(r'[a-zA-Z]').hasMatch(first)) return first.toUpperCase();

    final pinyin = PinyinHelper.getFirstWordPinyin(first);
    if (pinyin != null && pinyin.isNotEmpty) {
      final letter = pinyin[0].toUpperCase();
      if (RegExp(r'[A-Z]').hasMatch(letter)) return letter;
    }
    return '#';
  }

  /// 按首字母分组，组序 A-Z…#，组内保持过滤排序的顺序
  Map<String, List<Contact>> _groupContacts(List<Contact> contacts) {
    final groups = <String, List<Contact>>{};
    for (final contact in contacts) {
      groups.putIfAbsent(_letterOf(contact.name), () => []).add(contact);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });
    return {for (final key in keys) key: groups[key]!};
  }

  /// 字母分组的联系人列表 + 右侧索引条
  Widget _buildGroupedContactList(List<Contact> contacts) {
    final groups = _groupContacts(contacts);

    // 记录每个字母组在列表中的滚动偏移，供索引条跳转
    _letterOffsets.clear();
    double offset = 0;
    for (final group in groups.entries) {
      _letterOffsets[group.key] = offset;
      offset += _headerHeight + group.value.length * ContactListTile.height;
    }

    final entries = groups.entries.toList();
    final totalItems = entries.fold<int>(0, (sum, g) => sum + 1 + g.value.length);

    return Stack(
      children: [
        ListView.builder(
          controller: _listController,
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: totalItems,
          itemBuilder: (context, index) {
            int remaining = index;
            for (final group in entries) {
              if (remaining == 0) {
                return _buildSectionHeader(group.key);
              }
              remaining--;
              if (remaining < group.value.length) {
                final contact = group.value[remaining];
                return ContactListTile(
                  key: ValueKey(contact.id),
                  contact: contact,
                  seed: index,
                  onTap: () => _addOrEditContact(contact),
                  onLongPress: () => _showItemActions(contact),
                  onToggleFavorite: () => _toggleFavorite(contact),
                );
              }
              remaining -= group.value.length;
            }
            return const SizedBox.shrink();
          },
        ),
        Positioned(
          right: 2,
          top: 8,
          bottom: 8,
          child: _buildIndexBar(groups.keys.toSet()),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String letter) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      height: _headerHeight,
      padding: const EdgeInsets.only(left: 16),
      alignment: Alignment.centerLeft,
      child: JellyBox(
        color: theme.primary.withValues(alpha: 0.12),
        radius: BorderRadius.circular(999),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          letter,
          style: DsTypography.label.copyWith(color: theme.primary),
        ),
      ),
    );
  }

  /// 右侧字母索引条：点击/拖动跳到对应分组；无成员的字母置灰不可跳
  Widget _buildIndexBar(Set<String> availableLetters) {
    final theme = DSThemeBridge.resolve(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxHeight / _indexLetters.length;
        void jump(Offset localPosition) {
          final i = (localPosition.dy / slot).floor().clamp(0, _indexLetters.length - 1);
          _jumpToLetter(_indexLetters[i]);
        }

        return GestureDetector(
          onTapUp: (d) => jump(d.localPosition),
          onVerticalDragUpdate: (d) => jump(d.localPosition),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _indexLetters.map((letter) {
              final available = availableLetters.contains(letter);
              final active = _activeIndexLetter == letter;
              return SizedBox(
                height: slot,
                width: 20,
                child: Center(
                  child: Text(
                    letter,
                    style: DsTypography.caption.copyWith(
                      fontSize: 10,
                      color: active
                          ? theme.primary
                          : available
                              ? theme.textSub
                              : theme.textSub.withValues(alpha: 0.35),
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _jumpToLetter(String letter) {
    final target = _letterOffsets[letter];
    if (target == null || !_listController.hasClients) return;

    setState(() => _activeIndexLetter = letter);

    final max = _listController.position.maxScrollExtent;
    _listController.animateTo(
      target.clamp(0, max),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  /// 切换收藏并持久化
  Future<void> _toggleFavorite(Contact contact) async {
    await _controller.updateContact(
      contact.copyWith(isFavorite: !contact.isFavorite),
    );
    if (mounted) setState(() {});
  }

  /// 长按快捷操作：收藏切换 + 删除确认
  Future<void> _showItemActions(Contact contact) async {
    final theme = DSThemeBridge.resolve(context);

    await showDSBottomSheet(
      context: context,
      title: contact.name,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DSSheetAction(
            icon: DsIconKind.star,
            label: contact.isFavorite
                ? 'contact_removeFromFavorites'.tr
                : 'contact_addToFavorites'.tr,
            onTap: () {
              Navigator.pop(context);
              _toggleFavorite(contact);
            },
          ),
          DSSheetAction(
            icon: DsIconKind.trash,
            label: 'contact_deleteContact'.tr,
            destructive: true,
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(contact, theme: theme);
            },
          ),
        ],
      ),
    );
  }

  /// 删除确认（手绘对话框）
  Future<void> _confirmDelete(Contact contact, {AppThemeData? theme}) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: theme ?? DSThemeBridge.resolve(context),
      builder: (context) => DSDialog(
        title: 'contact_confirmDelete'.tr,
        message: 'contact_deleteConfirmMessage'.tr,
        confirmText: 'contact_deleteContact'.tr,
        cancelText: 'contact_cancel'.tr,
        confirmVariant: DSButtonVariant.destructive,
      ),
    );
    if (confirmed != true) return;

    await _controller.deleteContact(contact.id);
    _loadAvailableTags();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // key 随配置加载状态变化：持久化过滤配置加载完成后重建过滤栏，回显初值
    return KeyedSubtree(
      key: ValueKey(_filterConfigLoaded),
      child: SuperCupertinoNavigationWrapper(
      title: Text('contact_contacts'.tr),
      largeTitle: 'contact_contactListTitle'.tr,

      // ========== 搜索相关配置 ==========
      enableSearchBar: true,
      searchPlaceholder: 'contact_searchPlaceholder'.tr,
      onSearchChanged: (query) {
        _searchContacts(query);
      },
      searchBody: _buildSearchResults(),
      // ========== 多条件过滤配置 ==========
      enableMultiFilter: true,
      multiFilterItems: _buildFilterItems(),
      onMultiFilterChanged: _applyMultiFilters,
      body: FutureBuilder<List<Contact>>(
        future: _getFilteredContacts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('contact_errorMessage'.tr));
          }

          final contacts = snapshot.data ?? [];

          if (contacts.isEmpty) {
            final theme = DSThemeBridge.resolve(context);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DsIcon(
                    DsIconKind.search,
                    size: 64,
                    color: theme.textSub.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'contact_noContacts'.tr,
                    style: DsTypography.title.copyWith(color: theme.textSub),
                  ),
                ],
              ),
            );
          }

          return _buildGroupedContactList(contacts);
        },
      ),
      actions: [
        IconButton(
          key: _addButtonKey,
          icon: const Icon(Icons.add),
          onPressed: () {
            NavigationHelper.openContainerWithHero(
              context,
              (context) => ContactForm(
                onSave: (savedContact) async {
                  await _controller.addContact(savedContact);
                  setState(() {});
                  _loadAvailableTags();
                },
              ),
              sourceKey: _addButtonKey,
              heroTag: 'contact_add_button',
            );
          },
        ),
      ],
      enableLargeTitle: true,
      ),
    );
  }
}
