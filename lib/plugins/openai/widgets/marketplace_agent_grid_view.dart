import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/services/agent_marketplace_service.dart';
import 'marketplace_agent_card.dart';

/// 商场 Agent 网格视图
class MarketplaceAgentGridView extends StatelessWidget {
  final List<AIAgent> marketplaceAgents;
  final List<AIAgent> localAgents;
  final VoidCallback? onAgentChanged;

  const MarketplaceAgentGridView({
    super.key,
    required this.marketplaceAgents,
    required this.localAgents,
    this.onAgentChanged,
  });

  @override
  Widget build(BuildContext context) {
    final marketplaceService = AgentMarketplaceService();

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: marketplaceAgents.length,
      itemBuilder: (context, index) {
        final agent = marketplaceAgents[index];
        final status = marketplaceService.getAgentStatus(agent, localAgents);

        // 挂载即播墨线描画入场（design.md §10）
        return WiredDraw(
          child: MarketplaceAgentCard(
            agent: agent,
            isInstalled: status['installed'] ?? false,
            hasUpdate: status['updateAvailable'] ?? false,
            onAgentChanged: onAgentChanged,
          ),
        );
      },
    );
  }
}
