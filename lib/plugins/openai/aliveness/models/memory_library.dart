import 'package:shared_models/shared_models.dart';
class MemoryLibrary {
  const MemoryLibrary({
    required this.id,
    required this.name,
    required this.createdAt,
    this.description = '',
    this.allowedKeyPrefixes = const [],
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final String description;
  final List<String> allowedKeyPrefixes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    if (description.isNotEmpty) 'description': description,
    if (allowedKeyPrefixes.isNotEmpty) 'allowedKeyPrefixes': allowedKeyPrefixes,
  };

  factory MemoryLibrary.fromJson(Map<String, dynamic> json) => MemoryLibrary(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: parseIsoDateTime(json['createdAt'] as String),
    description: (json['description'] as String? ?? '').trim(),
    allowedKeyPrefixes: _readPrefixes(json['allowedKeyPrefixes']),
  );

  static List<String> _readPrefixes(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .map((prefix) => prefix.trim().replaceFirst(RegExp(r'\\.+$'), ''))
        .where((prefix) => prefix.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}
