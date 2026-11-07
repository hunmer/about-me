import 'package:uuid/uuid.dart';

/// 记录模版条目：一天中的一个固定时间点（如 起床 07:00）
class ActivityTemplateItem {
  final String id;

  /// 时间点名称（如 起床 / 出门 / 下班）
  final String title;

  /// 当日分钟偏移（0 = 00:00，最大 23*60+59）
  final int minutes;

  /// 应用模版时生成记录的时长（分钟）
  final int durationMinutes;

  ActivityTemplateItem({
    String? id,
    required this.title,
    required this.minutes,
    this.durationMinutes = 30,
  }) : id = id ?? const Uuid().v4();

  ActivityTemplateItem copyWith({
    String? title,
    int? minutes,
    int? durationMinutes,
  }) {
    return ActivityTemplateItem(
      id: id,
      title: title ?? this.title,
      minutes: minutes ?? this.minutes,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }

  factory ActivityTemplateItem.fromJson(Map<String, dynamic> json) {
    return ActivityTemplateItem(
      id: json['id']?.toString(),
      title: (json['title'] ?? '').toString(),
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'minutes': minutes,
      'durationMinutes': durationMinutes,
    };
  }

  /// 分钟偏移格式化为 HH:mm；负数或超过 23:59 时加「前日/次日」前缀
  static String formatMinutes(int minutes) {
    var day = minutes ~/ 1440;
    var m = minutes % 1440;
    if (m < 0) {
      m += 1440;
      day -= 1;
    }
    final label =
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    if (day > 0) return '次日 $label';
    if (day < 0) return '前日 $label';
    return label;
  }

  /// 分钟偏移格式化为 HH:mm（含跨天前缀）
  String get formattedTime => formatMinutes(minutes);
}

/// 记录模版：一组固定时间点，用于一键记录一天的时间点
/// （如 起床 07:00 / 出门 08:00 / 下班 18:00）；
/// 应用时可调整任一时间点，其余时间点按相对间隔联动平移
class ActivityRecordTemplate {
  final String id;

  /// 模版名称（如 工作日）
  final String name;

  /// 时间点列表（按时间顺序展示，存储时不强制排序）
  final List<ActivityTemplateItem> items;

  ActivityRecordTemplate({
    String? id,
    required this.name,
    required this.items,
  }) : id = id ?? const Uuid().v4();

  ActivityRecordTemplate copyWith({
    String? name,
    List<ActivityTemplateItem>? items,
  }) {
    return ActivityRecordTemplate(
      id: id,
      name: name ?? this.name,
      items: items ?? this.items,
    );
  }

  factory ActivityRecordTemplate.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'];
    return ActivityRecordTemplate(
      id: json['id']?.toString(),
      name: (json['name'] ?? '').toString(),
      items: itemsJson is List
          ? itemsJson
                .whereType<Map>()
                .map((e) => ActivityTemplateItem.fromJson(
                    Map<String, dynamic>.from(e)))
                .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }

  /// 按时间排序的条目副本
  List<ActivityTemplateItem> get sortedItems {
    final list = List<ActivityTemplateItem>.from(items)
      ..sort((a, b) => a.minutes.compareTo(b.minutes));
    return list;
  }
}
