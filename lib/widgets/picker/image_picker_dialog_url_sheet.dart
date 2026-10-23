part of 'image_picker_dialog.dart';

/// 在线 URL 输入的二级底部弹窗
///
/// 确认时 pop `{'url', 'bytes': null}`，取消/下滑 pop null；
/// 主弹窗收到结果后再以相同结果 pop 交给调用方。
class _UrlInputSheet extends StatefulWidget {
  final String? initialUrl;

  const _UrlInputSheet({this.initialUrl});

  @override
  State<_UrlInputSheet> createState() => _UrlInputSheetState();
}

class _UrlInputSheetState extends State<_UrlInputSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
    _focusNode = FocusNode();
    _validate(_controller.text);
    // 打开即聚焦弹键盘
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _validate(String url) {
    final valid =
        url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'));
    if (valid != _isValid) {
      setState(() => _isValid = valid);
    }
  }

  void _confirm() {
    if (!_isValid) return;
    Navigator.of(
      context,
    ).pop(<String, dynamic>{'url': _controller.text, 'bytes': null});
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Sheet(
      decoration: MaterialSheetDecoration(
        size: SheetSize.fit,
        color: theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: theme.spacing.lg),
            Text(
              'image_picker_onlineUrl'.tr,
              textAlign: TextAlign.center,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
            SizedBox(height: theme.spacing.md),
            DSInput(
              controller: _controller,
              label: 'image_picker_onlineUrl'.tr,
              hint: 'https://...',
              focusNode: _focusNode,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _confirm(),
              onChanged: _validate,
            ),
            SizedBox(height: theme.spacing.md),
            Row(
              children: [
                Expanded(
                  child: DSButton(
                    label: 'app_cancel'.tr,
                    variant: DSButtonVariant.outline,
                    size: DSButtonSize.sm,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DSButton(
                    label: 'app_confirm'.tr,
                    size: DSButtonSize.sm,
                    onPressed: _isValid ? _confirm : null,
                  ),
                ),
              ],
            ),
            SafeArea(top: false, child: SizedBox(height: theme.spacing.md)),
          ],
        ),
      ),
    );
  }
}
