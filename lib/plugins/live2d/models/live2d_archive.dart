import 'package:uuid/uuid.dart';
import '../video/video_pet_manifest.dart';

/// 档案中的模型原生 HitArea 或手动定义矩形区域。
class Live2DTapRegion {
  const Live2DTapRegion({
    required this.id,
    required this.name,
    this.source = 'model',
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.messages = const [],
  });

  final String id;
  final String name;

  /// `model` 由原生 Live2D HitArea 命中，`custom` 由归一化矩形命中。
  final String source;
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final List<String> messages;

  bool get hasBounds =>
      left != null && top != null && right != null && bottom != null;

  /// 几何坐标使用 0..1，原点在模型视口左上角，右侧和下侧不含。
  bool containsNormalizedPoint(double x, double y) =>
      source == 'custom' &&
      hasBounds &&
      x >= left! &&
      x < right! &&
      y >= top! &&
      y < bottom!;

  List<String> get effectiveMessages => messages
      .map((message) => message.trim())
      .where((message) => message.isNotEmpty)
      .toList();

  factory Live2DTapRegion.fromJson(Map<String, dynamic> json) {
    double? number(String key) => (json[key] as num?)?.toDouble();

    return Live2DTapRegion(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      source: json['source'] as String? ?? 'model',
      left: number('left'),
      top: number('top'),
      right: number('right'),
      bottom: number('bottom'),
      messages:
          (json['messages'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'source': source,
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
    'messages': messages,
  };
}

/// 点击台词的常见部位：id 用于存档持久化，label 为表单展示文案，
/// keywords 匹配模型 HitArea 的 Id/Name（转小写后包含匹配）；
/// miss 为未命中任何区域的点空，不参与关键词匹配
class Live2DTapPart {
  const Live2DTapPart({
    required this.id,
    required this.label,
    required this.keywords,
  });

  final String id;
  final String label;
  final List<String> keywords;
}

const List<Live2DTapPart> live2DTapParts = [
  Live2DTapPart(id: 'head', label: '头部', keywords: ['head', '头']),
  Live2DTapPart(id: 'face', label: '脸部', keywords: ['face', '脸']),
  Live2DTapPart(id: 'body', label: '身体', keywords: ['body', '身', 'belly', '胸']),
  Live2DTapPart(id: 'hand', label: '手部', keywords: ['hand', 'arm', '手', '臂']),
  Live2DTapPart(
    id: 'leg',
    label: '腿部',
    keywords: ['leg', 'foot', 'feet', '腿', '脚'],
  ),
  Live2DTapPart(id: 'miss', label: '点空', keywords: []),
];

/// Live2D 存档：只保存 Agent 的 id，使用时经 [AgentController.getAgent]
/// 按 id 读取最新配置，避免存档里残留过期的 Agent 快照
class Live2DArchive {
  Live2DArchive({
    required this.id,
    required this.name,
    required this.modelLabel,
    required this.modelDir,
    required this.modelFile,
    required this.agentId,
    this.coverPath,
    this.note = '',
    this.jevEnabled = false,
    this.tapMessagesEnabled = false,
    this.randomWalkEnabled = false,
    this.displayMode = 'live2d',
    this.videoManifest,
    this.videoBaseUri = 'assets/live2d/video/dsh_pet/',
    this.videoResolvedSources = const {},
    Map<String, String>? tapMessages,
    this.tapRegions = const [],
  }) : tapMessages = tapMessages ?? {};
  final String id;
  String name;
  String modelLabel;
  String modelDir;
  String modelFile;
  String? agentId;
  String? coverPath;
  String note;
  bool jevEnabled;
  String displayMode;
  VideoPetManifest? videoManifest;
  String videoBaseUri;
  Map<String, String> videoResolvedSources;

  bool get isVideo => displayMode == 'video';
  String get displayModelLabel =>
      isVideo ? videoManifest?.name ?? 'Video' : modelLabel;

  /// 点击台词总开关：开启后点击气泡优先使用 [tapMessages] 中的自定义台词
  bool tapMessagesEnabled;

  /// 随机走动开关（仅视频档案生效）：开启后桌宠在小屋内随机等待并水平走动
  bool randomWalkEnabled;

  /// 点击台词：部位 id（见 [live2DTapParts]）-> 多行文本，每行一条随机台词
  Map<String, String> tapMessages;

  /// 档案级区域；旧版 [tapMessages] 继续保留作为兼容回退。
  List<Live2DTapRegion> tapRegions;

  Live2DTapRegion? tapRegionForHitArea(String? hitAreaId, String? hitAreaName) {
    final id = hitAreaId?.trim().toLowerCase();
    final name = hitAreaName?.trim().toLowerCase();
    if ((id == null || id.isEmpty) && (name == null || name.isEmpty)) {
      return null;
    }
    return tapRegions.where((region) {
      if (region.source != 'model') return false;
      return (id != null && id.isNotEmpty && region.id.toLowerCase() == id) ||
          (name != null &&
              name.isNotEmpty &&
              region.name.trim().toLowerCase() == name);
    }).firstOrNull;
  }

  Live2DTapRegion? tapRegionAt(double normalizedX, double normalizedY) =>
      tapRegions
          .where(
            (region) =>
                region.containsNormalizedPoint(normalizedX, normalizedY),
          )
          .firstOrNull;

  /// 解析 [partId] 部位的自定义台词（按行拆分并过滤空行）
  List<String> tapMessageList(String partId) => (tapMessages[partId] ?? '')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  factory Live2DArchive.create({
    required String modelLabel,
    required String modelDir,
    required String modelFile,
    String? agentId,
  }) => Live2DArchive(
    id: const Uuid().v4(),
    name: '新 Live2D',
    modelLabel: modelLabel,
    modelDir: modelDir,
    modelFile: modelFile,
    agentId: agentId,
  );
  factory Live2DArchive.fromJson(Map<String, dynamic> json) => Live2DArchive(
    id: json['id'] as String? ?? const Uuid().v4(),
    name: json['name'] as String? ?? 'Live2D',
    modelLabel: json['modelLabel'] as String? ?? '',
    modelDir: json['modelDir'] as String? ?? '',
    modelFile: json['modelFile'] as String? ?? '',
    agentId: json['agentId'] as String?,
    coverPath: json['coverPath'] as String?,
    note: json['note'] as String? ?? '',
    jevEnabled: json['jevEnabled'] as bool? ?? false,
    displayMode: json['displayMode'] == 'video' ? 'video' : 'live2d',
    videoManifest: json['videoManifest'] is Map
        ? VideoPetManifest.fromJson(
            Map<String, dynamic>.from(json['videoManifest'] as Map),
          )
        : null,
    videoBaseUri:
        json['videoBaseUri'] as String? ?? 'assets/live2d/video/dsh_pet/',
    videoResolvedSources:
        (json['videoResolvedSources'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ) ??
        {},
    tapMessagesEnabled: json['tapMessagesEnabled'] as bool? ?? false,
    randomWalkEnabled: json['randomWalkEnabled'] as bool? ?? false,
    tapMessages:
        (json['tapMessages'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value as String),
        ) ??
        {},
    tapRegions:
        (json['tapRegions'] as List?)
            ?.whereType<Map>()
            .map(
              (region) =>
                  Live2DTapRegion.fromJson(Map<String, dynamic>.from(region)),
            )
            .toList() ??
        const [],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'modelLabel': modelLabel,
    'modelDir': modelDir,
    'modelFile': modelFile,
    'agentId': agentId,
    'coverPath': coverPath,
    'note': note,
    'jevEnabled': jevEnabled,
    'displayMode': displayMode,
    'videoManifest': videoManifest?.toJson(),
    'videoBaseUri': videoBaseUri,
    'videoResolvedSources': videoResolvedSources,
    'tapMessagesEnabled': tapMessagesEnabled,
    'randomWalkEnabled': randomWalkEnabled,
    'tapMessages': tapMessages,
    'tapRegions': tapRegions.map((region) => region.toJson()).toList(),
  };
}
