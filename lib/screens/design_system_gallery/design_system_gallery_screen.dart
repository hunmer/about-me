import 'package:flutter/widgets.dart';
import 'package:aboutme/core/services/ds_theme_color_controller.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

import 'sections/buttons_section.dart';
import 'sections/controls_section.dart';
import 'sections/data_section.dart';
import 'sections/extended_section.dart';
import 'sections/feedback_section.dart';
import 'sections/inputs_section.dart';
import 'sections/navigation_section.dart';
import 'sections/pickers_section.dart';

/// 手绘风设计系统组件展示页
///
/// 路由：/design_system
class DesignSystemGalleryScreen extends StatefulWidget {
  const DesignSystemGalleryScreen({super.key});

  @override
  State<DesignSystemGalleryScreen> createState() =>
      _DesignSystemGalleryScreenState();
}

class _DesignSystemGalleryScreenState extends State<DesignSystemGalleryScreen> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    // 展示页自带主题切换，不影响全局（颜色跟随当前主题色板）
    final theme = AppThemeData.fromPalette(
      DsThemeColorController().palette,
      isDark: _dark,
    );

    return AppTheme(
      data: theme,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.backgroundAlt, theme.background],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.lg,
              vertical: theme.spacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(theme),
                SizedBox(height: theme.spacing.xl),
                const ButtonsSection(),
                SizedBox(height: theme.spacing.lg),
                const ControlsSection(),
                SizedBox(height: theme.spacing.lg),
                const InputsSection(),
                SizedBox(height: theme.spacing.lg),
                const PickersSection(),
                SizedBox(height: theme.spacing.lg),
                const DataSection(),
                SizedBox(height: theme.spacing.lg),
                const FeedbackSection(),
                SizedBox(height: theme.spacing.lg),
                const NavigationSection(),
                SizedBox(height: theme.spacing.lg),
                const ExtendedSection(),
                SizedBox(height: theme.spacing.lg),
                const _TokensCard(),
                SizedBox(height: theme.spacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DSTopBar(title: '手绘风 组件库'),
        SizedBox(height: theme.spacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final c in [
              theme.warning,
              theme.secondary,
              theme.primary,
              theme.secondary,
              theme.warning,
            ])
              Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
                child: DsIcon(DsIconKind.star, size: 14, color: c),
              ),
          ],
        ),
        SizedBox(height: theme.spacing.sm),
        Text(
          '手绘风 游戏 UI 组件库',
          textAlign: TextAlign.center,
          style: DsTypography.display.copyWith(color: theme.text),
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          'claymorphism 立体质感 · 圆润可爱 · 轻松治愈',
          textAlign: TextAlign.center,
          style: DsTypography.caption.copyWith(color: theme.textSub),
        ),
        SizedBox(height: theme.spacing.md),
        // 深浅主题切换（用我们自己的 Switch，吃自己的狗粮）
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DsIcon(
              DsIconKind.moon,
              size: 16,
              color: _dark ? theme.warning : theme.textSub,
            ),
            SizedBox(width: theme.spacing.sm),
            DSSwitch(
              value: _dark,
              activeColor: theme.primary,
              onChanged: (v) => setState(() => _dark = v),
            ),
            SizedBox(width: theme.spacing.sm),
            DsIcon(
              DsIconKind.sun,
              size: 16,
              color: !_dark ? theme.warning : theme.textSub,
            ),
          ],
        ),
      ],
    );
  }
}

/// 设计令牌色板卡（对应设计稿底部的 Design Tokens）
class _TokensCard extends StatelessWidget {
  const _TokensCard();

  static const _swatches = <(String, Color)>[
    ('主色', Color(0xFF885CF6)),
    ('辅助色', Color(0xFFF5A8D4)),
    ('成功', Color(0xFF6EE7B7)),
    ('警告', Color(0xFFFCD34D)),
    ('危险', Color(0xFFF87185)),
    ('背景', Color(0xFFFDF7FF)),
    ('文字', Color(0xFF4C1D95)),
    ('次要文字', Color(0xFFA78BFA)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return DSCard(
      radius: theme.radii.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsIcon(DsIconKind.star, size: 16, color: theme.primary),
              SizedBox(width: theme.spacing.sm),
              Text(
                '设计规范（Design Tokens）',
                style: DsTypography.title.copyWith(color: theme.text),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.lg),
          Wrap(
            spacing: theme.spacing.md,
            runSpacing: theme.spacing.md,
            children: [
              for (final (name, color) in _swatches)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.stroke, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: theme.spacing.sm),
                    Text(
                      name,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          Text(
            '所有组件均采用：果冻/软陶质感、大圆角、顶部高光、白色描边、深色条纹和投影。'
            '样式全部由 AppTheme 令牌驱动，仅依赖 flutter/widgets.dart。',
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ],
      ),
    );
  }
}
