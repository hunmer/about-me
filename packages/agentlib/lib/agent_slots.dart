/// Configuration slots reserved for future global and per-agent resources.
class AgentResourceSlots {
  const AgentResourceSlots({
    this.skills = const [],
    this.mcpServers = const [],
  });
  final List<String> skills;
  final List<String> mcpServers;

  Map<String, dynamic> toJson() => {'skills': skills, 'mcpServers': mcpServers};
  factory AgentResourceSlots.fromJson(Map<String, dynamic>? json) =>
      AgentResourceSlots(
        skills: (json?['skills'] as List<dynamic>?)?.cast<String>() ?? const [],
        mcpServers:
            (json?['mcpServers'] as List<dynamic>?)?.cast<String>() ?? const [],
      );
}
