import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 类别选择器组件
///
/// 功能特性：
/// - 水平滚动的类别列表
/// - 圆形果冻图标 + 标签文字
/// - 支持自定义图标映射
class CategorySelectorField extends StatelessWidget {
  /// 可用的类别列表
  final List<String> categories;

  /// 当前选中的类别
  final String? selectedCategory;

  /// 类别图标映射表（持久化 IconData）
  final Map<String, IconData> categoryIcons;

  /// 类别选择变化的回调
  final ValueChanged<String> onCategoryChanged;

  /// 主题色（选中状态的背景色）
  final Color primaryColor;

  /// 组件高度
  final double height;

  /// 图标大小
  final double iconSize;

  /// 图标容器大小
  final double iconContainerSize;

  const CategorySelectorField({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.categoryIcons,
    required this.onCategoryChanged,
    this.primaryColor = const Color(0xFF607AFB),
    this.height = 100,
    this.iconSize = 28,
    this.iconContainerSize = 56,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;
          final icon = categoryIcons[category] ?? Icons.category;

          return Pressable(
            onPressed: () => onCategoryChanged(category),
            semanticLabel: category,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: iconContainerSize,
                  height: iconContainerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? primaryColor : null,
                    border: Border.all(color: theme.stroke, width: 1.4),
                    boxShadow: isSelected ? theme.shadows.soft : null,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? DsColors.white : theme.textSub,
                    size: iconSize,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  category,
                  style: DsTypography.caption.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? theme.text : theme.textSub,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
