import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart'
    show DSThemeBridge, dsScaffoldBackground;
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/onboarding/sample_data_selection_step.dart';

/// 插件首次打开引导页
///
/// 由 [PluginManager.openPlugin] 在插件首次打开时弹出，风格对齐
/// [OnboardingScreen]：PageView 多步骤（图标+标题+说明），
/// 步骤可通过 [PluginOnboardingStep.builder] 提供自定义内容
/// （如配置表单），收集的数据写入共享 values 并在完成时回传插件。
Future<void> showPluginOnboarding(
  BuildContext context, {
  required PluginBase plugin,
  required List<PluginOnboardingStep> steps,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PluginOnboardingScreen(plugin: plugin, steps: steps),
    ),
  );
}

class PluginOnboardingScreen extends StatefulWidget {
  const PluginOnboardingScreen({
    super.key,
    required this.plugin,
    required this.steps,
  });

  final PluginBase plugin;
  final List<PluginOnboardingStep> steps;

  @override
  State<PluginOnboardingScreen> createState() => _PluginOnboardingScreenState();
}

class _PluginOnboardingScreenState extends State<PluginOnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  /// 各自定义步骤共享的数据收集容器
  final Map<String, dynamic> _values = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index >= widget.steps.length - 1;

  Future<void> _finish() async {
    final plugin = widget.plugin;
    final values = Map<String, dynamic>.of(_values);
    if (!mounted) return;
    Navigator.of(context).pop();
    await plugin.onOnboardingComplete(context, values);
    // 应用用户在「示例数据选择」步骤勾选的分组（跳过引导视为未勾选）
    final selectedIds = values[kSampleDataGroupIdsKey];
    if (selectedIds is List) {
      await plugin.applySampleDataGroups(
        selectedIds.whereType<String>().toList(),
      );
    }
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = AppTheme.of(context);
          return Scaffold(
            backgroundColor: dsScaffoldBackground(theme),
            body: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.all(theme.spacing.md),
                      child: DSIconButton(
                        icon: DsIconKind.close,
                        size: 38,
                        color: theme.surfaceAlt,
                        iconColor: theme.textSub,
                        onPressed: _finish,
                        tooltip: 'app_onboarding_skip'.tr,
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      // 预渲染相邻页，避免带表单的步骤滑走再滑回时 State 被回收
                      allowImplicitScrolling: true,
                      itemCount: widget.steps.length,
                      onPageChanged: (index) =>
                          setState(() => _index = index),
                      itemBuilder: (context, index) =>
                          _buildPage(context, theme, widget.steps[index]),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      theme.spacing.xl,
                      theme.spacing.sm,
                      theme.spacing.xl,
                      theme.spacing.xl,
                    ),
                    child: DSButton(
                      label: _isLast
                          ? 'app_onboarding_getStarted'.tr
                          : 'app_onboarding_next'.tr,
                      variant: DSButtonVariant.secondary,
                      size: DSButtonSize.lg,
                      expand: true,
                      onPressed: _next,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 单页内容：自定义步骤为「标题 + 自定义内容」，否则「图标 + 标题 + 说明」
  Widget _buildPage(
    BuildContext context,
    AppThemeData theme,
    PluginOnboardingStep step,
  ) {
    final custom = step.builder?.call(context, _values);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.xxl),
      child: Column(
        mainAxisAlignment: custom != null
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          if (custom != null) ...[
            SizedBox(height: theme.spacing.xl),
            _buildHeader(theme, step, compactDescription: true),
            SizedBox(height: theme.spacing.xl),
            Expanded(child: custom),
          ] else ...[
            _buildIllustration(theme, step),
            SizedBox(height: theme.spacing.xxxl),
            DSPageIndicator(count: widget.steps.length, index: _index),
            SizedBox(height: theme.spacing.xxl),
            _buildHeader(theme, step),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(
    AppThemeData theme,
    PluginOnboardingStep step, {
    bool compactDescription = false,
  }) {
    return Column(
      children: [
        Text(
          step.title,
          style: DsTypography.display.copyWith(color: theme.text),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: theme.spacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            step.description,
            style: (compactDescription ? DsTypography.caption : DsTypography.body)
                .copyWith(color: theme.textSub, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// 插图占位：大果冻圆 + 步骤图标（缺省回退插件图标）
  Widget _buildIllustration(AppThemeData theme, PluginOnboardingStep step) {
    return JellyBox(
      width: 180,
      height: 180,
      radius: theme.radii.circle,
      color: widget.plugin.color ?? theme.primary,
      child: Icon(
        step.icon ?? widget.plugin.icon,
        size: 84,
        color: DsColors.white,
      ),
    );
  }
}
