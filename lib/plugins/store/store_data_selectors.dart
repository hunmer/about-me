part of 'store_plugin.dart';

// ==================== 数据选择器注册 ====================

/// 注册数据选择器
void _registerDataSelectors() {
  final selectorService = PluginDataSelectorService.instance;

  // 注册积分目标配置选择器（表单类型）
  selectorService.registerSelector(
    SelectorDefinition(
      id: 'store.pointsGoalForm',
      pluginId: StorePlugin.instance.id,
      name: '积分目标配置',
      description: '设置每日积分目标',
      icon: Icons.flag,
      color: Colors.orange,
      searchable: false,
      selectionMode: SelectionMode.single,
      steps: [
        // 直接使用自定义表单视图
        SelectorStep(
          id: 'goal_input',
          title: '设置每日积分目标',
          viewType: SelectorViewType.customForm,
          isFinalStep: true,
          dataLoader: (_) async {
            // 返回空列表，因为使用自定义UI
            return [];
          },
          customFormBuilder: (context, previousSelections, onComplete) {
            return _CustomGoalInputForm(onComplete: onComplete);
          },
        ),
      ],
    ),
  );

  // 注册商品选择器
  selectorService.registerSelector(
    SelectorDefinition(
      id: 'store.product',
      pluginId: StorePlugin.instance.id,
      name: 'store_productSelectorName'.tr,
      description: 'store_productSelectorDesc'.tr,
      icon: StorePlugin.instance.icon,
      color: StorePlugin.instance.color,
      searchable: true,
      selectionMode: SelectionMode.single,
      steps: [
        SelectorStep(
          id: 'product',
          title: 'store_selectProduct'.tr,
          viewType: SelectorViewType.grid,
          isFinalStep: true,
          dataLoader: (_) async {
            return StorePlugin.instance.controller.products.map((product) {
              // 构建副标题：价格 + 库存
              final subtitle =
                  '${product.price} ${'store_points'.tr} · ${'store_stockLabel'.tr}: ${product.stock}';

              return SelectableItem(
                id: product.id,
                title: product.name,
                subtitle: subtitle,
                icon: Icons.shopping_bag,
                rawData: product.toJson(),
              );
            }).toList();
          },
          searchFilter: (items, query) {
            if (query.isEmpty) return items;
            final lowerQuery = query.toLowerCase();
            return items.where((item) {
              final matchesTitle = item.title.toLowerCase().contains(
                lowerQuery,
              );
              final productData = item.rawData as Map<String, dynamic>;
              final description = productData['description'] as String? ?? '';
              final matchesDescription = description.toLowerCase().contains(
                lowerQuery,
              );
              return matchesTitle || matchesDescription;
            }).toList();
          },
        ),
      ],
    ),
  );

  // 注册用户物品选择器
  selectorService.registerSelector(
    SelectorDefinition(
      id: 'store.userItem',
      pluginId: StorePlugin.instance.id,
      name: 'store_userItemSelectorName'.tr,
      description: 'store_userItemSelectorDesc'.tr,
      icon: Icons.inventory_2,
      color: StorePlugin.instance.color,
      searchable: true,
      selectionMode: SelectionMode.single,
      steps: [
        SelectorStep(
          id: 'userItem',
          title: 'store_selectUserItem'.tr,
          viewType: SelectorViewType.list,
          isFinalStep: true,
          dataLoader: (_) async {
            return StorePlugin.instance.controller.userItems.map((item) {
              final productName = item.productName.isEmpty ? '未知物品' : item.productName;
              final remaining = item.remaining;
              final expireDate = item.expireDate;
              final remainingDays =
                  expireDate.difference(DateTime.now()).inDays;

              // 构建副标题：剩余次数 + 过期信息
              String subtitle;
              if (remainingDays < 0) {
                subtitle = '$remaining ${'store_times'.tr} · 已过期';
              } else if (remainingDays <= 7) {
                subtitle =
                    '$remaining ${'store_times'.tr} · 剩余 $remainingDays 天';
              } else {
                subtitle = '$remaining ${'store_times'.tr}';
              }

              return SelectableItem(
                id: item.id,
                title: productName,
                subtitle: subtitle,
                icon: Icons.inventory_2,
                rawData: {
                  ...item.toJson(),
                  'description': item.productDescription,
                },
              );
            }).toList();
          },
          searchFilter: (items, query) {
            if (query.isEmpty) return items;
            final lowerQuery = query.toLowerCase();
            return items.where((item) {
              final matchesTitle = item.title.toLowerCase().contains(
                lowerQuery,
              );
              final itemData = item.rawData as Map<String, dynamic>;
              final description = itemData['description'] as String? ?? '';
              final matchesDescription = description.toLowerCase().contains(
                lowerQuery,
              );
              return matchesTitle || matchesDescription;
            }).toList();
          },
        ),
      ],
    ),
  );
}

/// 自定义目标输入表单
class _CustomGoalInputForm extends StatefulWidget {
  final Function(dynamic) onComplete;

  const _CustomGoalInputForm({required this.onComplete});

  @override
  State<_CustomGoalInputForm> createState() => _CustomGoalInputFormState();
}

class _CustomGoalInputFormState extends State<_CustomGoalInputForm> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isValid = false;
  // DSInput 无 Form 校验，手动维护错误文案
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // 原 TextFormField 的 autofocus 行为：首帧后聚焦
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNode.canRequestFocus) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 校验输入（返回错误文案，null 表示通过）
  String? _validate(String value) {
    if (value.isEmpty) {
      return '请输入目标值';
    }
    final number = int.tryParse(value);
    if (number == null) {
      return '请输入有效的数字';
    }
    if (number <= 0) {
      return '目标值必须大于0';
    }
    if (number > 10000) {
      return '目标值不能超过10000';
    }
    return null;
  }

  void _submit() {
    final error = _validate(_controller.text);
    if (mounted) {
      setState(() {
        _errorText = error;
        _isValid = error == null;
      });
    }
    if (error == null) {
      final value = int.tryParse(_controller.text);
      if (value != null && value > 0) {
        widget.onComplete({'goal': value});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 说明文字（DS 暂无旗帜/奖杯图标，用 star 近似）
              DsIcon(DsIconKind.star, size: 64, color: theme.primary),
              const SizedBox(height: 24),
              Text(
                '设置你的每日积分目标',
                style: DsTypography.display.copyWith(color: theme.text),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '输入一个正整数作为你的每日目标',
                style: DsTypography.body.copyWith(color: theme.textSub),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // 输入框
              DSInput(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                label: '目标积分',
                hint: '例如：50',
                errorText: _errorText,
                prefix: DsIcon(DsIconKind.star, size: 18, color: theme.textSub),
                suffix: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '积分',
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                ),
                onChanged: (value) {
                  // 更新按钮状态
                  final isValid = _validate(value) == null;
                  if (_isValid != isValid) {
                    setState(() {
                      _isValid = isValid;
                    });
                  }
                },
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),

              // 推荐目标
              Text(
                '推荐目标：',
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    [20, 50, 100, 200].map((value) {
                      return DSButton(
                        label: '$value',
                        variant: DSButtonVariant.secondary,
                        size: DSButtonSize.sm,
                        onPressed: () {
                          _controller.text = value.toString();
                          setState(() {
                            _errorText = null;
                            _isValid = true;
                          });
                          _submit();
                        },
                      );
                    }).toList(),
              ),
              const Spacer(),

              // 确定按钮
              DSButton(
                label: '确定',
                size: DSButtonSize.lg,
                onPressed: _isValid ? _submit : null,
              ),
            ],
          );
        },
      ),
    );
  }
}
