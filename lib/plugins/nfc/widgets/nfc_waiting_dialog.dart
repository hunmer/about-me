import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:get/get.dart';

/// 显示 NFC 等待对话框（读取/写入进行中，不可点遮罩关闭）
///
/// 完成后由调用方通过 `Navigator.of(context, rootNavigator: true).pop()` 关闭
void showNfcWaitingDialog(
  BuildContext context, {
  String? detail,
  String? cancelText,
  VoidCallback? onCancel,
}) {
  showDSDialog(
    context: context,
    barrierDismissible: false,
    theme: DSThemeBridge.resolve(context),
    builder: (context) => PopScope(
      canPop: false,
      child: NfcWaitingDialog(
        message: 'nfc_pleaseBringPhoneNearNFC'.tr,
        detail: detail,
        cancelText: cancelText,
        onCancel: onCancel,
      ),
    ),
  );
}

/// NFC 等待对话框面板：果冻面板 + 加载动画 + 可选取消按钮
class NfcWaitingDialog extends StatelessWidget {
  const NfcWaitingDialog({
    super.key,
    required this.message,
    this.detail,
    this.cancelText,
    this.onCancel,
  });

  final String message;

  /// 副标题（当前操作说明）
  final String? detail;

  final String? cancelText;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return JellyBox(
      radius: theme.radii.xxl,
      padding: EdgeInsets.all(theme.spacing.xl),
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DSLoadingDots(size: 14),
          SizedBox(height: theme.spacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: DsTypography.body.copyWith(color: theme.text),
          ),
          if (detail != null) ...[
            SizedBox(height: theme.spacing.sm),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
          if (cancelText != null && onCancel != null) ...[
            SizedBox(height: theme.spacing.xl),
            DSButton(
              label: cancelText!,
              variant: DSButtonVariant.outline,
              onPressed: () {
                Navigator.of(context).pop();
                onCancel!();
              },
            ),
          ],
        ],
      ),
    );
  }
}
