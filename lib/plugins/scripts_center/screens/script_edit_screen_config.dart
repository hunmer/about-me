// 脚本编辑：配置 Tab（配置文件 profile 管理与动态配置表单渲染、configFormFields JSON 解析）。
part of 'script_edit_screen.dart';

/// 配置管理拆分：扩展 [_ScriptEditScreenState]，与类内方法等价。
extension _ScriptEditConfig on _ScriptEditScreenState {
  /// 应用配置文件数据（兼容新 profiles 格式与旧扁平格式）
  void _applyProfilesData(dynamic data) {
    final parsed = ScriptProfiles.fromStorage(data);
    _profiles = parsed.profiles;
    _defaultProfileId = parsed.defaultProfileId;
    _currentProfileId = parsed.defaultProfile?.id ?? 'default';
  }

  /// 确保至少有一个配置文件
  void _ensureProfiles() {
    if (_profiles.isEmpty) {
      _profiles = [ScriptProfile(id: 'default', name: '默认')];
      _defaultProfileId ??= 'default';
      _currentProfileId = 'default';
    }
  }

  /// 当前正在编辑的配置文件
  ScriptProfile get _currentProfile {
    _ensureProfiles();
    return _profiles.firstWhere(
      (p) => p.id == _currentProfileId,
      orElse: () => _profiles.first,
    );
  }

  /// 加载脚本配置
  Future<void> _loadScriptConfig() async {
    if (widget.script == null) return;

    try {
      final result = await AboutmeDataService.instance.call(
        'scripts_center',
        'getConfig',
        {'scriptId': widget.script!.id},
      );
      final data = result['success'] == true ? result['data'] : null;
      if (!mounted) return;
      // 注意：配置不存在时 data 为 null，同样标记加载完成
      setState(() {
        _applyProfilesData(data);
        _configLoaded = true;
      });
    } catch (e) {
      debugPrint('Failed to load script config: $e');
      // 读取失败也要放行，避免配置页卡在 loading
      if (mounted) {
        setState(() => _configLoaded = true);
      }
    }
  }

  /// 构建配置标签页
  Widget _buildConfigTab() {
    // 优先使用导入的configFormFields，其次使用script的configFormFields
    final configFormFields =
        _configFormFields.isNotEmpty
            ? _configFormFields
            : widget.script?.configFormFields ?? [];

    final hasConfigFormFields = configFormFields.isNotEmpty;

    // 无配置字段的脚本不需要读配置，直接放行
    if (hasConfigFormFields && !_configLoaded) {
      // 已存配置异步加载完成前不构建表单：否则 initialValue 拿不到已存值，
      // 事后重建又会清掉用户正在填的内容
      return const Center(child: CircularProgressIndicator());
    }

    if (hasConfigFormFields) {
      // 使用 FormBuilderWrapper 动态渲染配置表单（构建时当前配置文件已就绪）
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 配置文件管理栏
            _buildProfileBar(),
            const SizedBox(height: 16),
            // key 绑定当前配置文件 id：切换时表单整体重建，initialValue 换为新配置文件的值。
            // 注意不可传外部共享的 formKey：GlobalKey 会跨 ValueKey 复活 FormBuilderState，
            // 其缓存的旧字段值会经 registerField 反向写入新字段，导致切换后表单值不变
            FormBuilderWrapper(
              key: ValueKey('config_profile_$_currentProfileId'),
              onStateReady: (state) => _configWrapperState = state,
              config: FormConfig(
                fields: _getConfigFormFields(),
                showSubmitButton: false,
                showResetButton: false,
                fieldSpacing: 16,
                onSubmit: _handleConfigSubmit,
                // 实时收集配置值：配置 Tab 可能在保存前被销毁（TabBarView 回收），
                // 保存瞬间再取值不可靠，改为变化即同步到当前配置文件
                onValuesChanged: (values) {
                  _currentProfile.values = values;
                },
              ),
            ),
          ],
        ),
      );
    }

    // 没有配置表单字段定义时显示说明界面
    return Center(
      child: DSEmptyState(
        emoji: '⚙️',
        title: '该脚本无需配置',
        message: '此脚本没有定义配置选项，可以直接使用',
      ),
    );
  }

  /// 构建配置文件管理栏（选择/新建/重命名/删除/设为默认）
  Widget _buildProfileBar() {
    final theme = DSThemeBridge.resolve(context);
    _ensureProfiles();
    final current = _currentProfile;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.primary.withValues(alpha: 0.06),
        borderRadius: theme.radii.lg,
        border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          DsIcon(DsIconKind.tune, size: 20, color: theme.primary),
          const SizedBox(width: 8),
          Text(
            '配置文件',
            style: DsTypography.body.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: current.id,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: _profiles
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (p.id == _defaultProfileId) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.star,
                              size: 14,
                              color: theme.warning,
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id != null && id != _currentProfileId) {
                  setState(() => _currentProfileId = id);
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            color: theme.primary,
            tooltip: '新建配置文件',
            onPressed: _addProfile,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 20, color: theme.textSub),
            tooltip: '配置文件操作',
            onSelected: (action) {
              switch (action) {
                case 'rename':
                  _renameProfile();
                case 'setDefault':
                  _setDefaultProfile();
                case 'delete':
                  _deleteProfile();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('重命名'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'setDefault',
                child: Row(
                  children: [
                    Icon(Icons.star_outline, size: 18),
                    SizedBox(width: 8),
                    Text('设为默认'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                enabled: _profiles.length > 1,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: theme.danger),
                    SizedBox(width: 8),
                    Text('删除', style: TextStyle(color: theme.danger)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 弹出配置文件名称输入对话框
  Future<String?> _showProfileNameDialog(String title, String initialName) {
    final controller = TextEditingController(text: initialName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '配置文件名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('scripts_center_cancel'.tr),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              }
            },
            child: Text('app_ok'.tr),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  /// 新建配置文件（值复制当前配置文件，便于微调）
  Future<void> _addProfile() async {
    final name = await _showProfileNameDialog('新建配置文件', '');
    if (name == null) return;

    setState(() {
      final current = _currentProfile;
      final id = 'profile_${DateTime.now().millisecondsSinceEpoch}';
      _profiles.add(
        ScriptProfile(
          id: id,
          name: name,
          values: Map<String, dynamic>.from(current.values),
        ),
      );
      _currentProfileId = id;
    });
  }

  /// 重命名当前配置文件
  Future<void> _renameProfile() async {
    final current = _currentProfile;
    final name = await _showProfileNameDialog('重命名配置文件', current.name);
    if (name == null) return;

    setState(() => current.name = name);
  }

  /// 将当前配置文件设为默认
  void _setDefaultProfile() {
    setState(() => _defaultProfileId = _currentProfile.id);
    toastService.showToast('已设为默认配置文件');
  }

  /// 删除当前配置文件（至少保留一个）
  Future<void> _deleteProfile() async {
    if (_profiles.length <= 1) {
      toastService.showToast('至少保留一个配置文件');
      return;
    }

    final current = _currentProfile;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('scripts_center_deleteConfigFile'.tr),
        content: Text('确定删除配置文件「${current.name}」？其配置值将丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('scripts_center_cancel'.tr),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('app_delete'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _profiles.removeWhere((p) => p.id == current.id);
      if (_defaultProfileId == current.id) {
        _defaultProfileId = _profiles.first.id;
      }
      _currentProfileId = _defaultProfileId ?? _profiles.first.id;
    });
  }

  /// 获取配置表单字段
  List<FormFieldConfig> _getConfigFormFields() {
    // 优先使用导入的configFormFields，其次使用script的configFormFields
    final fields =
        _configFormFields.isNotEmpty
            ? _configFormFields
            : widget.script?.configFormFields ?? [];

    // 当前配置文件的值
    final currentValues = _currentProfile.values;

    // 为需要可用事件列表的字段添加 extra 数据
    return fields.map((field) {
      if (field.type == FormFieldType.eventMultiSelect) {
        // 添加可用事件列表到 extra
        final availableEvents =
            _availableEvents
                .map(
                  (e) => {
                    'eventName': e.eventName,
                    'category': e.category,
                    'description': e.description,
                  },
                )
                .toList();

        return FormFieldConfig(
          name: field.name,
          type: field.type,
          labelText: field.labelText,
          hintText: field.hintText,
          initialValue: currentValues[field.name],
          required: field.required,
          validationMessage: field.validationMessage,
          enabled: field.enabled,
          prefixIcon: field.prefixIcon,
          extra: {'eventMultiSelect': true, 'availableEvents': availableEvents},
        );
      }

      // 设置初始值
      return FormFieldConfig(
        name: field.name,
        type: field.type,
        labelText: field.labelText,
        hintText: field.hintText,
        initialValue: currentValues[field.name] ?? field.initialValue,
        required: field.required,
        validationMessage: field.validationMessage,
        enabled: field.enabled,
        prefixIcon: field.prefixIcon,
        extra: field.extra,
      );
    }).toList();
  }

  /// 处理配置表单提交
  void _handleConfigSubmit(Map<String, dynamic> values) {
    setState(() {
      _currentProfile.values = values;
    });
  }

  /// 从JSON解析配置表单字段
  List<FormFieldConfig> _parseConfigFormFieldsFromJson(dynamic jsonList) {
    if (jsonList == null) return [];

    if (jsonList is! List) return [];

    return jsonList.map<FormFieldConfig>((item) {
      final json = item as Map<String, dynamic>;
      final typeName = json['type'] as String?;

      // 构建 extra 字段，处理 pluginDataSelector 和 eventMultiSelect
      Map<String, dynamic>? extra;
      if (typeName == 'pluginDataSelector') {
        final pluginDataType = json['pluginDataType'] as String?;
        final fieldMapping = json['fieldMapping'] as Map<String, dynamic>?;
        if (pluginDataType != null || fieldMapping != null) {
          extra = <String, dynamic>{};
          if (pluginDataType != null) {
            extra['pluginDataType'] = pluginDataType;
          }
          if (fieldMapping != null && fieldMapping.isNotEmpty) {
            extra['fieldMapping'] = fieldMapping;
          }
        }
      } else if (typeName == 'eventMultiSelect') {
        extra = {'eventMultiSelect': true};
      } else {
        extra = json['extra'] as Map<String, dynamic>?;
      }

      // 解析基础字段
      return FormFieldConfig(
        name: json['name'] as String,
        type: FormFieldType.values.firstWhere(
          (e) => e.name == typeName,
          orElse: () => FormFieldType.text,
        ),
        labelText: json['labelText'] as String?,
        hintText: json['hintText'] as String?,
        initialValue: json['initialValue'],
        required: json['required'] as bool? ?? false,
        validationMessage: json['validationMessage'] as String?,
        enabled: json['enabled'] as bool? ?? true,
        prefixIcon: _parseIconData(json['prefixIcon'] as String?),
        extra: extra,
      );
    }).toList();
  }

  /// 解析图标名称为IconData
  IconData? _parseIconData(String? iconName) {
    if (iconName == null) return null;
    return _ScriptEditScreenState._iconMap[iconName];
  }
}
