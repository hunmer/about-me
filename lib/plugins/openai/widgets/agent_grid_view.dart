import 'package:flutter/material.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
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
        mainAxisSpacing: 8,
      ),
      itemCount: agents.length,
      itemBuilder: (context, index) {
        return AgentCard(agent: agents[index]);
      },
    );
  }
}