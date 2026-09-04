import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/widget_config_editor/index.dart';
import 'package:aboutme/plugins/bill/models/bill_shortcut.dart';
import 'package:aboutme/plugins/bill/services/bill_shortcuts_widget_service.dart';
import 'package:aboutme/plugins/bill/bill_plugin.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/services/toast_service.dart';

/// 快捷记账小组件配置页面
///
/// 功能:
/// - 添加/删除/编辑快捷预设
/// - 配置小组件颜色主题
/// - 保存配置到 SharedPreferences
class BillShortcutsSelectorScreen extends StatefulWidget {
  final int widgetId;

  const BillShortcutsSelectorScreen({super.key, required this.widgetId});

  @override
  State<BillShortcutsSelectorScreen> createState() =>
      _BillShortcutsSelectorScreenState();
}

class _BillShortcutsSelectorScreenState
    extends State<BillShortcutsSelectorScreen> {
  final List<BillShortcut> _shortcuts = [];
  BillPlugin? _billPlugin;
  late WidgetConfig _widgetConfig;

  @override
  void initState() {
    super.initState();
    _billPlugin = PluginManager.instance.getPlugin('bill') as BillPlugin?;

    // 初始化默认配置
    _widgetConfig = WidgetConfig(
      colors: [
        ColorConfig(
          key: 'background',
          label: '背景色',
          defaultValue: Colors.white,
          currentValue: Colors.white,
        ),
        ColorConfig(
          key: 'text',
          label: '文字色',
          defaultValue: const Color(0xFF1F2937),
          currentValue: const Color(0xFF1F2937),
        ),
        ColorConfig(
          key: 'icon',
          label: '图标色',
          defaultValue: const Color(0xFF10B981),
          currentValue: const Color(0xFF10B981),
        ),
      ],
      opacity: 1.0,
    );

    _loadExistingConfig();
  }

  /// 加载已有配置
  Future<void> _loadExistingConfig() async {
    final config = await BillShortcutsWidgetService.instance.loadWidgetConfig(
      widget.widgetId,
    );

    if (config != null && mounted) {
      setState(() {
        _shortcuts.clear();
        _shortcuts.addAll(config.shortcuts);
      });
    }

    // 加载颜色配置
    final colors = await BillShortcutsWidgetService.instance.loadWidgetColors(
      widget.widgetId,
    );

    if (colors != null && mounted) {
      setState(() {
        _widgetConfig = _widgetConfig.updateColor(
          'background',
          colors['backgroundColor']!,
        );
        _widgetConfig = _widgetConfig.updateColor('text', colors['textColor']!);
        _widgetConfig = _widgetConfig.updateColor('icon', colors['iconColor']!);
      });
    }
  }

  /// 添加快捷预设
  Future<void> _addShortcut() async {
    if (_billPlugin == null) {
      toastService.showToast('账单插件未加载');
      return;
    }

    final accounts = _billPlugin!.accounts;
    if (accounts.isEmpty) {
      toastService.showToast('请先创建账户');
      return;
    }

    // 打开编辑对话框
    final shortcut = await showDSDialog<BillShortcut>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => BillShortcutEditDialog(accounts: accounts),
    );

    if (shortcut != null && mounted) {
      setState(() {
        _shortcuts.add(shortcut);
      });
    }
  }

  /// 编辑快捷预设
  Future<void> _editShortcut(int index) async {
    if (_billPlugin == null) return;

    final accounts = _billPlugin!.accounts;
    final shortcut = await showDSDialog<BillShortcut>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => BillShortcutEditDialog(
            accounts: accounts,
            initialShortcut: _shortcuts[index],
          ),
    );

    if (shortcut != null && mounted) {
      setState(() {
        _shortcuts[index] = shortcut;
      });
    }
  }

  /// 删除快捷预设
  void _removeShortcut(int index) {
    setState(() {
      _shortcuts.removeAt(index);
    });
  }

  /// 保存配置
  Future<void> _saveConfig() async {
    if (_shortcuts.isEmpty) {
      toastService.showToast('请至少添加一个快捷预设');
      return;
    }

    final config = BillShortcutsWidgetConfig(
      widgetId: widget.widgetId,
      shortcuts: _shortcuts,
    );

    // 保存配置
    final saveResult = await BillShortcutsWidgetService.instance
        .saveWidgetConfig(config);

    if (!saveResult) {
      if (mounted) {
        toastService.showToast('保存配置失败');
      }
      return;
    }

    // 保存颜色配置
    await BillShortcutsWidgetService.instance.saveWidgetColors(
      widgetId: widget.widgetId,
      backgroundColor: _widgetConfig.getColor('background')!,
      textColor: _widgetConfig.getColor('text')!,
      iconColor: _widgetConfig.getColor('icon')!,
    );

    if (mounted) {
      toastService.showToast('配置已保存');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('bill_quickBookkeepingConfig'.tr),
        actions: [
          // DS 按钮自带 DSThemeBridge 提供 AppTheme
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.check,
                  size: 40,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  onPressed: _saveConfig,
                  tooltip: 'bill_saveConfig'.tr,
                );
              },
            ),
          ),
        ],
      ),
      body: WidgetConfigEditor(
        widgetSize: WidgetSize.large,
        initialConfig: _widgetConfig,
        previewTitle: 'bill_quickBookkeepingConfig'.tr,
        onConfigChanged: (config) {
          setState(() {
            _widgetConfig = config;
          });
        },
        previewBuilder: _buildPreview,
        customConfigWidgets: [_buildShortcutsList()],
      ),
      floatingActionButton: DSFab(
        icon: DsIconKind.plus,
        onPressed: _addShortcut,
      ),
    );
  }

  /// 构建预览
  Widget _buildPreview(BuildContext context, WidgetConfig config) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: config.getColor('background'),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'bill_quickBookkeepingConfig'.tr,
                style: TextStyle(
                  color: config.getColor('icon'),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.add, color: config.getColor('icon'), size: 24),
            ],
          ),
          const SizedBox(height: 12),
          // 快捷列表示例
          if (_shortcuts.isEmpty)
            Center(
              child: Text(
                'bill_noQuickPresets'.tr,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            )
          else
            ...List.generate(
              _shortcuts.length.clamp(0, 3),
              (index) => _buildPreviewItem(_shortcuts[index], config),
            ),
        ],
      ),
    );
  }

  /// 构建预览项
  Widget _buildPreviewItem(BillShortcut shortcut, WidgetConfig config) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_box_outline_blank,
            size: 20,
            color: Colors.grey[400],
          ),
          const SizedBox(width: 8),
          Icon(shortcut.icon, size: 24, color: shortcut.iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shortcut.name,
                  style: TextStyle(
                    color: config.getColor('text'),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  shortcut.category,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (shortcut.amount != null)
            Text(
              shortcut.isExpense
                  ? '-¥${shortcut.amount!.toStringAsFixed(2)}'
                  : '+¥${shortcut.amount!.toStringAsFixed(2)}',
              style: TextStyle(
                color:
                    shortcut.isExpense
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  /// 构建快捷列表
  Widget _buildShortcutsList() {
    final theme = DSThemeBridge.resolve(context);
    if (_shortcuts.isEmpty) {
      return Center(
        child: Text(
          'bill_clickToAddQuickPreset'.tr,
          style: DsTypography.body.copyWith(color: theme.textSub),
        ),
      );
    }

    return DSThemeBridge(
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _shortcuts.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) {
              newIndex -= 1;
            }
            final item = _shortcuts.removeAt(oldIndex);
            _shortcuts.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final shortcut = _shortcuts[index];
          return Container(
            key: ValueKey(shortcut.id),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(shortcut.icon, color: shortcut.iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shortcut.name,
                        style: DsTypography.body.copyWith(
                          color: theme.text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${shortcut.category}${shortcut.amount != null ? " · ${shortcut.isExpense ? "-" : "+"}¥${shortcut.amount!.toStringAsFixed(2)}" : ""}',
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
                DSIconButton(
                  icon: DsIconKind.edit,
                  size: 38,
                  onPressed: () => _editShortcut(index),
                ),
                DSIconButton(
                  icon: DsIconKind.trash,
                  size: 38,
                  onPressed: () => _removeShortcut(index),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 快捷预设编辑对话框
class BillShortcutEditDialog extends StatefulWidget {
  final List accounts;
  final BillShortcut? initialShortcut;

  const BillShortcutEditDialog({
    super.key,
    required this.accounts,
    this.initialShortcut,
  });

  @override
  State<BillShortcutEditDialog> createState() => _BillShortcutEditDialogState();
}

class _BillShortcutEditDialogState extends State<BillShortcutEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;

  /// 名称校验错误（DSInput 通过 errorText 展示）
  String? _nameError;

  String? _selectedAccountId;
  String _selectedCategory = '餐饮';
  bool _isExpense = true;
  IconData _selectedIcon = Icons.restaurant;
  Color _selectedIconColor = const Color(0xFF10B981);

  // 分类与图标映射
  final Map<String, IconData> _categoryIcons = {
    '餐饮': Icons.restaurant,
    '购物': Icons.shopping_cart,
    '交通': Icons.directions_car,
    '日用': Icons.home,
    '娱乐': Icons.theater_comedy,
    '医疗': Icons.local_hospital,
    '教育': Icons.school,
    '住房': Icons.apartment,
    '工资': Icons.work,
    '奖金': Icons.card_giftcard,
    '投资': Icons.trending_up,
    '其他': Icons.label,
  };

  @override
  void initState() {
    super.initState();

    final initial = widget.initialShortcut;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _amountController = TextEditingController(
      text: initial?.amount?.toStringAsFixed(2) ?? '',
    );

    _selectedAccountId = initial?.accountId ?? widget.accounts.first.id;
    _selectedCategory = initial?.category ?? '餐饮';
    _isExpense = initial?.isExpense ?? true;
    _selectedIcon = initial?.icon ?? Icons.restaurant;
    _selectedIconColor = initial?.iconColor ?? const Color(0xFF10B981);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    // DSInput 无内建 Form 校验，提交时手动校验
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'bill_pleaseEnterPresetName'.tr);
      return;
    }
    setState(() => _nameError = null);

    final shortcut = BillShortcut(
      id: widget.initialShortcut?.id,
      name: _nameController.text.trim(),
      accountId: _selectedAccountId!,
      category: _selectedCategory,
      amount:
          _amountController.text.isNotEmpty
              ? double.tryParse(_amountController.text)
              : null,
      isExpense: _isExpense,
      icon: _selectedIcon,
      iconColor: _selectedIconColor,
    );

    Navigator.of(context).pop(shortcut);
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return JellyBox(
      radius: theme.radii.xxl,
      padding: EdgeInsets.all(theme.spacing.xl),
      constraints: const BoxConstraints(maxWidth: 400),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initialShortcut == null
                  ? 'bill_addQuickPreset'.tr
                  : 'bill_editQuickPreset'.tr,
              textAlign: TextAlign.center,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
            SizedBox(height: theme.spacing.lg),
            // 名称
            DSInput(
              controller: _nameController,
              label: 'bill_presetName'.tr,
              hint: 'bill_presetNameHint'.tr,
              errorText: _nameError,
              onChanged: (_) {
                if (_nameError != null) {
                  setState(() => _nameError = null);
                }
              },
            ),
            SizedBox(height: theme.spacing.md),

            // 账户
            DSSelect<String>(
              value: _selectedAccountId,
              items:
                  widget.accounts
                      .map(
                        (account) => DSSelectItem(
                          value: account.id as String,
                          label: account.title as String,
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedAccountId = value;
                });
              },
              hint: '账户',
            ),
            SizedBox(height: theme.spacing.md),

            // 分类（选项需展示持久化 IconData，DSSelect 不支持自定义行，保留 Material 下拉）
            Material(
              type: MaterialType.transparency,
              child: DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: '分类'),
                items:
                    _categoryIcons.keys.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Row(
                          children: [
                            Icon(_categoryIcons[category], size: 20),
                            const SizedBox(width: 8),
                            Text(category),
                          ],
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                    _selectedIcon = _categoryIcons[value]!;
                  });
                },
              ),
            ),
            SizedBox(height: theme.spacing.md),

            // 金额(可选)
            DSInput(
              controller: _amountController,
              label: 'bill_presetAmount'.tr,
              hint: 'bill_presetAmountHint'.tr,
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: theme.spacing.md),

            // 收入/支出
            DSSegmentedControl(
              options: ['bill_expense'.tr, 'bill_income'.tr],
              selected: _isExpense ? 0 : 1,
              onChanged: (index) {
                setState(() {
                  _isExpense = index == 0;
                });
              },
            ),
            SizedBox(height: theme.spacing.lg),
            Row(
              children: [
                Expanded(
                  child: DSButton(
                    label: 'bill_cancel'.tr,
                    variant: DSButtonVariant.outline,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: theme.spacing.md),
                Expanded(
                  child: DSButton(label: 'bill_save'.tr, onPressed: _save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
