import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/widgets/tags_dialog/tags_dialog.dart';
import 'package:aboutme/plugins/calendar_album/controllers/calendar_controller.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/constants/app_icons.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/item_event_args.dart';

/// 简单的标签组数据结构（本地定义，保持向后兼容）
class TagGroup {
  final String name;
  final List<String> tags;

  TagGroup({required this.name, required this.tags});

  TagGroup copyWith({String? name, List<String>? tags}) {
    return TagGroup(
      name: name ?? this.name,
      tags: tags ?? List.from(this.tags),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'tags': tags};
  }

  factory TagGroup.fromJson(Map<String, dynamic> json) {
    return TagGroup(
      name: json['name'] as String,
      tags: List<String>.from(json['tags'] as List),
    );
  }
}

class TagController extends ChangeNotifier {
  // 发送事件通知
  void _notifyEvent(String action, String tagName) {
    final eventArgs = ItemEventArgs(
      eventName: 'calendar_tag_$action',
      itemId: tagName,
      title: tagName,
      action: action,
    );
    EventManager.instance.broadcast('calendar_tag_$action', eventArgs);
  }
  final VoidCallback? onTagsChanged;

  List<TagGroup> tagGroups = [];
  List<String> selectedTags = [];
  List<String> recentTags = [];

  /// 标签 → 文件夹贴纸图标名（AppIcons.predefinedIcons 的键）
  Map<String, String> tagIcons = {};

  TagController({this.onTagsChanged}) {
    initialize();
  }

  Future<void> initialize() async {
    // 初始化默认标签组
    tagGroups = [
      TagGroup(name: '最近使用', tags: []),
      TagGroup(name: '地点', tags: ['家', '工作', '旅行']),
      TagGroup(name: '活动', tags: ['生日', '聚会', '会议']),
      TagGroup(name: '心情', tags: ['开心', '平静', '兴奋', '思考']),
    ];

    try {
      // 加载标签数据（tag 三文件合一命令）
      final result = await AboutmeDataService.instance.get(
        'calendar_album',
        'getTags',
      );
      if (result['success'] != true) {
        throw Exception('加载标签失败: ${result['error']}');
      }
      final tags = Map<String, dynamic>.from(result['data'] as Map);

      // 尝试加载标签组
      final groups = (tags['tagGroups'] as List).cast<Map>();
      if (groups.isNotEmpty) {
        tagGroups = groups
            .map((e) => TagGroup.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        // 如果文件为空，保存默认标签组
        await _saveTagGroups();
      }

      // 尝试加载最近使用的标签
      recentTags = (tags['recentTags'] as List).cast<String>().toList();
      _updateRecentTagGroup();

      // 尝试加载标签文件夹图标
      tagIcons = (tags['tagIcons'] as Map).map(
        (key, value) => MapEntry(key as String, value.toString()),
      );

      notifyListeners();
      onTagsChanged?.call();
    } catch (e, stack) {
      debugPrint('加载标签组失败: $e');
      debugPrint('Stack trace: $stack');
      initialize();
    }
  }

  Future<void> _saveTagGroups() async {
    try {
      await AboutmeDataService.instance.call('calendar_album', 'updateTags', {
        'tagGroups': tagGroups
            .map((group) => {'name': group.name, 'tags': group.tags})
            .toList(),
      });
    } catch (e) {
      debugPrint('保存标签组失败: $e');
    }
  }

  Future<void> _saveRecentTags() async {
    try {
      await AboutmeDataService.instance.call('calendar_album', 'updateTags', {
        'recentTags': List<String>.from(recentTags),
      });
    } catch (e) {
      debugPrint('保存最近标签失败: $e');
    }
  }

  Future<void> _saveTagIcons() async {
    try {
      await AboutmeDataService.instance.call('calendar_album', 'updateTags', {
        'tagIcons': Map<String, String>.from(tagIcons),
      });
    } catch (e) {
      debugPrint('保存标签图标失败: $e');
    }
  }

  /// 设置/移除标签文件夹贴纸（值为图标键，或 `emoji:<字符>` / `img:<图片地址>`）
  Future<void> setTagIcon(String tag, String? iconName) async {
    if (iconName == null) {
      tagIcons.remove(tag);
    } else {
      tagIcons[tag] = iconName;
    }
    await _saveTagIcons();
    notifyListeners();
    onTagsChanged?.call();
  }

  /// 获取标签文件夹贴纸原始值（图标键 / emoji: / img: 前缀，未设置返回 null）
  String? getTagSticker(String tag) => tagIcons[tag];

  /// 获取标签文件夹贴纸图标（非图标类贴纸或未设置返回 null）
  IconData? getTagIcon(String tag) {
    final name = tagIcons[tag];
    if (name == null || name.startsWith('emoji:') || name.startsWith('img:')) {
      return null;
    }
    return AppIcons.predefinedIcons[name];
  }

  void _updateRecentTagGroup() {
    final recentGroupIndex = tagGroups.indexWhere((g) => g.name == '最近使用');
    if (recentGroupIndex != -1) {
      tagGroups[recentGroupIndex] = TagGroup(
        name: '最近使用',
        tags: List.from(recentTags),
      );
    }
  }

  Future<void> updateRecentTags(List<String> tags) async {
    if (tags.isEmpty) return;

    for (final tag in tags) {
      recentTags.remove(tag);
      recentTags.insert(0, tag);
    }

    if (recentTags.length > 10) {
      recentTags.removeRange(10, recentTags.length);
    }

    _updateRecentTagGroup();
    await _saveRecentTags();
    await _saveTagGroups();
    notifyListeners();
    onTagsChanged?.call();
  }

  /// 收集标签下的图片（imageUrls + markdown 内联图，去重，新条目在前）
  List<String> getTagImages(String tag) {
    final plugin = PluginManager.instance.getPlugin('calendar_album');
    final calendar =
        (plugin as dynamic).calendarController as CalendarController?;
    if (calendar == null) return const [];

    final urls = <String>[];
    final seen = <String>{};
    for (final entry in calendar.getEntriesByTag(tag)) {
      for (final url in [...entry.imageUrls, ...entry.extractImagesFromMarkdown()]) {
        if (url.isEmpty || !seen.add(url)) continue;
        urls.add(url);
      }
    }
    return urls;
  }

  Future<List<String>?> showTagManagerDialog(
    BuildContext context, {
    TagsItemBuilder? tagItemBuilder,
  }) async {
    // 转换为新组件可接受的格式
    final legacyGroups = tagGroups.map((g) => g.toJson()).toList();

    final result = await TagsDialog.show(
      context,
      groups: legacyGroups,
      selectedTags: List.from(selectedTags),
      tagItemBuilder: tagItemBuilder,
      config: TagsDialogConfig(
        title: '标签管理',
        // 默认单选：选中即返回（调用方可据此打开标签文件夹）；
        // 传入 tagItemBuilder 的场景（如添加日记选标签）为多选
        selectionMode: tagItemBuilder != null
            ? TagsSelectionMode.multiple
            : TagsSelectionMode.single,
        enableEditing: true,
        enableBatchEdit: true,
      ),
      onGroupsChanged: (newGroups) {
        // 新格式转回旧格式
        tagGroups = newGroups.map((g) => TagGroup(
          name: g.name,
          tags: g.tags.map((t) => t.name).toList(),
        )).toList();
        _saveTagGroups();
        notifyListeners();
        onTagsChanged?.call();
      },
    );

    if (result != null) {
      selectedTags = List.from(result);
      await updateRecentTags(selectedTags);
      notifyListeners();
      onTagsChanged?.call();
      return selectedTags;
    }
    return null;
  }

  void setState(void Function() fn) {
    fn();
    notifyListeners();
  }

  List<String> get tags {
    return tagGroups.expand((group) => group.tags).toList();
  }

  Future<void> addTag(String tag, {String? groupName}) async {
    final group =
        groupName != null
            ? tagGroups.firstWhere(
              (g) => g.name == groupName,
              orElse: () => TagGroup(name: groupName, tags: []),
            )
            : tagGroups.firstWhere((g) => g.name == '最近使用');

    if (!group.tags.contains(tag)) {
      group.tags.add(tag);
      await _saveTagGroups();
      notifyListeners();

      // 广播添加事件
      _notifyEvent('added', tag);
    }
  }

  Future<void> deleteTag(String tag) async {
    for (final group in tagGroups) {
      group.tags.remove(tag);
    }
    recentTags.remove(tag);
    tagIcons.remove(tag);
    await _saveTagGroups();
    await _saveRecentTags();
    await _saveTagIcons();
    notifyListeners();

    // 广播删除事件
    _notifyEvent('deleted', tag);
  }

  bool hasTag(String name) {
    return tagGroups.any((group) => group.tags.contains(name));
  }
}
