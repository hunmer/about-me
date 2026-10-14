import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/screens/agent_edit_screen.dart';

/// 商场 Agent 卡片
/// 在基础 AgentCard 的基础上增加安装状态显示
class MarketplaceAgentCard extends StatefulWidget {
  final AIAgent agent;
  final bool isInstalled;
  final bool hasUpdate;
  final VoidCallback? onAgentChanged; // 安装/更新后的回调

  const MarketplaceAgentCard({
    super.key,
    required this.agent,
    this.isInstalled = false,
    this.hasUpdate = false,
    this.onAgentChanged,
  });

  @override
  State<MarketplaceAgentCard> createState() => _MarketplaceAgentCardState();
}

class _MarketplaceAgentCardState extends State<MarketplaceAgentCard> {
  final GlobalKey _cardKey = GlobalKey();

  AIAgent get agent => widget.agent;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    // 环境描画动画（外层 WiredDraw 注入）；null = 已画完
    final drawProgress = WiredDrawTransition.progressOf(context);
    // Material 壳为 Hero 动画源(经 openContainerWithHero),保留结构
    return Material(
      key: _cardKey,
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () async {
          final result = await NavigationHelper.openContainerWithHero(
            context,
            (context) => AgentEditScreen(
              agent: agent,
              // 传递是否来自商场的标识
              isFromMarketplace: true,
            ),
            sourceKey: _cardKey,
            heroTag: 'marketplace_agent_card_${agent.id}',
          );

          // 如果安装成功，通知父组件刷新
          if (result == true && widget.onAgentChanged != null) {
            widget.onAgentChanged!();
          }
        },
        child: JellyBox(
          color: theme.surface,
          radius: BorderRadius.circular(12),
          raised: false,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 竖版封面区 + 左下角名称 badge
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(child: _buildCover(drawProgress)),
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _buildNameBadge(theme, drawProgress),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Agent Info（服务商 + 标签）
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'openai_providerLabel'.trParams({
                            'provider': agent.serviceProviderId,
                          }),
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        _buildTags(theme),
                      ],
                    ),
                  ),
                ],
              ),

              // 安装状态标识
              if (widget.isInstalled || widget.hasUpdate)
                Positioned(top: 8, right: 8, child: _buildStatusBadge()),
            ],
          ),
        ),
      ),
    );
  }

  /// 左下角名称 badge：skribble 手绘纸底 + 墨线描边
  Widget _buildNameBadge(AppThemeData theme, Animation<double>? drawProgress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surface,
        radius: BorderRadius.circular(8),
        progress: drawProgress,
      ),
      child: Text(
        agent.name,
        style: DsTypography.body.copyWith(
          color: theme.text,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// 构建状态徽章
  Widget _buildStatusBadge() {
    final theme = DSThemeBridge.resolve(context);
    if (widget.hasUpdate) {
      return _statusBadge(
        background: theme.warning,
        foreground: theme.onWarning,
        icon: DsIconKind.refresh,
        label: 'openai_updateAvailable'.tr,
      );
    }

    if (widget.isInstalled) {
      return _statusBadge(
        background: theme.success,
        foreground: theme.onSuccess,
        icon: DsIconKind.check,
        label: 'openai_installed'.tr,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _statusBadge({
    required Color background,
    required Color foreground,
    required DsIconKind icon,
    required String label,
  }) {
    return JellyBox(
      color: background,
      radius: BorderRadius.circular(999),
      raised: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsIcon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: DsTypography.label.copyWith(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建竖版封面（avatarUrl 支持 assets / 网络 / 本地文件）
  Widget _buildCover(Animation<double>? drawProgress) {
    final avatarUrl = agent.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      Widget errorBuilder(
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) => _buildCoverFallback();
      if (avatarUrl.startsWith('assets/')) {
        return _clipCover(
          Image.asset(
            avatarUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: errorBuilder,
          ),
          drawProgress,
        );
      }
      if (avatarUrl.startsWith('http')) {
        return _clipCover(
          Image.network(
            avatarUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: errorBuilder,
          ),
          drawProgress,
        );
      }
      return FutureBuilder<String>(
        future: ImageUtils.getAbsolutePath(avatarUrl),
        builder: (context, snapshot) {
          final path = snapshot.data;
          if (snapshot.hasData && path != null && path.isNotEmpty) {
            return _clipCover(
              Image.file(
                File(path),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: errorBuilder,
              ),
              drawProgress,
            );
          }
          return _buildCoverFallback();
        },
      );
    }

    return _buildCoverFallback();
  }

  Widget _clipCover(Widget child, Animation<double>? drawProgress) {
    final theme = DSThemeBridge.resolve(context);
    final radius = const BorderRadius.vertical(top: Radius.circular(11));
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(borderRadius: radius, child: child),
        // 图片墨线描边覆盖层（无填充，只画手绘边框）
        IgnorePointer(
          child: Container(
            decoration: dsSketchDecoration(
              theme: theme,
              radius: radius,
              progress: drawProgress,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverFallback() {
    final theme = DSThemeBridge.resolve(context);
    final color =
        agent.iconColor ??
        _getColorForServiceProvider(theme, agent.serviceProviderId);
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: color.withValues(alpha: 0.15),
      child: Center(
        child: agent.icon != null
            ? Icon(agent.icon, size: 48, color: color)
            : DsIcon(DsIconKind.bot, size: 48, color: color),
      ),
    );
  }

  /// 根据服务商 ID 取主题语义色（不硬编码色值，随主题/深浅模式联动）
  Color _getColorForServiceProvider(AppThemeData theme, String providerId) {
    switch (providerId) {
      case 'openai':
        return theme.success;
      case 'azure':
        return theme.primary;
      case 'ollama':
        return theme.warning;
      case 'deepseek':
        return theme.secondary;
      default:
        return theme.textSub;
    }
  }

  Widget _buildTags(AppThemeData theme) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: agent.tags.take(2).map((tag) {
        return DSBadge(label: tag, autoColor: true, fontSize: 10);
      }).toList(),
    );
  }
}
