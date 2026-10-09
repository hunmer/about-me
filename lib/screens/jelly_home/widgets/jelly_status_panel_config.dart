import 'dart:convert';
import 'dart:ui';

enum JellyStatusItemType { mood, energy, affection, companionDays }

class JellyStatusItemConfig {
  const JellyStatusItemConfig({
    required this.type,
    required this.iconRegion,
    required this.valueRegion,
  });

  final JellyStatusItemType type;
  final Rect iconRegion;
  final Rect valueRegion;

  Map<String, Object> toJson() => {
    'type': type.name,
    'icon': _rectToJson(iconRegion),
    'value': _rectToJson(valueRegion),
  };

  factory JellyStatusItemConfig.fromJson(Map<String, dynamic> json) {
    return JellyStatusItemConfig(
      type: JellyStatusItemType.values.byName(json['type'] as String),
      iconRegion: _rectFromJson(json['icon']),
      valueRegion: _rectFromJson(json['value']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is JellyStatusItemConfig &&
      other.type == type &&
      other.iconRegion == iconRegion &&
      other.valueRegion == valueRegion;

  @override
  int get hashCode => Object.hash(type, iconRegion, valueRegion);
}

class JellyStatusPanelConfig {
  const JellyStatusPanelConfig({
    required this.avatarRegion,
    required this.experienceRegion,
    required this.items,
  });

  static const defaults = JellyStatusPanelConfig(
    avatarRegion: Rect.fromLTRB(0.055, 0.37, 0.225, 0.69),
    experienceRegion: Rect.fromLTRB(0.255, 0.405, 0.925, 0.525),
    items: [
      JellyStatusItemConfig(
        type: JellyStatusItemType.mood,
        iconRegion: Rect.fromLTRB(0.245, 0.565, 0.305, 0.685),
        valueRegion: Rect.fromLTRB(0.305, 0.575, 0.405, 0.68),
      ),
      JellyStatusItemConfig(
        type: JellyStatusItemType.energy,
        iconRegion: Rect.fromLTRB(0.425, 0.565, 0.485, 0.685),
        valueRegion: Rect.fromLTRB(0.485, 0.575, 0.585, 0.68),
      ),
      JellyStatusItemConfig(
        type: JellyStatusItemType.affection,
        iconRegion: Rect.fromLTRB(0.595, 0.565, 0.655, 0.685),
        valueRegion: Rect.fromLTRB(0.655, 0.575, 0.755, 0.68),
      ),
    ],
  );

  static const itemSlots = <({Rect icon, Rect value})>[
    (
      icon: Rect.fromLTRB(0.245, 0.565, 0.305, 0.685),
      value: Rect.fromLTRB(0.305, 0.575, 0.405, 0.68),
    ),
    (
      icon: Rect.fromLTRB(0.425, 0.565, 0.485, 0.685),
      value: Rect.fromLTRB(0.485, 0.575, 0.585, 0.68),
    ),
    (
      icon: Rect.fromLTRB(0.595, 0.565, 0.655, 0.685),
      value: Rect.fromLTRB(0.655, 0.575, 0.755, 0.68),
    ),
    (
      icon: Rect.fromLTRB(0.765, 0.565, 0.825, 0.685),
      value: Rect.fromLTRB(0.825, 0.575, 0.925, 0.68),
    ),
  ];

  final Rect avatarRegion;
  final Rect experienceRegion;
  final List<JellyStatusItemConfig> items;

  JellyStatusPanelConfig copyWith({
    Rect? avatarRegion,
    Rect? experienceRegion,
    List<JellyStatusItemConfig>? items,
  }) => JellyStatusPanelConfig(
    avatarRegion: avatarRegion ?? this.avatarRegion,
    experienceRegion: experienceRegion ?? this.experienceRegion,
    items: items ?? this.items,
  );

  String encode() => jsonEncode({
    'avatar': _rectToJson(avatarRegion),
    'experience': _rectToJson(experienceRegion),
    'items': items.map((item) => item.toJson()).toList(),
  });

  static JellyStatusPanelConfig parse(
    String? source, {
    JellyStatusPanelConfig fallback = defaults,
  }) {
    if (source == null || source.isEmpty) return fallback;
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      final config = JellyStatusPanelConfig(
        avatarRegion: _rectFromJson(json['avatar']),
        experienceRegion: _rectFromJson(json['experience']),
        items: (json['items'] as List<dynamic>)
            .map(
              (item) =>
                  JellyStatusItemConfig.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
      if (!config._isValid) return fallback;
      return config;
    } catch (_) {
      return fallback;
    }
  }

  bool get _isValid =>
      _validRect(avatarRegion) &&
      _validRect(experienceRegion) &&
      items.length <= JellyStatusItemType.values.length &&
      items.map((item) => item.type).toSet().length == items.length &&
      items.every(
        (item) => _validRect(item.iconRegion) && _validRect(item.valueRegion),
      );

  @override
  bool operator ==(Object other) =>
      other is JellyStatusPanelConfig &&
      other.avatarRegion == avatarRegion &&
      other.experienceRegion == experienceRegion &&
      _listEquals(other.items, items);

  @override
  int get hashCode =>
      Object.hash(avatarRegion, experienceRegion, Object.hashAll(items));
}

List<double> _rectToJson(Rect rect) => [
  rect.left,
  rect.top,
  rect.right,
  rect.bottom,
];

Rect _rectFromJson(dynamic source) {
  final values = (source as List<dynamic>).cast<num>();
  if (values.length != 4) throw const FormatException('Invalid region');
  return Rect.fromLTRB(
    values[0].toDouble(),
    values[1].toDouble(),
    values[2].toDouble(),
    values[3].toDouble(),
  );
}

bool _validRect(Rect rect) =>
    rect.left >= 0 &&
    rect.top >= 0 &&
    rect.right <= 1 &&
    rect.bottom <= 1 &&
    rect.width > 0 &&
    rect.height > 0;

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
