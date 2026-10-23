/// 不包含平台路径的不可变资源描述。
class AssetDto {
  const AssetDto({required this.id, required this.fileName,
    required this.mediaType, required this.size, required this.sha256,
    required this.createdAt});
  final String id;
  final String fileName;
  final String mediaType;
  final int size;
  final String sha256;
  final String createdAt;
  String get reference => 'asset://$id';

  factory AssetDto.fromJson(Map<String, dynamic> json) => AssetDto(
    id: json['id'] as String, fileName: json['fileName'] as String,
    mediaType: json['mediaType'] as String, size: json['size'] as int,
    sha256: json['sha256'] as String, createdAt: json['createdAt'] as String);
  Map<String, dynamic> toJson() => {'id': id, 'fileName': fileName,
    'mediaType': mediaType, 'size': size, 'sha256': sha256, 'createdAt': createdAt};
}
