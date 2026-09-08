/// A selectable AgentLib resource entry.
class AgentResourceItem {
  const AgentResourceItem({
    required this.id,
    this.name,
    this.enabled = true,
    this.tags = const [],
    this.content,
  });

  final String id;
  final String? name;
  final bool enabled;
  final List<String> tags;
  final String? content;

  String get displayName => name?.isNotEmpty == true ? name! : id;

  AgentResourceItem copyWith({
    String? id,
    String? name,
    bool? enabled,
    List<String>? tags,
    String? content,
  }) => AgentResourceItem(
    id: id ?? this.id,
    name: name ?? this.name,
    enabled: enabled ?? this.enabled,
    tags: tags ?? this.tags,
    content: content ?? this.content,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (name != null) 'name': name,
    'enabled': enabled,
    'tags': tags,
    if (content != null) 'content': content,
  };

  factory AgentResourceItem.fromJson(dynamic value) {
    if (value is String) return AgentResourceItem(id: value);
    final json = Map<String, dynamic>.from(value as Map);
    return AgentResourceItem(
      id: json['id'] as String? ?? json['name'] as String? ?? '',
      name: json['name'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      content: json['content'] as String?,
    );
  }
}

/// Configuration slots reserved for global and per-agent resources.
class AgentResourceSlots {
  const AgentResourceSlots({
    this.skills = const [],
    this.mcpServers = const [],
  });
  final List<AgentResourceItem> skills;
  final List<AgentResourceItem> mcpServers;

  Map<String, dynamic> toJson() => {
    'skills': skills.map((item) => item.toJson()).toList(),
    'mcpServers': mcpServers.map((item) => item.toJson()).toList(),
  };
  factory AgentResourceSlots.fromJson(Map<String, dynamic>? json) =>
      AgentResourceSlots(
        skills:
            (json?['skills'] as List<dynamic>?)
                ?.map(AgentResourceItem.fromJson)
                .where((item) => item.id.isNotEmpty)
                .toList() ??
            const [],
        mcpServers:
            (json?['mcpServers'] as List<dynamic>?)
                ?.map(AgentResourceItem.fromJson)
                .where((item) => item.id.isNotEmpty)
                .toList() ??
            const [],
      );
}
