/// 个人资料卡片小组件（手绘纸卡风格）
///
/// 手绘照片卡：背景照片核心视觉保留（渐变洗白遮罩改为纸色），
/// 外层 rough 墨线框描画入场（WiredDraw）；认证徽章 / 关注按钮 /
/// 统计图标全部手绘化，逐项错峰动画保留。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 个人资料卡片小组件
///
/// 用于展示用户个人信息，包括头像、姓名、简介、关注数等
class ProfileCardWidget extends StatefulWidget {
  /// 背景图片 URL
  final String imageUrl;

  /// 姓名
  final String name;

  /// 是否认证
  final bool isVerified;

  /// 简介
  final String bio;

  /// 粉丝数
  final int followersCount;

  /// 关注数
  final int followingCount;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const ProfileCardWidget({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.isVerified,
    required this.bio,
    required this.followersCount,
    required this.followingCount,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory ProfileCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return ProfileCardWidget(
      imageUrl: props['imageUrl'] as String? ?? '',
      name: props['name'] as String? ?? 'Unknown',
      isVerified: props['isVerified'] as bool? ?? false,
      bio: props['bio'] as String? ?? '',
      followersCount: (props['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (props['followingCount'] as num?)?.toInt() ?? 0,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<ProfileCardWidget> createState() => _ProfileCardWidgetState();
}

class _ProfileCardWidgetState extends State<ProfileCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleFollow() {
    setState(() {
      _isFollowing = !_isFollowing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final radius = BorderRadius.circular(24 * widget.size.scale);

    // 手绘照片卡：照片核心视觉保留，rough 墨线框画在照片之上
    // （foregroundDecoration），WiredDraw 提供描画入场环境
    return WiredDraw(
      child: Container(
        width: widget.inline ? double.maxFinite : double.infinity,
        height: widget.inline ? double.maxFinite : double.infinity,
        foregroundDecoration: dsSketchDecoration(
          theme: theme,
          radius: radius,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              // 背景图片
              Positioned.fill(
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(color: theme.surfaceAlt);
                  },
                ),
              ),
              // 渐变遮罩（纸色洗白，保证底部文字可读）
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        theme.surface.withValues(alpha: 0.9),
                      ],
                      stops: const [0.0, 0.3, 1.0],
                    ),
                  ),
                ),
              ),
              // 底部纸色叠加（内容区承托）
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: widget.size.getHeightConstraints().maxHeight * 0.4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.surface.withValues(alpha: 0.8),
                        theme.surface.withValues(alpha: 0.4),
                        theme.surface,
                      ],
                    ),
                  ),
                ),
              ),
              // 内容
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: widget.size.getPadding().copyWith(
                    top: widget.size.getPadding().top * 0.75,
                    bottom: widget.size.getPadding().bottom * 0.75,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 姓名和认证标志
                      _NameSection(
                        name: widget.name,
                        isVerified: widget.isVerified,
                        animation: _animation,
                        size: widget.size,
                      ),
                      SizedBox(height: widget.size.getTitleSpacing() * 0.5),
                      // 简介
                      _BioSection(
                        bio: widget.bio,
                        animation: _animation,
                        size: widget.size,
                      ),
                      SizedBox(height: widget.size.getItemSpacing() * 0.5),
                      // 统计和关注按钮
                      _StatsAndFollowSection(
                        followersCount: widget.followersCount,
                        followingCount: widget.followingCount,
                        isFollowing: _isFollowing,
                        onFollowPressed: _toggleFollow,
                        animation: _animation,
                        size: widget.size,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 姓名和认证标志部分
class _NameSection extends StatelessWidget {
  final String name;
  final bool isVerified;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _NameSection({
    required this.name,
    required this.isVerified,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final nameAnimation = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
        );

        return Opacity(
          opacity: nameAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - nameAnimation.value)),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: size.getTitleFontSize(),
                      fontWeight: FontWeight.w700,
                      color: theme.text,
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isVerified) ...[
                  SizedBox(width: size.getItemSpacing() * 0.375),
                  // 认证徽章：success 实底 + 墨线描边 + 手绘对勾
                  Container(
                    padding: EdgeInsets.all(size.getPadding().right * 0.125),
                    decoration: dsSketchDecoration(
                      theme: theme,
                      radius: BorderRadius.circular(size.getThumbnailIconSize()),
                      fillColor: theme.success,
                    ),
                    child: WiredIcon(
                      icon: Icons.verified,
                      size: size.getThumbnailIconSize(),
                      color: theme.onSuccess,
                      drawConfig: theme.wired.drawConfig,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 简介部分
class _BioSection extends StatelessWidget {
  final String bio;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _BioSection({
    required this.bio,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final bioAnimation = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
        );

        return Opacity(
          opacity: bioAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - bioAnimation.value)),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                bio,
                style: TextStyle(
                  fontSize: size.getSubtitleFontSize(),
                  fontWeight: FontWeight.w500,
                  color: theme.textSub,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 统计和关注按钮部分
class _StatsAndFollowSection extends StatelessWidget {
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final VoidCallback onFollowPressed;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _StatsAndFollowSection({
    required this.followersCount,
    required this.followingCount,
    required this.isFollowing,
    required this.onFollowPressed,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final statsAnimation = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.5, 0.9, curve: Curves.easeOutCubic),
        );

        return Opacity(
          opacity: statsAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - statsAnimation.value)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 统计数据
                Row(
                  children: [
                    _StatItem(
                      icon: Icons.person_outline,
                      count: followersCount,
                      animation: statsAnimation,
                      size: size,
                    ),
                    SizedBox(width: size.getItemSpacing()),
                    _StatItem(
                      icon: Icons.check_box_outline_blank,
                      count: followingCount,
                      animation: statsAnimation,
                      size: size,
                    ),
                  ],
                ),
                // 关注按钮：墨底 / surfaceAlt 底 + 墨线描边
                GestureDetector(
                  onTap: onFollowPressed,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.getPadding().right * 0.875,
                      vertical: size.getPadding().bottom * 0.375,
                    ),
                    decoration: dsSketchDecoration(
                      theme: theme,
                      radius: BorderRadius.circular(20),
                      fillColor: isFollowing ? theme.surfaceAlt : theme.ink,
                    ),
                    child: Row(
                      children: [
                        Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: TextStyle(
                            fontSize: size.getLegendFontSize(),
                            fontWeight: FontWeight.w600,
                            color: isFollowing ? theme.text : theme.surface,
                          ),
                        ),
                        if (!isFollowing) ...[
                          SizedBox(width: size.getPadding().right * 0.1875),
                          DsIcon(
                            DsIconKind.plus,
                            size: size.getThumbnailIconSize(),
                            color: theme.surface,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 统计项
class _StatItem extends StatelessWidget {
  final IconData icon;
  final int count;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _StatItem({
    required this.icon,
    required this.count,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Row(
      children: [
        WiredIcon(
          icon: icon,
          size: size.getThumbnailIconSize(),
          color: theme.textSub,
          drawConfig: theme.wired.drawConfig,
        ),
        SizedBox(width: size.getPadding().right * 0.25),
        AnimatedFlipCounter(
          value: count.toDouble() * animation.value,
          fractionDigits: 0,
          duration: const Duration(milliseconds: 600),
          textStyle: TextStyle(
            fontSize: size.getSubtitleFontSize(),
            fontWeight: FontWeight.w600,
            color: theme.textSub,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}
