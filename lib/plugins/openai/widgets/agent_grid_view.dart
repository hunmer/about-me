import 'package:flutter/material.dart';
import 'package:aboutme/core/services/hand_drawn_style_controller.dart';
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
    // 贴条开关联动出血边距(与 HandDrawnListView 行为一致)
    return ListenableBuilder(
      listenable: HandDrawnStyleController(),
      builder: (context, _) => GridView.builder(
        padding: EdgeInsets.fromLTRB(
          8,
          // 首行贴条上半出血,不预留会被视口顶部裁剪
          8 + stickyTapeBleed(),
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
      ),
    );
  }
}
