import 'package:flutter/material.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'agent_card.dart';

class AgentGridView extends StatelessWidget {
  final List<AIAgent> agents;

  const AgentGridView({
    super.key,
    required this.agents,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 8,
        // ≥ 贴条出血,避免上一行贴条压盖
        mainAxisSpacing: 16,
      ),
      itemCount: agents.length,
      itemBuilder: (context, index) {
        // 手绘便签:随机倾斜 + 贴条(角度由 agent.id 哈希确定)
        return HandDrawnStickyItem(
          tiltKey: agents[index].id,
          child: AgentCard(agent: agents[index]),
        );
      },
    );
  }
}
