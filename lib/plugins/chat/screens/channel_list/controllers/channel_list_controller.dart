import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';

class ChannelListController extends ChangeNotifier {
  final List<Channel> channels;
  final ChatPlugin chatPlugin;
  late List<Channel> sortedChannels = [];
  String selectedGroup = "all"; // 当前选择的频道组
  late SharedPreferences prefs;
  List<String> availableGroups = ["all", "ungrouped"]; // 可用的频道组列表
  String searchQuery = ""; // 搜索关键词

  ChannelListController({required this.channels, required this.chatPlugin}) {
    _initialize();
    chatPlugin.addListener(_onChannelsUpdated);
  }

  /// 统一初始化方法,确保异步操作完成后再更新 UI
  Future<void> _initialize() async {
    // 1. 先加载用户偏好设置
    await _initializePrefs();

    // 2. 再更新可用分组和排序后的频道
    _updateAvailableGroups();

    // 3. 通知 UI 更新
    notifyListeners();
  }

  @override
  void dispose() {
    chatPlugin.removeListener(_onChannelsUpdated);
    super.dispose();
  }

  void _onChannelsUpdated() {
    // 当频道数据更新时,重新计算可用分组和排序
    _updateAvailableGroups();
    notifyListeners();
  }

  Future<void> _initializePrefs() async {
    prefs = await SharedPreferences.getInstance();
    selectedGroup = prefs.getString('selectedGroup') ?? "all";
    // 不在这里调用 notifyListeners(),由 _initialize() 统一调用
  }

  Future<void> loadSelectedGroup() async {
    prefs = await SharedPreferences.getInstance();
    selectedGroup = prefs.getString('selectedGroup') ?? "all";
    notifyListeners();
  }

  Future<void> saveSelectedGroup(String group) async {
    await prefs.setString('selectedGroup', group);
    selectedGroup = group;
    _updateSortedChannels();
    notifyListeners();
  }

  void _updateSortedChannels() {
    List<Channel> tempChannels;
    // 已封存的频道只在"archived"分类下显示，其他分类一律排除
    if (selectedGroup == "archived") {
      tempChannels = channels.where((channel) => channel.isArchived).toList();
    } else if (selectedGroup == "all") {
      tempChannels = channels.where((channel) => !channel.isArchived).toList();
    } else if (selectedGroup == "ungrouped") {
      tempChannels = channels
          .where((channel) => channel.groups.isEmpty && !channel.isArchived)
          .toList();
    } else {
      tempChannels = channels
          .where(
            (channel) =>
                channel.groups.contains(selectedGroup) && !channel.isArchived,
          )
          .toList();
    }

    // 去重：确保每个 ID 只出现一次（保留第一个出现的）
    final seenIds = <String>{};
    sortedChannels = tempChannels.where((channel) {
      if (seenIds.contains(channel.id)) {
        return false;
      }
      seenIds.add(channel.id);
      return true;
    }).toList()..sort(Channel.compare);
  }

  void _updateAvailableGroups() {
    // all/ungrouped/archived 为固定分类
    Set<String> groups = {"all", "ungrouped", "archived"};
    for (var channel in channels) {
      groups.addAll(channel.groups);
    }
    availableGroups = groups.toList()..sort();
    _updateSortedChannels();
  }

  Future<void> addChannel(Channel channel) async {
    await ChatPlugin.instance.channelService.createChannel(channel);
    _updateAvailableGroups();
    _updateSortedChannels();
    notifyListeners();
  }

  Future<void> updateChannel(Channel updatedChannel) async {
    await chatPlugin.channelService.saveChannel(updatedChannel);
    _updateAvailableGroups();
    notifyListeners();
  }

  Future<void> deleteChannel(String channelId) async {
    await chatPlugin.channelService.deleteChannel(channelId);
    _updateSortedChannels();
    notifyListeners();
  }

  Future<void> togglePin(Channel channel) async {
    await chatPlugin.channelService.patchChannel(channel.id, {
      'isPinned': !channel.isPinned,
    });
    _updateSortedChannels();
    notifyListeners();
  }

  Future<void> toggleArchive(Channel channel) async {
    final archived = !channel.isArchived;
    await chatPlugin.channelService.patchChannel(channel.id, {
      'isArchived': archived,
      if (archived) 'isPinned': false,
    });
    _updateSortedChannels();
    notifyListeners();
  }

  Future<void> reorderChannels(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex--;
    final ordered = [...sortedChannels];
    final item = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, item);
    await chatPlugin.channelService.reorderChannels(
      ordered.map((c) => c.id).toList(),
    );
    _updateSortedChannels();
    notifyListeners();
  }

  /// 获取过滤后的频道列表（应用搜索和分组过滤）
  List<Channel> get filteredChannels {
    List<Channel> filtered = List.from(sortedChannels);

    // 应用搜索过滤
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((channel) {
        return channel.title.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  /// 设置搜索关键词
  void setSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }

  /// 清除搜索
  void clearSearch() {
    searchQuery = "";
    notifyListeners();
  }
}
