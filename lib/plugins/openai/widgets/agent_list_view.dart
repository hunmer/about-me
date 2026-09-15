import 'package:flutter/material.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'agent_list_item.dart';

class AgentListView extends StatelessWidget {
  final List<AIAgent> agents;

  const AgentListView({
    super.key,
    required this.agents,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: agents.length,
      itemBuilder: (context, index) {
        return AgentListItem(agent: agents[index]);
      },
    );
  }
}