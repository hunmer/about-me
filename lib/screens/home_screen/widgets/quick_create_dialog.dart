import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Memento/screens/home_screen/managers/quick_create_registry.dart';

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

    return AlertDialog(
      title: Text('home_quickCreateTitle'.tr),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      content: SizedBox(
        width: double.maxFinite,
        child: items.isEmpty
            ? const SizedBox.shrink()
            : GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 100,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.9,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _buildItemTile(
                    context,
                    Theme.of(context),
                    item,
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('app_cancel'.tr),
        ),
      ],
    );
  }

  /// 构建单个可新建项
  Widget _buildItemTile(
    BuildContext context,
    ThemeData theme,
    QuickCreateItem item,
  ) {
    final color = item.color ?? theme.colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).pop();
        onSelected(item);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
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
              child: Icon(item.icon, size: 24, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              style: theme.textTheme.labelMedium,
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
