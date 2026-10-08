/// 贴图合集
///
/// 贴图文件统一存放在 `stickers/{id}/` 目录（相对 app_data），
/// 注册表持久化在 `stickers/collections.json`。
class StickerCollection {
  final String id;
  String name;

  /// 封面贴图的存储相对路径（默认取第一张贴图）
  String? coverPath;

  /// 贴图文件的存储相对路径列表
  List<String> stickerPaths;

  final DateTime createdAt;
  DateTime updatedAt;

  StickerCollection({
    required this.id,
    required this.name,
    this.coverPath,
    List<String>? stickerPaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : stickerPaths = stickerPaths ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  int get stickerCount => stickerPaths.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'coverPath': coverPath,
    'stickerPaths': stickerPaths,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static StickerCollection fromJson(Map<String, dynamic> json) {
    return StickerCollection(
      id: json['id'] as String,
      name: json['name'] as String? ?? '未命名合集',
      coverPath: json['coverPath'] as String?,
      stickerPaths:
          (json['stickerPaths'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// 返回用于展示/发送的路径（ImageUtils/createImageProvider 约定的 ./ 前缀格式）
  String displayPath(String storagePath) => './$storagePath';
}
