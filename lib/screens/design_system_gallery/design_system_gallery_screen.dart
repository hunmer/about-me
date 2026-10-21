import 'package:flutter/widgets.dart';
import 'package:aboutme/core/services/ds_theme_color_controller.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

import 'sections/buttons_section.dart';
import 'sections/controls_section.dart';
import 'sections/data_section.dart';
import 'sections/extended_section.dart';
import 'sections/feedback_section.dart';
import 'sections/gallery_section.dart';
import 'sections/inputs_section.dart';
import 'sections/navigation_section.dart';
import 'sections/pickers_section.dart';

/// 手绘风设计系统组件展示页
///
/// 布局：顶栏（含深浅切换）+ 分类导航条（DSChipBar，吃自己狗粮）
/// + 内容区一次只渲染当前分类的组件示例，切换时淡入并回到顶部。
///
/// 路由：/design_system
class DesignSystemGalleryScreen extends StatefulWidget {
  const DesignSystemGalleryScreen({super.key});

  @override
  State<DesignSystemGalleryScreen> createState() =>
      _DesignSystemGalleryScreenState();
}

class _DesignSystemGalleryScreenState extends State<DesignSystemGalleryScreen> {
  static const _categories = [
    '按钮', '输入', '选择器', '控件', '数据展示', '反馈浮层', '导航', '布局装饰', '令牌',
  ];

  bool _dark = false;
  int _category = 0;
  final _contentController = ScrollController();

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(theme),
              // 分类导航：横滑 chip 条，内容区只展示选中分类
              DSChipBar(
                labels: _categories,
                selected: _category,
                onChanged: (i) {
                  setState(() => _category = i);
                  // 切换分类后内容回到顶部
                  if (_contentController.hasClients) {
                    _contentController.jumpTo(0);
                  }
                },
              ),
              SizedBox(height: theme.spacing.md),
              Expanded(
                child: SingleChildScrollView(
                  controller: _contentController,
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.spacing.lg,
                    vertical: theme.spacing.sm,
                  ),
                  child: AnimatedSwitcher(
                    duration: DsMotion.fast,
                    switchInCurve: DsMotion.curve,
                    switchOutCurve: DsMotion.curve,
                    child: KeyedSubtree(
                      key: ValueKey(_category),
                      child: _buildCategory(_category),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategory(int index) => switch (index) {
    0 => const ButtonsSection(),
    1 => const InputsSection(),
    2 => const PickersSection(),
    3 => const ControlsSection(),
    4 => const DataSection(),
    5 => const FeedbackSection(),
    6 => const NavigationSection(),
    7 => const ExtendedSection(),
    _ => const _TokensSection(),
  };

  Widget _buildHeader(AppThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.md),
      child: Row(
        children: [
          Expanded(child: DSTopBar(title: '手绘风 组件库', onBack: null)),
          DsIcon(
            DsIconKind.moon,
            size: 16,
            color: _dark ? theme.warning : theme.textSub,
          ),
          SizedBox(width: theme.spacing.sm),
          // 深浅主题切换（用我们自己的 Switch，吃自己的狗粮）
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
    );
  }
}

/// 09 设计令牌色板卡（对应设计稿底部的 Design Tokens）
class _TokensSection extends StatelessWidget {
  const _TokensSection();

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
    return SectionCard(
      index: '09',
      title: '设计规范（Design Tokens）',
      children: [
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
                    ),
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Text(
                    name,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                ],
              ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        Text(
          '所有组件样式全部由 AppTheme 令牌驱动：手绘墨线（skribble）+ 语义色板'
          ' + 6 档笔型风格 + 8 套主题预设，仅依赖 flutter/widgets.dart。',
          style: DsTypography.caption.copyWith(color: theme.textSub),
        ),
      ],
    );
  }
}
