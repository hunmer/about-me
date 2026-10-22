import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/calendar_album/controllers/calendar_controller.dart';
import 'package:aboutme/plugins/calendar_album/models/calendar_entry.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';

/// 相册照片记录：照片与其所属日记条目的关联（过滤/搜索均基于条目元数据）。
/// 相册瀑布流与照片地图页共用
class AlbumMapPhoto {
  final String url;
  final String? liveVideoUrl;
  final CalendarEntry entry;

  const AlbumMapPhoto({
    required this.url,
    this.liveVideoUrl,
    required this.entry,
  });
}

/// 相册照片的多条件过滤/搜索条件与执行逻辑。
/// 相册页与照片地图页共用，保证两处过滤行为一致
class AlbumPhotoQuery {
  const AlbumPhotoQuery({this.multiFilters = const {}, this.searchQuery = ''});

  final Map<String, dynamic> multiFilters;
  final String searchQuery;

  /// 构建照片记录列表（按日记日期倒序，同一条目的 imageUrls + markdown 内联图）
  static List<AlbumMapPhoto> buildRecords(CalendarController controller) {
    final records = <AlbumMapPhoto>[];
    final seen = <String>{};
    final dates = controller.entries.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final date in dates) {
      final entries = controller.entries[date]!;
      final sorted = List<CalendarEntry>.from(entries)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      for (final entry in sorted) {
        final urls = [...entry.imageUrls, ...entry.extractImagesFromMarkdown()];
        for (final url in urls) {
          if (url.isEmpty || !seen.add(url)) continue;
          final imageIndex = entry.imageUrls.indexOf(url);
          final liveVideoUrl =
              imageIndex >= 0 &&
                  imageIndex < entry.liveVideoUrls.length &&
                  entry.liveVideoUrls[imageIndex].isNotEmpty
              ? entry.liveVideoUrls[imageIndex]
              : null;
          records.add(
            AlbumMapPhoto(url: url, liveVideoUrl: liveVideoUrl, entry: entry),
          );
        }
      }
    }
    return records;
  }

  /// 应用多条件过滤 + 搜索（不排序，调用方按需排序）
  List<AlbumMapPhoto> apply(List<AlbumMapPhoto> all) {
    var photos = all.where((r) => _passesMultiFilters(r.entry)).toList();
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      photos = photos.where((r) => _matchesSearch(r.entry, query)).toList();
    }
    return photos;
  }

  /// 条目是否通过所有多条件过滤
  bool _passesMultiFilters(CalendarEntry entry) {
    // 1. 标签过滤（任一命中即通过）
    final selectedTags = multiFilters['tags'];
    if (selectedTags is List && selectedTags.isNotEmpty) {
      final hasAnyTag = entry.tags.any((tag) => selectedTags.contains(tag));
      if (!hasAnyTag) return false;
    }

    // 2. 日期范围过滤（按日记创建日期）
    final range = multiFilters['dateRange'];
    if (range is DateTimeRange) {
      final end = range.end.add(const Duration(days: 1));
      if (entry.createdAt.isBefore(range.start) ||
          entry.createdAt.isAfter(end)) {
        return false;
      }
    }

    // 3. 标题关键词过滤
    final title = multiFilters['title'];
    if (title is String &&
        title.isNotEmpty &&
        !entry.title.toLowerCase().contains(title.toLowerCase())) {
      return false;
    }

    // 4. 注释关键词过滤（剔除 markdown 内联图语法，避免命中图片路径）
    final content = multiFilters['content'];
    if (content is String && content.isNotEmpty) {
      final plain = entry.content.replaceAll(
        RegExp(r'!\[.*?\]\(.*?\)'),
        '',
      );
      if (!plain.toLowerCase().contains(content.toLowerCase())) return false;
    }

    // 5. 心情过滤
    final mood = multiFilters['mood'];
    if (mood is String && entry.mood != mood) return false;

    // 6. 天气过滤
    final weather = multiFilters['weather'];
    if (weather is String && entry.weather != weather) return false;

    // 7. 位置过滤
    final location = multiFilters['location'];
    if (location is String && entry.location != location) return false;

    return true;
  }

  /// 搜索匹配：日记标题/标签/内容（[query] 已小写）
  bool _matchesSearch(CalendarEntry entry, String query) {
    if (entry.title.toLowerCase().contains(query)) return true;
    if (entry.tags.any((tag) => tag.toLowerCase().contains(query))) return true;
    if (entry.content.toLowerCase().contains(query)) return true;
    return false;
  }

  /// 心情/天气存储值转显示文案：优先取翻译键，缺失时回退原值
  /// （历史数据可能直接存中文或 emoji）
  static String enumLabel(String kind, String value) {
    final key = 'calendar_album_${kind}_${value.toLowerCase()}';
    final label = key.tr;
    return label == key ? value : label;
  }

  /// 收集日记条目中实际出现的心情/天气取值
  static List<String> _getDistinctEntryValues(
    CalendarController controller,
    String? Function(CalendarEntry) pick,
  ) {
    final values = <String>{};
    for (final entries in controller.entries.values) {
      for (final entry in entries) {
        final value = pick(entry);
        if (value != null && value.isNotEmpty) values.add(value);
      }
    }
    return values.toList()..sort();
  }

  /// 构建多条件过滤项
  static List<FilterItem> buildFilterItems(
    CalendarController controller, {
    List<String>? initialTags,
  }) {
    final availableTags = controller.getAllTags();
    final moods = _getDistinctEntryValues(controller, (e) => e.mood);
    final weathers = _getDistinctEntryValues(controller, (e) => e.weather);
    final locations = _getDistinctEntryValues(controller, (e) => e.location);

    return [
      // 1. 标签多选
      if (availableTags.isNotEmpty)
        FilterItem(
          id: 'tags',
          title: 'calendar_album_tag'.tr,
          type: FilterType.tagsMultiple,
          initialValue: initialTags,
          builder: (context, currentValue, onChanged) {
            return FilterBuilders.buildTagsFilter(
              context: context,
              currentValue: currentValue,
              onChanged: onChanged,
              availableTags: availableTags,
            );
          },
          getBadge: FilterBuilders.tagsBadge,
        ),

      // 2. 日期范围（按日记创建日期过滤）
      FilterItem(
        id: 'dateRange',
        title: 'calendar_album_date_range'.tr,
        type: FilterType.dateRange,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildDateRangeFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
          );
        },
        getBadge: FilterBuilders.dateRangeBadge,
      ),

      // 3. 标题关键词输入
      FilterItem(
        id: 'title',
        title: 'calendar_album_title'.tr,
        type: FilterType.input,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildKeywordFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
          );
        },
        getBadge: FilterBuilders.keywordBadge,
      ),

      // 4. 注释（日记内容）关键词输入
      FilterItem(
        id: 'content',
        title: 'calendar_album_content'.tr,
        type: FilterType.input,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildKeywordFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
          );
        },
        getBadge: FilterBuilders.keywordBadge,
      ),

      // 5. 心情单选
      if (moods.isNotEmpty)
        FilterItem(
          id: 'mood',
          title: 'calendar_album_mood'.tr,
          type: FilterType.tagsSingle,
          builder: (context, currentValue, onChanged) {
            return _buildEnumSingleFilter(
              values: moods,
              labelOf: (v) => enumLabel('mood', v),
              currentValue: currentValue,
              onChanged: onChanged,
            );
          },
          getBadge: (value) =>
              value is String ? enumLabel('mood', value) : null,
        ),

      // 6. 天气单选
      if (weathers.isNotEmpty)
        FilterItem(
          id: 'weather',
          title: 'calendar_album_weather'.tr,
          type: FilterType.tagsSingle,
          builder: (context, currentValue, onChanged) {
            return _buildEnumSingleFilter(
              values: weathers,
              labelOf: (v) => enumLabel('weather', v),
              currentValue: currentValue,
              onChanged: onChanged,
            );
          },
          getBadge: (value) =>
              value is String ? enumLabel('weather', value) : null,
        ),

      // 7. 位置单选（日记实际出现过的地址）
      if (locations.isNotEmpty)
        FilterItem(
          id: 'location',
          title: 'calendar_album_location'.tr,
          type: FilterType.tagsSingle,
          builder: (context, currentValue, onChanged) {
            return _buildEnumSingleFilter(
              values: locations,
              labelOf: (v) => v,
              currentValue: currentValue,
              onChanged: onChanged,
            );
          },
          getBadge: FilterBuilders.keywordBadge,
        ),
    ];
  }

  /// 枚举单选过滤器（心情/天气）：选中后自动返回第一层
  static Widget _buildEnumSingleFilter({
    required List<String> values,
    required String Function(String) labelOf,
    required dynamic currentValue,
    required FilterItemChanged onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          DSChip(
            label: labelOf(value),
            selected: currentValue == value,
            onSelected: (selected) =>
                onChanged(selected ? value : null, done: true),
          ),
      ],
    );
  }
}
