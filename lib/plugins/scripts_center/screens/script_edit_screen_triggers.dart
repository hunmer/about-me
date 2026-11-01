// 脚本编辑：触发条件管理（自动运行开关 + 触发器列表/卡片/添加对话框）。
part of 'script_edit_screen.dart';

/// 触发条件拆分：扩展 [_ScriptEditScreenState]，与类内方法等价。
extension _ScriptEditTriggers on _ScriptEditScreenState {
  /// 构建触发条件区块（嵌入高级设置 Tab，随页面整体滚动）
  Widget _buildTriggersSection() {
    final theme = DSThemeBridge.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 自动运行开关
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.surfaceAlt,
            borderRadius: theme.radii.lg,
          ),
          child: Row(
            children: [
              DsIcon(DsIconKind.refresh, color: theme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自动运行',
                      style: DsTypography.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.primary,
                      ),
                    ),
                    Text(
                      '开启后将在插件初始化时自动执行此脚本',
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              DSSwitch(
                value: _autoRun,
                onChanged: (value) {
                  setState(() {
                    _autoRun = value;
                  });
                },
                activeColor: theme.primary,
              ),
            ],
          ),
        ),

        // 自动运行开启时隐藏触发条件选项
        if (!_autoRun) ...[
          const SizedBox(height: 16),

          // 标题行 + 添加触发器按钮
          Row(
            children: [
              Icon(Icons.bolt, color: theme.primary),
              const SizedBox(width: 8),
              Text(
                '触发条件',
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
              const Spacer(),
              DSButton(
                label: 'scripts_center_addTrigger'.tr,
                icon: DsIconKind.plus,
                size: DSButtonSize.sm,
                onPressed: _showAddTriggerDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 触发器列表（顺序排布，随页面滚动）
          if (_triggers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: theme.stroke),
                borderRadius: theme.radii.lg,
              ),
              child: Column(
                children: [
                  Icon(Icons.bolt_outlined, size: 40, color: theme.disabled),
                  const SizedBox(height: 8),
                  Text(
                    '暂无触发条件，点击右上角按钮添加',
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            for (var index = 0; index < _triggers.length; index++)
              _buildTriggerCard(index),
        ],
      ],
    );
  }

  /// 构建单个触发器卡片
  Widget _buildTriggerCard(int index) {
    final theme = DSThemeBridge.resolve(context);
    final trigger = _triggers[index];
    final eventOption = _availableEvents.firstWhere(
      (e) => e.eventName == trigger.event,
      orElse: () => _EventOption(trigger.event, '未知', trigger.event),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DSListItemCard(
        title: '${index + 1}. ${eventOption.eventName}',
        subtitle: [
          'scripts_center_categoryLabel'.trParams({
            'category': eventOption.category,
          }),
          'scripts_center_descriptionLabel'.trParams({
            'description': eventOption.description,
          }),
          if (trigger.delay != null && trigger.delay! > 0)
            'scripts_center_delayLabel'.trParams({
              'delay': trigger.delay!.toString(),
            }),
        ].join(' · '),
        iconColor: theme.primary,
        trailing: DSIconButton(
          icon: DsIconKind.trash,
          size: 32,
          color: theme.surfaceAlt,
          iconColor: theme.danger,
          tooltip: 'app_delete'.tr,
          onPressed: () {
            setState(() {
              _triggers.removeAt(index);
            });
          },
        ),
      ),
    );
  }

  /// 显示添加触发器对话框
  Future<void> _showAddTriggerDialog() async {
    // 初始化：从当前触发器中提取已有的事件
    List<String> selectedEvents = _triggers.map((t) => t.event).toList();

    // 获取第一个触发器的延迟作为默认值（如果有）
    int delay = _triggers.isNotEmpty && _triggers.first.delay != null
        ? _triggers.first.delay!
        : 0;
    final delayController = TextEditingController(text: delay.toString());

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('scripts_center_addTriggerCondition'.tr),
                  content: SizedBox(
                    width: 500,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 事件选择
                        Text('scripts_center_selectEventRequired'.tr,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final events = await showDialog<List<String>>(
                              context: context,
                              builder:
                                  (context) => EventSelectorDialog(
                                    availableEvents:
                                        _availableEvents
                                            .map(
                                              (e) => EventOption(
                                                eventName: e.eventName,
                                                category: e.category,
                                                description: e.description,
                                              ),
                                            )
                                            .toList(),
                                    initialSelectedEvents: selectedEvents,
                                    dialogTitle: '选择事件',
                                  ),
                            );
                            if (events != null) {
                              setDialogState(() {
                                selectedEvents = events;
                              });
                            }
                          },
                          icon: const Icon(Icons.event),
                          label: Text(
                            selectedEvents.isEmpty
                                ? '请选择事件（可多选）'
                                : '已选择 ${selectedEvents.length} 个事件',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 延迟设置
                        TextField(
                          controller: delayController,
                          decoration: const InputDecoration(
                            labelText: '延迟（毫秒）',
                            hintText: '0',
                            helperText: '触发后延迟多久执行脚本',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            delay = int.tryParse(value) ?? 0;
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('scripts_center_cancel'.tr),
                    ),
                    ElevatedButton(
                      onPressed:
                          selectedEvents.isEmpty
                              ? null
                              : () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('scripts_center_add'.tr),
                    ),
                  ],
                ),
          ),
    );

    if (result == true && selectedEvents.isNotEmpty) {
      setState(() {
        // 清空原有触发器，替换为新选择的触发器
        _triggers.clear();
        for (final event in selectedEvents) {
          _triggers.add(
            ScriptTrigger(event: event, delay: delay > 0 ? delay : null),
          );
        }
      });
    }

    delayController.dispose();
  }
}
