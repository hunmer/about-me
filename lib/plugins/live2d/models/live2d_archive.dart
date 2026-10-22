import 'package:uuid/uuid.dart';

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
  Live2DTapPart(id: 'leg', label: '腿部', keywords: ['leg', 'foot', 'feet', '腿', '脚']),
  Live2DTapPart(id: 'miss', label: '点空', keywords: []),
];

/// Live2D 存档：只保存 Agent 的 id，使用时经 [AgentController.getAgent]
/// 按 id 读取最新配置，避免存档里残留过期的 Agent 快照
class Live2DArchive {
  Live2DArchive({required this.id, required this.name, required this.modelLabel, required this.modelDir, required this.modelFile, required this.agentId, this.coverPath, this.tapMessagesEnabled = false, Map<String, String>? tapMessages}) : tapMessages = tapMessages ?? {};
  final String id;
  String name;
  String modelLabel;
  String modelDir;
  String modelFile;
  String? agentId;
  String? coverPath;

  /// 点击台词总开关：开启后点击气泡优先使用 [tapMessages] 中的自定义台词
  bool tapMessagesEnabled;

  /// 点击台词：部位 id（见 [live2DTapParts]）-> 多行文本，每行一条随机台词
  Map<String, String> tapMessages;

  /// 解析 [partId] 部位的自定义台词（按行拆分并过滤空行）
  List<String> tapMessageList(String partId) => (tapMessages[partId] ?? '')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  factory Live2DArchive.create({required String modelLabel, required String modelDir, required String modelFile, String? agentId}) => Live2DArchive(id: const Uuid().v4(), name: '新 Live2D', modelLabel: modelLabel, modelDir: modelDir, modelFile: modelFile, agentId: agentId);
  factory Live2DArchive.fromJson(Map<String, dynamic> json) => Live2DArchive(
    id: json['id'] as String? ?? const Uuid().v4(),
    name: json['name'] as String? ?? 'Live2D',
    modelLabel: json['modelLabel'] as String? ?? '',
    modelDir: json['modelDir'] as String? ?? '',
    modelFile: json['modelFile'] as String? ?? '',
    agentId: json['agentId'] as String?,
    coverPath: json['coverPath'] as String?,
    tapMessagesEnabled: json['tapMessagesEnabled'] as bool? ?? false,
    tapMessages:
        (json['tapMessages'] as Map<String, dynamic>?)
            ?.map((key, value) => MapEntry(key, value as String)) ??
        {},
  );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'modelLabel': modelLabel, 'modelDir': modelDir, 'modelFile': modelFile, 'agentId': agentId, 'coverPath': coverPath, 'tapMessagesEnabled': tapMessagesEnabled, 'tapMessages': tapMessages};
}
