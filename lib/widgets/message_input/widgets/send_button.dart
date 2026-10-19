import 'package:flutter/widgets.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

class SendButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const SendButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          return DSIconButton(
            icon: DsIconKind.send,
            size: 40,
            onPressed: onPressed,
          );
        },
      ),
    );
  }
}
