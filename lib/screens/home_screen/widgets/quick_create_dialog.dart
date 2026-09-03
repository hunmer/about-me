import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/managers/quick_create_registry.dart';

/// 快速新建对话框
///
/// 展示所有注册的快速创建项（插件的可新建数据类型），
/// 点击后关闭对话框并通过 [onSelected] 通知调用方打开对应编辑界面。
class QuickCreateDialog extends StatelessWidget {
  /// 选中项回调（在对话框关闭后调用，context 为主页上下文）
  final void Function(QuickCreateItem item) onSelected;

  const QuickCreateDialog({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final items = QuickCreateRegistry().items;

    return DSThemeBridge(
      // Builder 让内容在主题桥之内构建，可读取 AppTheme
      child: Builder(
        builder: (context) {
          final theme = AppTheme.of(context);
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'home_quickCreateTitle'.tr,
                  textAlign: TextAlign.center,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                SizedBox(height: theme.spacing.lg),
                Flexible(
                  child:
                      items.isEmpty
                          ? const SizedBox.shrink()
                          : GridView.builder(
                            shrinkWrap: true,
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 100,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 0.9,
                                ),
                            itemCount: items.length,
                            itemBuilder:
                                (context, index) => _buildItemTile(
                                  context,
                                  theme,
                                  items[index],
                                ),
                          ),
                ),
                SizedBox(height: theme.spacing.lg),
                DSButton(
                  label: 'app_cancel'.tr,
                  variant: DSButtonVariant.outline,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建单个可新建项
  Widget _buildItemTile(
    BuildContext context,
    AppThemeData theme,
    QuickCreateItem item,
  ) {
    final color = item.color ?? theme.primary;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        onSelected(item);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: theme.radii.lg,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              // item.icon 为插件注册的 Material IconData，保留
              child: Icon(item.icon, size: 24, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              style: DsTypography.caption.copyWith(color: theme.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
