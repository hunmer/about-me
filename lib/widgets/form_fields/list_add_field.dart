import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 列表添加组件
///
/// 功能特性：
/// - 显示列表项（DS 果冻复选框、可删除）
/// - 底部有添加按钮和输入框（编辑原语）
/// - 支持回车添加
/// - 支持泛型，可与任何数据模型配合使用
class ListAddField<T> extends StatelessWidget {
  /// 列表项数据
  final List<T> items;

  /// 输入控制器
  final TextEditingController controller;

  /// 添加项的回调
  final VoidCallback onAdd;

  /// 切换完成状态的回调
  final Function(int index) onToggle;

  /// 删除项的回调
  final Function(int index) onRemove;

  /// 获取标题的回调
  final String Function(T item) getTitle;

  /// 获取完成状态的回调
  final bool Function(T item) getIsCompleted;

  /// 添加按钮的文本
  final String addButtonText;

  /// 主题色（保留以兼容配置；DS 件一律取主题令牌）
  final Color primaryColor;

  const ListAddField({
    super.key,
    required this.items,
    required this.controller,
    required this.onAdd,
    required this.onToggle,
    required this.onRemove,
    required this.getTitle,
    required this.getIsCompleted,
    required this.addButtonText,
    this.primaryColor = const Color(0xFF607AFB),
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return JellyBox(
      radius: theme.radii.lg,
      strokeColor: theme.textSub.withValues(alpha: 0.45),
      child: Column(
        children: [
          // 列表项
          for (var index = 0; index < items.length; index++)
            _buildItemRow(context, theme, index),
          // 添加输入框
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Pressable(
                  onPressed: onAdd,
                  semanticLabel: addButtonText,
                  child: Row(
                    children: [
                      DsIcon(DsIconKind.plus, size: 18, color: theme.primary),
                      const SizedBox(width: 8),
                      Text(
                        addButtonText,
                        style: DsTypography.caption.copyWith(
                          color: theme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: DsTypography.body.copyWith(color: theme.text),
                    decoration: InputDecoration(
                      hintText: '',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: DsTypography.body.copyWith(
                        color: theme.textSub.withValues(alpha: 0.75),
                      ),
                    ),
                    onSubmitted: (_) => onAdd(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, AppThemeData theme, int index) {
    final item = items[index];
    final title = getTitle(item);
    final isCompleted = getIsCompleted(item);

    return Container(
      decoration: BoxDecoration(
        border:
            index < items.length - 1
                ? Border(bottom: BorderSide(color: theme.stroke))
                : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          DSCheckbox(value: isCompleted, onChanged: (_) => onToggle(index)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: DsTypography.body.copyWith(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? theme.textSub : theme.text,
              ),
            ),
          ),
          Pressable(
            onPressed: () => onRemove(index),
            semanticLabel: 'app_delete'.tr,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DsIcon(DsIconKind.close, size: 15, color: theme.textSub),
            ),
          ),
        ],
      ),
    );
  }
}
