import 'package:agentlib/agent_slots.dart';

/// 全局 AgentLib 资源插槽。
/// 当前仅保存配置边界，具体 skills/MCP 注册与发现留待后续实现。
class AgentLibResourceService {
  static AgentResourceSlots globalSlots = const AgentResourceSlots();

  static AgentResourceSlots fromSettings(Map<String, dynamic> settings) {
    return AgentResourceSlots.fromJson(
      settings['agentlibResourceSlots'] as Map<String, dynamic>?,
    );
  }

  static Map<String, dynamic> toSettings(AgentResourceSlots slots) => {
    'agentlibResourceSlots': slots.toJson(),
  };
}
