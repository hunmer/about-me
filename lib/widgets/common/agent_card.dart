import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'package:aboutme/widgets/arc_context_menu.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// Agent 卡片组件（公共小组件版本）
///
/// 用于在主页小组件系统中展示 AI 助手信息
class AgentCardWidget extends StatefulWidget {
  /// Agent 名称
  final String name;

  /// Agent 描述
  final String description;

  /// 服务商 ID
  final String serviceProviderId;

  /// 标签列表
  final List<String> tags;

  /// 头像 URL
  final String? avatarUrl;

  /// 图标（IconData 的 codePoint）
  final int? iconCodePoint;

  /// 图标颜色
  final int? iconColorValue;

  /// 小组件尺寸（用于响应式布局）
  final HomeWidgetSize? size;

  /// 点击回调（用于导航到详情页）
  final VoidCallback? onTap;

  /// 长按回调（用于显示操作菜单）
  final VoidCallback? onLongPress;

  /// 长按圆盘菜单项（传入时替代 [onLongPress]，
  /// 与 [onMore]（"更多"弹底部 sheet）配套）
  final List<ArcMenuItem>? arcActions;
  final VoidCallback? onMore;

  const AgentCardWidget({
    super.key,
    required this.name,
    required this.description,
    required this.serviceProviderId,
    required this.tags,
    this.avatarUrl,
    this.iconCodePoint,
    this.iconColorValue,
    this.size,
    this.onTap,
    this.onLongPress,
    this.arcActions,
    this.onMore,
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory AgentCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return AgentCardWidget(
      name: props['name'] as String? ?? '',
      description: props['description'] as String? ?? '',
      serviceProviderId: props['serviceProviderId'] as String? ?? 'openai',
      tags: (props['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      avatarUrl: props['avatarUrl'] as String?,
      iconCodePoint: props['iconCodePoint'] as int?,
      iconColorValue: props['iconColorValue'] as int?,
      size: size,
      onTap: props['onTap'] as VoidCallback?,
      onLongPress: props['onLongPress'] as VoidCallback?,
    );
  }

  @override
  State<AgentCardWidget> createState() => _AgentCardWidgetState();
}

class _AgentCardWidgetState extends State<AgentCardWidget> {
  final GlobalKey _cardKey = GlobalKey();

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

  /// 根据尺寸获取字体大小
  double _getTitleFontSize(HomeWidgetSize size) {
    switch (size.category) {
      case SizeCategory.mini:
        return 10.0;
      case SizeCategory.small:
        return 12.0;
      case SizeCategory.medium:
        return 14.0;
      case SizeCategory.large:
      case SizeCategory.xlarge:
        return 16.0;
    }
  }

  /// 根据尺寸获取副标题字体大小
  double _getSubtitleFontSize(HomeWidgetSize size) {
    switch (size.category) {
      case SizeCategory.mini:
        return 8.0;
      case SizeCategory.small:
        return 10.0;
      case SizeCategory.medium:
        return 11.0;
      case SizeCategory.large:
      case SizeCategory.xlarge:
        return 12.0;
    }
  }

  /// 根据尺寸获取内边距
  double _getPadding(HomeWidgetSize size) {
    switch (size.category) {
      case SizeCategory.mini:
        return 4.0;
      case SizeCategory.small:
        return 6.0;
      case SizeCategory.medium:
        return 8.0;
      case SizeCategory.large:
      case SizeCategory.xlarge:
        return 8.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    // 使用传入的尺寸，默认 large
    final size = widget.size ?? HomeWidgetSize.large;
    final effectiveColor = widget.iconColorValue != null
        ? Color(widget.iconColorValue!)
        : _getColorForServiceProvider(theme, widget.serviceProviderId);

    // Material 壳为 Hero 动画源(经 openContainerWithHero),手绘外观交给 JellyBox
    Widget card = Material(
      key: _cardKey,
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onTap,
        // 圆盘菜单接管长按时不再注册，避免手势竞争
        onLongPress:
            widget.arcActions != null ? null : widget.onLongPress,
        child: JellyBox(
          color: theme.surface,
          radius: BorderRadius.circular(12),
          raised: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Agent 封面（竖版通栏 + 左下角名称 badge）
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: _buildAgentIcon(theme, effectiveColor, size),
                    ),
                    Positioned(
                      left: _getPadding(size),
                      right: _getPadding(size),
                      bottom: _getPadding(size),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildNameBadge(theme, size),
                      ),
                    ),
                  ],
                ),
              ),

              // Agent Info（服务商 + 标签）
              Padding(
                padding: EdgeInsets.all(_getPadding(size)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'app_provider'.tr}: ${widget.serviceProviderId}',
                      style: TextStyle(
                        fontSize: _getSubtitleFontSize(size),
                        color: theme.textSub,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    _buildTags(theme, size),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final actions = widget.arcActions;
    if (actions == null) return card;
    return ArcContextMenu.actions(
      actions: actions,
      showMore: () => widget.onMore?.call(),
      child: card,
    );
  }

  /// 左下角名称 badge：skribble 手绘纸底 + 墨线描边
  Widget _buildNameBadge(AppThemeData theme, HomeWidgetSize size) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surface,
        radius: BorderRadius.circular(8),
      ),
      child: Text(
        widget.name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: _getTitleFontSize(size),
          color: theme.text,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildAgentIcon(
    AppThemeData theme,
    Color effectiveColor,
    HomeWidgetSize size,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableSize = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;

        // 如果有封面，优先显示（竖版通栏，含 assets/ 网络与本地路径）
        if (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty) {
          final radius = const BorderRadius.vertical(top: Radius.circular(11));
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: radius,
                child: AdaptiveImage(
                  imagePath: widget.avatarUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              // 图片墨线描边覆盖层（无填充，只画手绘边框）
              IgnorePointer(
                child: Container(
                  decoration: dsSketchDecoration(
                    theme: theme,
                    radius: radius,
                  ),
                ),
              ),
            ],
          );
        }

        // 如果有自定义图标，手绘底 + 主题色图标
        if (widget.iconCodePoint != null) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: dsSketchDecoration(
              theme: theme,
              fillColor: effectiveColor,
              radius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                dynamicIconData(
                  widget.iconCodePoint!,
                  fontFamily: 'MaterialIcons',
                ),
                size: availableSize * 0.5,
                color: theme.surface,
              ),
            ),
          );
        }

        // 默认图标
        return _buildDefaultIcon(theme, effectiveColor, availableSize);
      },
    );
  }

  Widget _buildDefaultIcon(
    AppThemeData theme,
    Color effectiveColor,
    double availableSize,
  ) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: effectiveColor,
        radius: BorderRadius.circular(12),
      ),
      child: Center(
        child: DsIcon(
          DsIconKind.bot,
          size: availableSize * 0.5,
          color: theme.surface,
        ),
      ),
    );
  }

  Widget _buildTags(AppThemeData theme, HomeWidgetSize size) {
    final tagCount = size.category == SizeCategory.mini ? 1 : 2;
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: widget.tags.take(tagCount).map((tag) {
        return DSBadge(
          label: tag,
          autoColor: true,
          fontSize: _getSubtitleFontSize(size) - 2,
        );
      }).toList(),
    );
  }
}

/// AgentCardData 数据模型（用于 JSON 序列化）
class AgentCardData {
  final String name;
  final String description;
  final String serviceProviderId;
  final List<String> tags;
  final String? avatarUrl;
  final int? iconCodePoint;
  final int? iconColorValue;
  final int? sizeWidth;
  final int? sizeHeight;

  const AgentCardData({
    required this.name,
    required this.description,
    required this.serviceProviderId,
    required this.tags,
    this.avatarUrl,
    this.iconCodePoint,
    this.iconColorValue,
    this.sizeWidth,
    this.sizeHeight,
  });

  /// 获取 HomeWidgetSize
  HomeWidgetSize get size {
    if (sizeWidth != null && sizeHeight != null) {
      return HomeWidgetSize.fromSize(sizeWidth!, sizeHeight!);
    }
    return HomeWidgetSize.large;
  }

  /// 从 AIAgent 创建
  factory AgentCardData.fromAgent(AIAgent agent, {HomeWidgetSize? size}) {
    return AgentCardData(
      name: agent.name,
      description: agent.description,
      serviceProviderId: agent.serviceProviderId,
      tags: agent.tags,
      avatarUrl: agent.avatarUrl,
      iconCodePoint: agent.icon?.codePoint,
      iconColorValue: agent.iconColor?.value,
      sizeWidth: size?.width,
      sizeHeight: size?.height,
    );
  }

  /// 从 JSON 创建
  factory AgentCardData.fromJson(Map<String, dynamic> json) {
    return AgentCardData(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      serviceProviderId: json['serviceProviderId'] as String? ?? 'openai',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      avatarUrl: json['avatarUrl'] as String?,
      iconCodePoint: json['iconCodePoint'] as int?,
      iconColorValue: json['iconColorValue'] as int?,
      sizeWidth: json['sizeWidth'] as int?,
      sizeHeight: json['sizeHeight'] as int?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'serviceProviderId': serviceProviderId,
      'tags': tags,
      'avatarUrl': avatarUrl,
      'iconCodePoint': iconCodePoint,
      'iconColorValue': iconColorValue,
      'sizeWidth': sizeWidth,
      'sizeHeight': sizeHeight,
    };
  }
}
