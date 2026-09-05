import 'package:uuid/uuid.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';

class Live2DArchive {
  Live2DArchive({required this.id, required this.name, required this.modelLabel, required this.modelDir, required this.modelFile, required this.agentId, this.personality = const []});
  final String id;
  String name;
  String modelLabel;
  String modelDir;
  String modelFile;
  String? agentId;
  List<Prompt> personality;

  factory Live2DArchive.create({required String modelLabel, required String modelDir, required String modelFile, String? agentId}) => Live2DArchive(id: const Uuid().v4(), name: '新 Live2D', modelLabel: modelLabel, modelDir: modelDir, modelFile: modelFile, agentId: agentId);
  factory Live2DArchive.fromJson(Map<String, dynamic> json) => Live2DArchive(id: json['id'] as String? ?? const Uuid().v4(), name: json['name'] as String? ?? 'Live2D', modelLabel: json['modelLabel'] as String? ?? '', modelDir: json['modelDir'] as String? ?? '', modelFile: json['modelFile'] as String? ?? '', agentId: json['agentId'] as String?, personality: (json['personality'] as List<dynamic>?)?.map((e) => Prompt.fromJson(Map<String, dynamic>.from(e as Map))).toList() ?? const []);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'modelLabel': modelLabel, 'modelDir': modelDir, 'modelFile': modelFile, 'agentId': agentId, 'personality': personality.map((p) => p.toJson()).toList()};
}
