/// 脚本配置文件（Profile）
///
/// 一个脚本可拥有多份配置文件，每份是配置表单（configFormFields）的一组值，
/// 便于同一脚本在不同场景（如不同账号/环境）间切换。
///
/// 存储格式（configs/scripts_center/{scriptId}_config.json）：
/// {
///   "profiles": [{"id": "default", "name": "默认", "values": {...}}],
///   "defaultProfileId": "default"
/// }
/// 旧格式（扁平值 Map）读取时自动视为单个 default 配置文件。
class ScriptProfile {
  /// 配置文件唯一标识
  final String id;

  /// 显示名称
  String name;

  /// 表单值
  Map<String, dynamic> values;

  ScriptProfile({
    required this.id,
    required this.name,
    Map<String, dynamic>? values,
  }) : values = values ?? {};

  factory ScriptProfile.fromJson(Map<String, dynamic> json) {
    return ScriptProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? (json['id'] as String),
      values: (json['values'] as Map<dynamic, dynamic>?)
              ?.map((k, v) => MapEntry(k.toString(), v)) ??
          {},
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'values': values};
}

/// 多配置文件容器（配置文件列表 + 默认项）
class ScriptProfiles {
  List<ScriptProfile> profiles;

  /// 默认配置文件 id（执行未指定 profileId 时使用）
  String? defaultProfileId;

  ScriptProfiles({required this.profiles, this.defaultProfileId});

  /// 无配置时的空容器（仅含一个空 default）
  factory ScriptProfiles.empty() => ScriptProfiles(
        profiles: [ScriptProfile(id: 'default', name: '默认')],
        defaultProfileId: 'default',
      );

  /// 从存储数据解析，兼容旧扁平格式（整体视为 default 配置文件的值）
  static ScriptProfiles fromStorage(dynamic data) {
    if (data is Map) {
      final map = data.map((k, v) => MapEntry(k.toString(), v));
      final profilesJson = map['profiles'];
      // 仅当 profiles 是非空 List 且元素含 id 字段时才认为是新格式，
      // 避免旧扁平配置中恰好存在 profiles 字段被误判
      if (profilesJson is List && profilesJson.isNotEmpty) {
        final profiles = profilesJson
            .whereType<Map>()
            .where((e) => e['id'] != null)
            .map((e) => ScriptProfile.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v))))
            .toList();
        if (profiles.isNotEmpty) {
          final defaultId = map['defaultProfileId'] as String?;
          return ScriptProfiles(
            profiles: profiles,
            defaultProfileId: profiles.any((p) => p.id == defaultId)
                ? defaultId
                : profiles.first.id,
          );
        }
      }
      // 旧扁平格式
      return ScriptProfiles(
        profiles: [
          ScriptProfile(
            id: 'default',
            name: '默认',
            values: Map<String, dynamic>.from(map),
          ),
        ],
        defaultProfileId: 'default',
      );
    }
    return ScriptProfiles.empty();
  }

  /// 按 id 查找
  ScriptProfile? getById(String? id) {
    if (id == null || id.isEmpty) return null;
    try {
      return profiles.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 默认配置文件（defaultProfileId 缺失/失效时取第一个）
  ScriptProfile? get defaultProfile => getById(defaultProfileId) ??
      (profiles.isEmpty ? null : profiles.first);

  /// 序列化为存储结构
  Map<String, dynamic> toStorage() {
    return {
      'profiles': profiles.map((p) => p.toJson()).toList(),
      'defaultProfileId': defaultProfile?.id,
    };
  }
}
