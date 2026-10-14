import 'package:flutter/material.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'agent_list_item.dart';

class AgentListView extends StatelessWidget {
  final List<AIAgent> agents;

  const AgentListView({
    super.key,
    required this.agents,
  });

  @override
  Widget build(BuildContext context) {
    // 手绘便签:随机倾斜 + 贴条(角度由 agent.id 哈希确定);
    // item 自带 vertical 4×2 间距,补 8px separator 至 16px 避免贴条压盖
    return HandDrawnListView(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: agents.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      tiltKeyOf: (index) => agents[index].id,
      itemBuilder: (context, index) {
        return AgentListItem(agent: agents[index]);
      },
    );
  }
}
