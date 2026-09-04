import 'package:flutter/widgets.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

class MessageActions extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final Function(String?) onSetFixedSymbol;

  const MessageActions({
    super.key,
    required this.onEdit,
    required this.onDelete,
    required this.onCopy,
    required this.onSetFixedSymbol,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DSIconButton(
          icon: DsIconKind.edit,
          size: 32,
          color: theme.surfaceAlt,
          iconColor: theme.textSub,
          onPressed: onEdit,
          tooltip: '编辑',
        ),
        DSIconButton(
          icon: DsIconKind.copy,
          size: 32,
          color: theme.surfaceAlt,
          iconColor: theme.textSub,
          onPressed: onCopy,
          tooltip: '复制',
        ),
        DSIconButton(
          icon: DsIconKind.trash,
          size: 32,
          color: theme.surfaceAlt,
          iconColor: theme.textSub,
          onPressed: onDelete,
          tooltip: '删除',
        ),
      ],
    );
  }
}
