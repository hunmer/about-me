import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

import 'gallery_section.dart';

/// 06 反馈与浮层
class FeedbackSection extends StatelessWidget {
  const FeedbackSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return SectionCard(
      index: '06',
      title: '反馈与浮层',
      children: [
        DemoFlow(
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            DemoBlock(
              label: '对话框（Dialog）',
              child: DSButton(
                label: '完成今日任务！',
                onPressed: () => _showDemoDialog(context),
              ),
            ),
            DemoBlock(
              label: '底部面板（Bottom Sheet）',
              child: DSButton(
                label: '打开面板',
                variant: DSButtonVariant.outline,
                onPressed: () => _showDemoSheet(context),
              ),
            ),
            DemoBlock(
              label: 'Toast 提示',
              child: DSButton(
                label: '已保存 ✓',
                variant: DSButtonVariant.secondary,
                onPressed:
                    () => showDSToast(
                      context,
                      message: '已保存',
                      type: DSToastType.success,
                    ),
              ),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        DemoFlow(
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            DemoBlock(
              label: '气泡（Tooltip，悬停/长按）',
              child: DSTooltip(
                message: '点击这里看说明~',
                child: DSButton(
                  label: '说明',
                  variant: DSButtonVariant.ghost,
                  onPressed: () {},
                ),
              ),
            ),
            DemoBlock(
              label: '加载动画（Loading）',
              child: const DSLoadingDots(label: '加载中...'),
            ),
          ],
        ),
      ],
    );
  }

  void _showDemoDialog(BuildContext context) {
    showDSDialog<bool>(
      context: context,
      builder:
          (context) => DSDialog(
            title: '完成今日任务！',
            message: '太棒啦！继续保持，明天会更好~',
            confirmText: '确定',
            cancelText: '取消',
            onConfirm: () {
              Navigator.of(context).pop(true);
              showDSToast(context, message: '任务已完成', type: DSToastType.success);
            },
          ),
    );
  }

  void _showDemoSheet(BuildContext context) {
    showDSBottomSheet<void>(
      context: context,
      title: '记录操作',
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DSSheetAction(
                icon: DsIconKind.share,
                label: '分享给好友',
                trailing: DsIcon(
                  DsIconKind.chevronRight,
                  size: 16,
                  color: DSThemeBridge.resolve(context).textSub,
                ),
                onTap: () => Navigator.of(context).pop(),
              ),
              DSSheetAction(
                icon: DsIconKind.download,
                label: '导出记录',
                onTap: () => Navigator.of(context).pop(),
              ),
              DSSheetAction(
                icon: DsIconKind.trash,
                label: '删除记录',
                destructive: true,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
    );
  }
}
