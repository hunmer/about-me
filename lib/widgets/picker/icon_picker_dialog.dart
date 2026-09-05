import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import '../custom_dialog.dart';
import 'package:aboutme/constants/app_icons.dart';

class IconPickerDialog extends StatefulWidget {
  final IconData currentIcon;
  final bool enableIconToImage; // 是否启用图标转图片功能
  final bool forceConvertToImage; // 是否强制转换为图片（不可取消）

  const IconPickerDialog({
    super.key,
    required this.currentIcon,
    this.enableIconToImage = true,
    this.forceConvertToImage = false,
  });

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  late IconData selectedIcon;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  int _currentPage = 0;
  static const int _iconsPerPage = 200;
  List<IconData> _cachedFilteredIcons = [];
  late List<String> _iconNames;
  late List<IconData> _iconData;
  bool _convertToImage = false; // 是否转换为图片

  // 使用预定义的图标映射表中的图标（持久化 IconData）
  late List<IconData> allIcons;

  @override
  void initState() {
    super.initState();
    selectedIcon = widget.currentIcon;
    // 从AppIcons中获取所有预定义图标
    allIcons = AppIcons.predefinedIcons.values.toList();
    _iconNames = AppIcons.predefinedIcons.keys.toList();
    _iconData = AppIcons.predefinedIcons.values.toList();
    // 如果强制转换为图片，则初始化为 true
    if (widget.forceConvertToImage) {
      _convertToImage = true;
    }
    _updateFilteredIcons();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // 过滤图标列表
  List<IconData> get filteredIcons => _cachedFilteredIcons;

  void _updateFilteredIcons() {
    List<IconData> result;
    if (searchQuery.isEmpty) {
      result = _iconData;
    } else {
      // 先过滤名称列表
      final filteredIndices =
          _iconNames
              .asMap()
              .entries
              .where((entry) {
                return entry.value.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                );
              })
              .map((entry) => entry.key)
              .toList();

      // 转换为对应的图标数据
      result = filteredIndices.map((index) => _iconData[index]).toList();
    }

    // 重置页码当过滤结果变化时
    if (_currentPage > 0 && _currentPage * _iconsPerPage >= result.length) {
      _currentPage = 0;
    }

    _cachedFilteredIcons = result;
  }

  // 获取当前页的图标
  List<IconData> get _currentPageIcons {
    final start = _currentPage * _iconsPerPage;
    final end = start + _iconsPerPage;
    return filteredIcons.sublist(
      start.clamp(0, filteredIcons.length),
      end.clamp(0, filteredIcons.length),
    );
  }

  // 总页数
  int get _totalPages {
    return (filteredIcons.length / _iconsPerPage).ceil();
  }

  /// 将图标转换为图片
  Future<Map<String, dynamic>?> _convertIconToImage(IconData icon) async {
    try {
      // 创建测试环境来渲染图标
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 设置画布大小
      const size = 100.0;

      // 绘制图标
      final iconPainter = IconPainter(
        icon: icon,
        size: 80.0,
        color: Colors.black,
      );
      iconPainter.paint(canvas, const Size(100, 100));

      // 结束录制
      final picture = recorder.endRecording();

      // 转换为图片
      final img = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();

      if (bytes != null) {
        return {'bytes': bytes, 'icon': icon};
      }
      return null;
    } catch (e) {
      print('图标转图片失败: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return CustomDialog(
      title: 'widget_selectIcon'.tr,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 搜索框
          DSInput(
            controller: _searchController,
            hint: 'widget_searchIcons'.tr,
            prefix: DsIcon(DsIconKind.search, size: 20, color: theme.textSub),
            onChanged: (value) {
              if (_debounceTimer?.isActive ?? false) {
                _debounceTimer?.cancel();
              }
              _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                setState(() {
                  searchQuery = value;
                  _updateFilteredIcons();
                });
              });
            },
          ),
          const SizedBox(height: 16),

          // 图标转图片选项
          if (widget.enableIconToImage)
            Row(
              children: [
                DSCheckbox(
                  value: _convertToImage,
                  onChanged:
                      widget.forceConvertToImage
                          ? null
                          : (value) {
                            setState(() {
                              _convertToImage = value ?? false;
                            });
                          },
                ),
                Expanded(
                  child: Text(
                    'widget_convertIconToImage'.tr,
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                ),
                Pressable(
                  onPressed: _showConvertHelp,
                  semanticLabel: 'widget_whatIsIconToImage'.tr,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: DsIcon(
                      DsIconKind.info,
                      size: 18,
                      color: theme.textSub,
                    ),
                  ),
                ),
              ],
            ),

          if (widget.enableIconToImage) const SizedBox(height: 16),

          // 图标网格（果冻单元承载持久化 IconData）
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _currentPageIcons.length,
              itemBuilder: (context, index) {
                final icon = _currentPageIcons[index];
                final isSelected = icon == selectedIcon;
                return Pressable(
                  onPressed: () {
                    setState(() {
                      selectedIcon = icon;
                    });
                  },
                  semanticLabel: 'icon',
                  builder: (context, states) {
                    final pressed = states.contains(WidgetState.pressed);
                    return JellyBox(
                      radius: theme.radii.md,
                      color: isSelected ? theme.primary : null,
                      raised: isSelected && !pressed,
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        size: 24,
                        color: isSelected ? theme.onPrimary : theme.text,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_totalPages > 1) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPageButton(
                  icon: DsIconKind.chevronLeft,
                  enabled: _currentPage > 0,
                  onPressed: () => setState(() => _currentPage--),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${_currentPage + 1}/$_totalPages',
                    style: DsTypography.body.copyWith(color: theme.textSub),
                  ),
                ),
                _buildPageButton(
                  icon: DsIconKind.chevronRight,
                  enabled: _currentPage < _totalPages - 1,
                  onPressed: () => setState(() => _currentPage++),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        DSButton(
          label: 'widget_cancel'.tr,
          variant: DSButtonVariant.outline,
          size: DSButtonSize.sm,
          onPressed: () => Navigator.pop(context),
        ),
        DSButton(
          label: 'widget_confirm'.tr,
          size: DSButtonSize.sm,
          onPressed: () async {
            if (_convertToImage) {
              final result = await _convertIconToImage(selectedIcon);
              Navigator.pop(context, result);
            } else {
              Navigator.pop(context, selectedIcon);
            }
          },
        ),
      ],
    );
  }

  /// 翻页按钮
  Widget _buildPageButton({
    required DsIconKind icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: enabled ? onPressed : null,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return JellyBox(
          width: 36,
          height: 36,
          radius: theme.radii.md,
          raised: enabled && !pressed,
          alignment: Alignment.center,
          child: DsIcon(
            icon,
            size: 18,
            color:
                enabled
                    ? theme.primaryText
                    : theme.textSub.withValues(alpha: 0.5),
          ),
        );
      },
    );
  }

  /// 图标转图片功能说明
  void _showConvertHelp() {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSDialog(
            title: 'widget_iconToImage'.tr,
            message: 'widget_iconToImageDescription'.tr,
            confirmText: 'widget_confirm'.tr,
          ),
    );
  }
}

/// 图标绘制器
class IconPainter extends CustomPainter {
  final IconData icon;
  final double size;
  final Color color;

  IconPainter({required this.icon, required this.size, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // 居中绘制图标
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: this.size,
          fontFamily: icon.fontFamily,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final offset = Offset(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 显示图标选择器对话框的工具方法
Future<dynamic> showIconPickerDialog(
  BuildContext context,
  IconData currentIcon, {
  bool enableIconToImage = true,
  bool forceConvertToImage = false,
}) {
  // 使用原生showDialog，但确保使用rootNavigator以保证在最上层显示
  return showDialog<dynamic>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    useSafeArea: true,
    useRootNavigator: true, // 确保在根Navigator上显示，这样会在所有其他对话框之上
    builder:
        (context) => IconPickerDialog(
          currentIcon: currentIcon,
          enableIconToImage: enableIconToImage,
          forceConvertToImage: forceConvertToImage,
        ),
  );
}
