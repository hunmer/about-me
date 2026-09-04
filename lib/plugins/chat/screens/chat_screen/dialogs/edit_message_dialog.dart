import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/message.dart';

class EditMessageDialog extends StatelessWidget {
  final Message message;
  final TextEditingController controller;
  final Function() onCancel;
  final Function() onSave;

  const EditMessageDialog({
    super.key,
    required this.message,
    required this.controller,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'chat_editMessageTitle'.tr,
                  textAlign: TextAlign.center,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                SizedBox(height: theme.spacing.lg),
                DSInput(
                  controller: controller,
                  hint: 'chat_messageHintText'.tr,
                  maxLines: null,
                ),
                SizedBox(height: theme.spacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _FormatButton(
                      label: 'B',
                      style: DsTypography.heading.copyWith(
                        color: theme.text,
                        fontWeight: FontWeight.w900,
                      ),
                      onTap: () => _insertMarkdownStyle('**'),
                    ),
                    _FormatButton(
                      label: 'I',
                      style: DsTypography.heading.copyWith(
                        color: theme.text,
                        fontStyle: FontStyle.italic,
                      ),
                      onTap: () => _insertMarkdownStyle('*'),
                    ),
                    _FormatButton(
                      label: 'S',
                      style: DsTypography.heading.copyWith(
                        color: theme.text,
                        decoration: TextDecoration.lineThrough,
                      ),
                      onTap: () => _insertMarkdownStyle('~~'),
                    ),
                    _FormatButton(
                      label: 'U',
                      style: DsTypography.heading.copyWith(
                        color: theme.text,
                        decoration: TextDecoration.underline,
                      ),
                      onTap: () => _insertMarkdownStyle('__'),
                    ),
                  ],
                ),
                SizedBox(height: theme.spacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: DSButton(
                        label: 'app_cancel'.tr,
                        variant: DSButtonVariant.outline,
                        onPressed: onCancel,
                      ),
                    ),
                    SizedBox(width: theme.spacing.md),
                    Expanded(
                      child: DSButton(label: 'app_save'.tr, onPressed: onSave),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _insertMarkdownStyle(String style) {
    final text = controller.text;
    final selection = controller.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '$style${selection.textInside(text)}$style',
    );
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset:
            selection.baseOffset +
            style.length * 2 +
            selection.textInside(text).length,
      ),
    );
  }
}

/// Markdown 格式按钮：果冻底座 + 带格式样的字母
class _FormatButton extends StatelessWidget {
  const _FormatButton({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pressed ? theme.primary.mixWhite(0.86) : theme.surfaceAlt,
            borderRadius: theme.radii.sm,
            border: Border.all(color: theme.stroke, width: 1.2),
          ),
          child: Text(label, style: style),
        );
      },
    );
  }
}
