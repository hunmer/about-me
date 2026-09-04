import 'dart:io';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/screens/agent_edit_screen.dart';

/// 商场 Agent 列表项
class MarketplaceAgentListItem extends StatelessWidget {
  final AIAgent agent;
  final bool isInstalled;
  final bool hasUpdate;
  final VoidCallback? onAgentChanged; // 安装/更新后的回调

  const MarketplaceAgentListItem({
    super.key,
    required this.agent,
    this.isInstalled = false,
    this.hasUpdate = false,
    this.onAgentChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DSCard(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm,
        ),
        onTap: () async {
          final result = await NavigationHelper.push(
            context,
            AgentEditScreen(agent: agent, isFromMarketplace: true),
          );

          // 如果安装成功，通知父组件刷新
          if (result == true && onAgentChanged != null) {
            onAgentChanged!();
          }
        },
        child: Row(
          children: [
            _buildAgentIcon(),
            SizedBox(width: theme.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          agent.name,
                          style: DsTypography.body.copyWith(
                            color: theme.text,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isInstalled || hasUpdate) _buildStatusBadge(context),
                    ],
                  ),
                  Text(
                    '服务商: ${agent.serviceProviderId}',
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                  const SizedBox(height: 4),
                  _buildTags(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建状态徽章
  Widget _buildStatusBadge(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    if (hasUpdate) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.warning,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsIcon(DsIconKind.refresh, size: 12, color: theme.onWarning),
            const SizedBox(width: 2),
            Text(
              '可更新',
              style: DsTypography.label.copyWith(
                color: theme.onWarning,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (isInstalled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.success,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsIcon(DsIconKind.check, size: 12, color: theme.onSuccess),
            const SizedBox(width: 2),
            Text(
              '已安装',
              style: DsTypography.label.copyWith(
                color: theme.onSuccess,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildAgentIcon() {
    // 如果有头像，优先显示头像
    if (agent.avatarUrl != null && agent.avatarUrl!.isNotEmpty) {
      return FutureBuilder<String>(
        future: ImageUtils.getAbsolutePath(agent.avatarUrl),
        builder: (context, snapshot) {
          return SizedBox(
            width: 40,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getColorForServiceProvider(
                    agent.serviceProviderId,
                  ).withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: ClipOval(
                    child:
                        agent.avatarUrl!.startsWith('http')
                            ? Image.network(
                              agent.avatarUrl!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) =>
                                      _buildDefaultIcon(),
                            )
                            : snapshot.hasData
                            ? Image.file(
                              File(snapshot.data!),
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) =>
                                      _buildDefaultIcon(),
                            )
                            : _buildDefaultIcon(),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // 如果有自定义图标，使用自定义图标
    if (agent.icon != null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              agent.iconColor ??
              _getColorForServiceProvider(agent.serviceProviderId),
        ),
        child: Icon(agent.icon, size: 24, color: Colors.white),
      );
    }

    // 默认图标
    return _buildDefaultIcon();
  }

  Widget _buildDefaultIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getColorForServiceProvider(agent.serviceProviderId),
      ),
      child: const Icon(Icons.smart_toy, size: 24, color: Colors.white),
    );
  }

  Color _getColorForServiceProvider(String providerId) {
    switch (providerId) {
      case 'openai':
        return Colors.green;
      case 'azure':
        return Colors.blue;
      case 'ollama':
        return Colors.orange;
      case 'deepseek':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTags(AppThemeData theme) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children:
          agent.tags.take(3).map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                tag,
                style: DsTypography.label.copyWith(
                  fontSize: 10,
                  color: theme.textSub,
                ),
              ),
            );
          }).toList(),
    );
  }
}
