/// Agent 资产图（角色设定/场景参考图，供生图保持形象一致）
class AgentAsset {
  final String id;
  final String name;

  /// 占位生成提示词模板（生成时自动附加 agent 人设描述）
  final String prompt;

  /// 图片相对路径；null = 未生成的占位
  String? path;
  final DateTime createdAt;

  AgentAsset({
    required this.id,
    required this.name,
    required this.prompt,
    this.path,
    required this.createdAt,
  });

  bool get hasImage => path != null && path!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'prompt': prompt,
    'path': path,
    'createdAt': createdAt.toIso8601String(),
  };

  static AgentAsset fromJson(Map<String, dynamic> json) => AgentAsset(
    id: json['id'] as String,
    name: json['name'] as String,
    prompt: (json['prompt'] as String?) ?? '',
    path: json['path'] as String?,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now(),
  );

  AgentAsset copyWith({String? name, String? prompt, String? path}) =>
      AgentAsset(
        id: id,
        name: name ?? this.name,
        prompt: prompt ?? this.prompt,
        path: path ?? this.path,
        createdAt: createdAt,
      );
}
