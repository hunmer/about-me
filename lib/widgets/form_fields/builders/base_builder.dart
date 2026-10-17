import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import '../config.dart';
import '../form_field_wrapper.dart';
import '../types.dart';

/// ========== 公共样式生成函数 ==========

/// 创建统一的圆角容器装饰（DS 令牌驱动，手绘墨线）
/// 用于 Container、Row 等非输入组件
Decoration createRoundedContainerDecoration(
  BuildContext context, {
  double radius = 12,
}) {
  final theme = DSThemeBridge.resolve(context);

  return dsSketchDecoration(
    theme: theme,
    fillColor: theme.surface,
    radius: BorderRadius.circular(radius),
    // 描边对齐 DSInput 失焦态（主题语义色派生）
    stroke: theme.textSub.withValues(alpha: 0.45),
  );
}

/// ========== 构建函数 ==========

/// 构建文本输入框 - DSInput 果冻风格
///
/// 仍经 FormBuilderField 注册到 FormBuilder，外部 patchValue /
/// saveAndValidate 等行为与原 FormBuilderTextField 一致。
Widget buildTextField(
  FormFieldConfig config,
  GlobalKey fieldKey,
  BuildContext context,
) {
  return FormBuilderField<String>(
    key: fieldKey,
    name: config.name,
    initialValue: config.initialValue?.toString() ?? '',
    enabled: config.enabled,
    onChanged: config.onChanged,
    builder:
        (fieldState) => _FormDSInput(
          value: fieldState.value ?? '',
          enabled: config.enabled,
          obscureText: config.type == FormFieldType.password,
          keyboardType:
              config.type == FormFieldType.email
                  ? TextInputType.emailAddress
                  : config.type == FormFieldType.number
                  ? TextInputType.number
                  : TextInputType.text,
          labelText: config.labelText,
          hintText: config.hintText,
          prefixIcon: config.prefixIcon,
          suffixButtons: config.suffixButtons,
          onChanged: fieldState.didChange,
        ),
  );
}

/// 构建多行文本输入框 - DSInput 果冻风格
Widget buildTextAreaField(
  FormFieldConfig config,
  GlobalKey fieldKey,
  BuildContext context,
) {
  final extra = config.extra ?? {};

  return FormBuilderField<String>(
    key: fieldKey,
    name: config.name,
    initialValue: config.initialValue?.toString() ?? '',
    enabled: config.enabled,
    onChanged: config.onChanged,
    builder:
        (fieldState) => _FormDSInput(
          value: fieldState.value ?? '',
          enabled: config.enabled,
          keyboardType: TextInputType.multiline,
          minLines: (extra['minLines'] as int?) ?? 3,
          maxLines: (extra['maxLines'] as int?) ?? 6,
          labelText: config.labelText,
          hintText: config.hintText,
          onChanged: fieldState.didChange,
        ),
  );
}

/// 构建下拉选择框 - DSPopover 果冻气泡选项
Widget buildSelectField(
  FormFieldConfig config,
  GlobalKey fieldKey,
  BuildContext context,
) {
  final theme = DSThemeBridge.resolve(context);
  final items = config.items ?? const <DropdownMenuItem<dynamic>>[];

  return FormBuilderField<dynamic>(
    key: fieldKey,
    name: config.name,
    initialValue: config.initialValue,
    enabled: config.enabled,
    builder: (fieldState) {
      // 如果items列表不为空,但当前value不在items中,自动设置为initialValue或第一项
      if (items.isNotEmpty &&
          (fieldState.value == null ||
              !items.any((item) => item.value == fieldState.value))) {
        // 使用 Future.microtask 避免在 build 期间调用 setState
        Future.microtask(() {
          if (fieldState.mounted) {
            final newValue = config.initialValue ?? items.first.value;
            fieldState.didChange(newValue);
          }
        });
      }

      final selected =
          items.where((item) => item.value == fieldState.value).firstOrNull;

      Widget trigger = JellyBox(
        height: 46,
        radius: theme.radii.lg,
        strokeColor: theme.textSub.withValues(alpha: 0.45),
        padding: EdgeInsets.symmetric(horizontal: theme.spacing.md),
        child: Row(
          children: [
            if (config.prefixIcon != null) ...[
              Icon(config.prefixIcon, size: 20, color: theme.textSub),
              SizedBox(width: theme.spacing.sm),
            ],
            Expanded(
              child: DefaultTextStyle(
                style: DsTypography.body.copyWith(
                  color:
                      selected != null
                          ? theme.text
                          : theme.textSub.withValues(alpha: 0.8),
                ),
                child: selected?.child ?? Text(config.hintText ?? 'app_pleaseSelect'.tr),
              ),
            ),
            DsIcon(DsIconKind.chevronDown, size: 18, color: theme.primary),
          ],
        ),
      );
      if (!config.enabled) {
        trigger = Opacity(opacity: 0.55, child: IgnorePointer(child: trigger));
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (config.labelText != null)
            Padding(
              padding: EdgeInsets.only(
                bottom: theme.spacing.sm,
                left: theme.spacing.xs,
              ),
              child: Text(
                config.labelText!,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ),
          if (config.enabled)
            DSPopover(
              width: 264,
              contentBuilder:
                  (ctx, close) => ConstrainedBox(
                    constraints: BoxConstraints(
                      // 给弹出层留出上下边距，避免选项较多时超出视口。
                      maxHeight: MediaQuery.sizeOf(ctx).height * 0.6,
                    ),
                  child: _SelectScrollbar(
                    children: [
                      for (final item in items)
                        _SelectOptionRow(
                          selected: item.value == fieldState.value,
                          onTap: () {
                            close();
                            fieldState.didChange(item.value);
                            config.onChanged?.call(item.value);
                          },
                          child: item.child,
                        ),
                    ],
                  ),
                  ),
              child: trigger,
            )
          else
            trigger,
        ],
      );
    },
  );
}

/// 构建可搜索下拉（combobox）字段：DSCombobox 的表单封装
///
/// 选项经 [FormFieldConfig.extra] 的 `options` 传入
/// （`List<DSSelectItem<dynamic>>`），字段值为所选 item 的 value；
/// required 校验走表单统一的空值检查。
Widget buildComboBoxField(FormFieldConfig config, GlobalKey fieldKey) {
  final extra = config.extra ?? {};
  final options =
      (extra['options'] as List<DSSelectItem<dynamic>>?) ?? const [];

  return WrappedFormField(
    key: fieldKey,
    name: config.name,
    initialValue: config.initialValue,
    enabled: config.enabled,
    onChanged: config.onChanged,
    onValueChanged: config.onValueChanged,
    builder: (context, value, setValue) {
      final theme = DSThemeBridge.resolve(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (config.labelText != null)
            Padding(
              padding: EdgeInsets.only(
                bottom: theme.spacing.sm,
                left: theme.spacing.xs,
              ),
              child: Text(
                config.labelText!,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ),
          DSCombobox<dynamic>(
            items: options,
            value: value,
            hint: config.hintText ?? '请选择',
            enabled: config.enabled,
            onChanged: config.enabled ? (v) => setValue(v) : null,
          ),
        ],
      );
    },
  );
}

/// 下拉选项滚动列表：Scrollbar 与 ListView 共享 ScrollController。
///
/// 弹层挂在根 Overlay 上，取不到 PrimaryScrollController，
/// thumbVisibility 为 true 的 Scrollbar 必须显式持有 controller。
class _SelectScrollbar extends StatefulWidget {
  const _SelectScrollbar({required this.children});

  final List<Widget> children;

  @override
  State<_SelectScrollbar> createState() => _SelectScrollbarState();
}

class _SelectScrollbarState extends State<_SelectScrollbar> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: ListView(
        controller: _controller,
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        children: widget.children,
      ),
    );
  }
}

/// 下拉气泡中的选项行：选中态主色果冻块 + 对勾
class _SelectOptionRow extends StatelessWidget {
  const _SelectOptionRow({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.md,
            vertical: theme.spacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color:
                selected
                    ? theme.primary
                    : pressed
                    ? theme.surfaceAlt
                    : hovered
                    ? theme.surfaceAlt.withValues(alpha: 0.55)
                    : DsColors.transparent,
            borderRadius: theme.radii.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: DefaultTextStyle(
                  style: DsTypography.body.copyWith(
                    color: selected ? theme.onPrimary : theme.text,
                  ),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
              if (selected) ...[
                SizedBox(width: theme.spacing.sm),
                DsIcon(DsIconKind.check, size: 16, color: theme.onPrimary),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// FormBuilder 值 ↔ DSInput 控制器的同步桥
///
/// - 输入：DSInput.onChanged → fieldState.didChange
/// - 外部改值（patchValue / reset）：didUpdateWidget 同步进控制器
class _FormDSInput extends StatefulWidget {
  const _FormDSInput({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixButtons,
  });

  final String value;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final List<InputGroupButton>? suffixButtons;
  final ValueChanged<String> onChanged;

  @override
  State<_FormDSInput> createState() => _FormDSInputState();
}

class _FormDSInputState extends State<_FormDSInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _FormDSInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 用户正在输入时两者始终一致；不一致说明值来自外部（patchValue 等）
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return DSInput(
      controller: _controller,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      label: widget.labelText,
      hint: widget.hintText,
      prefix:
          widget.prefixIcon != null
              ? Icon(widget.prefixIcon, size: 20, color: theme.textSub)
              : null,
      suffix: _buildSuffixButtons(theme),
      onChanged: widget.onChanged,
    );
  }

  /// 后缀按钮：果冻小方块承载持久化 IconData
  Widget? _buildSuffixButtons(AppThemeData theme) {
    if (widget.suffixButtons == null || widget.suffixButtons!.isEmpty) {
      return null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final btn in widget.suffixButtons!)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Pressable(
              onPressed: btn.onPressed,
              semanticLabel: btn.tooltip,
              builder: (context, states) {
                final pressed = states.contains(WidgetState.pressed);
                return JellyBox(
                  width: 34,
                  height: 34,
                  radius: theme.radii.md,
                  raised: !pressed,
                  color: theme.primary.mixWhite(0.88),
                  alignment: Alignment.center,
                  child: Icon(btn.icon, size: 18, color: theme.primaryText),
                );
              },
            ),
          ),
      ],
    );
  }
}
