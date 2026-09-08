import 'package:uuid/uuid.dart';

/// Live2D 存档：只保存 Agent 的 id，使用时经 [AgentController.getAgent]
/// 按 id 读取最新配置，避免存档里残留过期的 Agent 快照
class Live2DArchive {
  Live2DArchive({required this.id, required this.name, required this.modelLabel, required this.modelDir, required this.modelFile, required this.agentId, this.coverPath});
  final String id;
  String name;
  String modelLabel;
  String modelDir;
  String modelFile;
  String? agentId;
  String? coverPath;

  factory Live2DArchive.create({required String modelLabel, required String modelDir, required String modelFile, String? agentId}) => Live2DArchive(id: const Uuid().v4(), name: '新 Live2D', modelLabel: modelLabel, modelDir: modelDir, modelFile: modelFile, agentId: agentId);
  factory Live2DArchive.fromJson(Map<String, dynamic> json) => Live2DArchive(id: json['id'] as String? ?? const Uuid().v4(), name: json['name'] as String? ?? 'Live2D', modelLabel: json['modelLabel'] as String? ?? '', modelDir: json['modelDir'] as String? ?? '', modelFile: json['modelFile'] as String? ?? '', agentId: json['agentId'] as String?, coverPath: json['coverPath'] as String?);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'modelLabel': modelLabel, 'modelDir': modelDir, 'modelFile': modelFile, 'agentId': agentId, 'coverPath': coverPath};
}
