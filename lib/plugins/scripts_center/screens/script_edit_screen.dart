import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:super_cupertino_navigation_bar/utils/persistent_nav_bar.dart';
import 'package:super_cupertino_navigation_bar/utils/navigation_bar_static_components.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/scripts_center/models/script_info.dart';
import 'package:aboutme/plugins/scripts_center/models/script_input.dart';
import 'package:aboutme/plugins/scripts_center/models/script_profile.dart';
import 'package:aboutme/plugins/scripts_center/models/script_trigger.dart';
import 'package:aboutme/plugins/scripts_center/services/script_manager.dart';
import 'package:aboutme/plugins/scripts_center/widgets/script_input_edit_dialog.dart';
import 'package:aboutme/utils/file_picker_helper.dart';
import 'package:aboutme/widgets/form_fields/form_builder_wrapper.dart';
import 'package:aboutme/widgets/form_fields/config.dart';
import 'package:aboutme/widgets/form_fields/types.dart';
import 'package:aboutme/widgets/form_fields/event_multi_select_field.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:get/get.dart';

/// 脚本编辑屏幕
///
/// 完整的脚本编辑界面（DS 风格：PersistentNavigationBar 头部 +
/// 底部弧形导航切换分区），包含：
/// - 基本信息编辑
/// - 代码编辑器
/// - 高级设置（含触发条件、输入参数）
/// - 配置
class ScriptEditScreen extends StatefulWidget {
  /// 如果为null则为创建模式，否则为编辑模式
  final ScriptInfo? script;

  /// 脚本管理器（用于加载代码）
  final ScriptManager scriptManager;

  /// 初始数据（用于导入模式）
  final Map<String, dynamic>? initialData;

  const ScriptEditScreen({
    super.key,
    this.script,
    required this.scriptManager,
    this.initialData,
  });

  @override
  State<ScriptEditScreen> createState() => _ScriptEditScreenState();
}

/// 事件选项
class _EventOption {
  final String eventName;
  final String category;
  final String description;

  _EventOption(this.eventName, this.category, this.description);
}

class _ScriptEditScreenState extends State<ScriptEditScreen> {
  /// 底部导航当前分区：0 基本信息 / 1 代码 / 2 高级设置 / 3 配置
  int _currentTabIndex = 0;

  /// 已访问过的分区（首次访问才构建，之后保留状态）。
  /// 不一次挂载全部分区：配置分区的表单带 ValueKey+GlobalKey，
  /// 打开瞬间与异步加载同时做子树迁移会触发框架断言
  final List<int> _visitedTabs = [0];

  /// PersistentNavigationBar 组件 key（GlobalKey 需跨帧稳定，不能每次 build 新建）
  final NavigationBarStaticComponentsKeys _navBarKeys =
      NavigationBarStaticComponentsKeys();

  // 基本信息 Tab 的表单状态
  final GlobalKey<FormBuilderState> _basicInfoFormKey =
      GlobalKey<FormBuilderState>();
  FormBuilderWrapperState? _basicInfoWrapperState;

  // 高级设置 Tab 的表单状态
  final GlobalKey<FormBuilderState> _advancedFormKey =
      GlobalKey<FormBuilderState>();
  FormBuilderWrapperState? _advancedWrapperState;

  // 配置 Tab 的状态
  final GlobalKey<FormBuilderState> _configFormKey =
      GlobalKey<FormBuilderState>();
  FormBuilderWrapperState? _configWrapperState;

  // 配置文件列表（profile）：同一配置表单的多组值
  List<ScriptProfile> _profiles = [];

  // 当前正在编辑的配置文件 id
  String _currentProfileId = 'default';

  // 默认配置文件 id（执行未指定时使用）
  String? _defaultProfileId;

  /// 配置是否已从磁盘加载完成（完成后才构建配置表单，确保 initialValue 正确）
  bool _configLoaded = false;

  // 配置表单字段定义（用于动态渲染配置界面）
  List<FormFieldConfig> _configFormFields = [];

  // 代码编辑器控制器
  late final TextEditingController _codeController;

  // 输入参数列表
  List<ScriptInput> _inputs = [];

  // 触发条件列表
  List<ScriptTrigger> _triggers = [];

  // 是否自动运行
  bool _autoRun = false;

  // 本地脚本文件路径
  String? _localScriptPath;

  // 图标名称到 IconData 的映射
  static const Map<String, IconData> _iconMap = {
    'code': Icons.code,
    'backup': Icons.backup,
    'analytics': Icons.analytics,
    'settings': Icons.settings,
    'sync': Icons.sync,
    'schedule': Icons.schedule,
    'notification': Icons.notifications,
    'data': Icons.storage,
    'auto': Icons.autorenew,
    'star': Icons.star,
    'favorite': Icons.favorite,
    'build': Icons.build,
  };

  // IconData 到图标名称的反向映射（不能是 const，因为 IconData 重写了 == 和 hashCode）
  static final Map<IconData, String> _iconNameMap = {
    Icons.code: 'code',
    Icons.backup: 'backup',
    Icons.analytics: 'analytics',
    Icons.settings: 'settings',
    Icons.sync: 'sync',
    Icons.schedule: 'schedule',
    Icons.notifications: 'notification',
    Icons.storage: 'data',
    Icons.autorenew: 'auto',
    Icons.star: 'star',
    Icons.favorite: 'favorite',
    Icons.build: 'build',
  };

  // 可用事件列表（从项目中收集的所有事件）
  final List<_EventOption> _availableEvents = [
    // 核心事件
    _EventOption('plugins_initialized', '插件系统', '所有插件初始化完成'),

    // 日记插件事件
    _EventOption('diary_entry_created', '日记', '创建日记条目'),
    _EventOption('diary_entry_updated', '日记', '更新日记条目'),
    _EventOption('diary_entry_deleted', '日记', '删除日记条目'),

    // 活动插件事件
    _EventOption('activity_added', '活动', '添加活动记录'),
    _EventOption('activity_deleted', '活动', '删除活动记录'),

    // 笔记插件事件
    _EventOption('note_added', '笔记', '添加笔记'),
    _EventOption('note_deleted', '笔记', '删除笔记'),

    // 任务插件事件
    _EventOption('task_added', '任务', '添加任务'),
    _EventOption('task_deleted', '任务', '删除任务'),
    _EventOption('task_completed', '任务', '完成任务'),

    // 签到插件事件
    _EventOption('checkin_completed', '签到', '完成签到'),
    _EventOption('checkin_deleted', '签到', '删除签到记录'),

    // 账单插件事件
    _EventOption('bill_added', '账单', '添加账单'),
    _EventOption('bill_deleted', '账单', '删除账单'),
    _EventOption('account_added', '账单', '添加账户'),
    _EventOption('account_deleted', '账单', '删除账户'),

    // 物品管理事件
    _EventOption('goods_item_added', '物品', '添加物品'),
    _EventOption('goods_item_deleted', '物品', '删除物品'),

    // 聊天插件事件
    _EventOption('chat_message_sent', '聊天', '发送消息'),
    _EventOption('chat_message_updated', '聊天', '更新消息'),
    _EventOption('UserEventNames.userAvatarUpdated', '聊天', '更新用户头像'),

    // 追踪器事件
    _EventOption('onRecordAdded', '追踪器', '添加记录'),

    // 计时器事件
    _EventOption('timer_task_changed', '计时器', '任务变更'),
    _EventOption('timer_item_changed', '计时器', '项目变更'),
    _EventOption('timer_item_progress', '计时器', '项目进度更新'),

    // 商店事件
    _EventOption('store_product_added', '商店', '添加商品'),
    _EventOption('store_product_deleted', '商店', '删除商品'),
    _EventOption('store_purchase', '商店', '购买商品'),

    // 习惯插件事件
    _EventOption('habit_added', '习惯', '添加习惯'),
    _EventOption('habit_deleted', '习惯', '删除习惯'),
    _EventOption('habit_checked', '习惯', '打卡习惯'),

    // 联系人事件
    _EventOption('contact_added', '联系人', '添加联系人'),
    _EventOption('contact_deleted', '联系人', '删除联系人'),

    // 纪念日事件
    _EventOption('memorial_day_added', '纪念日', '添加纪念日'),
    _EventOption('memorial_day_deleted', '纪念日', '删除纪念日'),

    // 日历事件
    _EventOption('calendar_event_added', '日历', '添加事件'),
    _EventOption('calendar_event_deleted', '日历', '删除事件'),
  ];

  bool get isEditMode => widget.script != null;

  /// 根据图标名称获取 IconData
  IconData _getIconData(String iconName) {
    return _iconMap[iconName] ?? Icons.code;
  }

  /// 根据 IconData 获取图标名称
  String _getIconName(IconData icon) {
    return _iconNameMap[icon] ?? 'code';
  }

  @override
  void initState() {
    super.initState();

    // 初始化代码控制器
    _codeController = TextEditingController();

    // 处理初始数据（导入模式）或编辑模式
    if (widget.initialData != null) {
      // 导入模式
      _localScriptPath = widget.initialData!['localScriptPath'] as String?;
      _codeController.text = widget.initialData!['code'] as String? ?? '';

      if (widget.initialData!['inputs'] != null) {
        _inputs =
            (widget.initialData!['inputs'] as List<dynamic>)
                .cast<ScriptInput>();
      }

      if (widget.initialData!['triggers'] != null) {
        _triggers =
            (widget.initialData!['triggers'] as List<dynamic>)
                .map((e) => ScriptTrigger.fromJson(e as Map<String, dynamic>))
                .toList();
      }

      if (widget.initialData!['config'] != null) {
        _applyProfilesData(widget.initialData!['config']);
      }

      // 解析 configFormFields
      if (widget.initialData!['configFormFields'] != null) {
        _configFormFields = _parseConfigFormFieldsFromJson(
          widget.initialData!['configFormFields'],
        );
      }
      // 导入模式无需读盘，配置直接就绪
      _configLoaded = true;
    } else if (widget.script != null) {
      // 编辑模式
      _inputs = List.from(widget.script!.inputs);
      _triggers = List.from(widget.script!.triggers);
      _autoRun = widget.script!.autoRun;
      _localScriptPath = widget.script!.localScriptPath;
      _configFormFields = widget.script!.configFormFields;

      // 异步加载代码
      _loadScriptCode();
      // 异步加载配置
      _loadScriptConfig();
    } else {
      // 新建模式：无已存配置，直接放行
      _configLoaded = true;
    }
  }

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
      final configPath =
          'configs/scripts_center/${widget.script!.id}_config.json';
      final data = await AboutmeDataService.instance.readPath(configPath);
      print('[ScriptConfigDebug] 8.打开编辑屏读取配置: $configPath -> $data');
      if (!mounted) return;
      // 注意：文件不存在时 read 返回空 Map（非 null），同样标记加载完成
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

  /// 加载脚本代码
  Future<void> _loadScriptCode() async {
    if (widget.script == null) return;

    try {
      final code = await widget.scriptManager.getScriptCode(widget.script!.id);
      if (code != null && mounted) {
        _codeController.text = code;
      }
    } catch (e) {
      // 加载失败，保持空代码
      debugPrint('Failed to load script code: $e');
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// 存储基本信息表单的值（用于提交时合并）
  Map<String, dynamic>? _basicInfoValues;

  /// 验证并保存
  void _saveScript() {
    print('[ScriptConfigDebug] 1.保存按钮触发, 基本信息表单state=${_basicInfoWrapperState != null ? "已初始化" : "null"}');
    _basicInfoWrapperState?.submitForm();
  }

  /// 处理基本信息表单提交
  void _handleBasicInfoSubmit(Map<String, dynamic> values) {
    // 检查widget是否仍然mounted
    if (!mounted) {
      print('[ScriptConfigDebug] 2.基本信息提交: widget已unmounted, 中断!');
      return;
    }

    print('[ScriptConfigDebug] 2.基本信息提交成功, values=$values');

    // 保存基本信息表单的值
    _basicInfoValues = values;

    // 检查高级设置表单是否已初始化
    if (_advancedWrapperState != null) {
      // 如果已初始化，提交表单获取值
      print('[ScriptConfigDebug] 3.提交高级设置表单');
      _advancedWrapperState!.submitForm();
    } else {
      // 如果未初始化，使用默认值直接保存
      print('[ScriptConfigDebug] 3.高级设置表单未初始化(用户没切到该Tab), 用默认值');
      _handleAdvancedSubmit(_getDefaultAdvancedValues());
    }
  }

  /// 获取高级设置的默认值
  Map<String, dynamic> _getDefaultAdvancedValues() {
    final script = widget.script;
    return {
      'type': script?.type ?? 'module',
      'enabled': script?.enabled ?? true,
      'updateUrl': script?.updateUrl ?? '',
    };
  }

  /// 处理高级设置表单提交（最终提交）
  void _handleAdvancedSubmit(Map<String, dynamic> advancedValues) {
    // 检查widget是否仍然mounted
    if (!mounted) {
      print('[ScriptConfigDebug] 4.高级设置提交: widget已unmounted, 中断!');
      return;
    }

    print('[ScriptConfigDebug] 4.高级设置提交, advancedValues=$advancedValues');

    // 在保存前，获取配置表单的最新值（如果已初始化），写入当前配置文件
    if (_configWrapperState != null) {
      final configValues = _configWrapperState!.currentValues;
      if (configValues.isNotEmpty) {
        _currentProfile.values = configValues;
      }
    }
    // 未初始化时各配置文件的 values 保持加载/实时同步的值

    // 获取保存的基本信息表单的值
    final basicValues = _basicInfoValues ?? {};

    // 验证必填字段
    final name = basicValues['name']?.toString().trim() ?? '';
    if (name.isEmpty && widget.initialData == null) {
      toastService.showToast('请输入脚本名称');
      return;
    }

    // 在新建模式下，id必填；如果没有填写，自动从name生成
    String id = basicValues['id']?.toString().trim() ?? '';
    if (id.isEmpty && !isEditMode) {
      // 使用拼音或简化名称生成id（这里简化为使用小写+下划线）
      id = name
          .toLowerCase()
          .replaceAll(RegExp(r'[\s\u4e00-\u9fa5]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      if (id.isEmpty) {
        id = 'script_${DateTime.now().millisecondsSinceEpoch}';
      }
      toastService.showToast('已自动生成脚本ID: $id');
    }

    // 从 icon 字段中提取图标名称（circleIconPicker 返回 Map）
    String iconValue = 'code';
    if (basicValues['icon'] != null) {
      if (basicValues['icon'] is Map) {
        final iconMap = basicValues['icon'] as Map;
        final iconData = iconMap['icon'] as IconData?;
        iconValue = iconData != null ? _getIconName(iconData) : 'code';
      } else if (basicValues['icon'] is String) {
        iconValue = basicValues['icon'] as String;
      }
    }

    // 合并两个表单的数据
    final scriptData = {
      'name': name,
      'id': id,
      'description': basicValues['description']?.toString().trim() ?? '',
      'author': basicValues['author']?.toString().trim() ?? '',
      'version': basicValues['version']?.toString().trim() ?? '1.0.0',
      'icon': iconValue,
      'type': advancedValues['type']?.toString() ?? 'module',
      'enabled': advancedValues['enabled'] as bool? ?? true,
      'autoRun': _autoRun,
      'code': _codeController.text,
      'inputs': _inputs,
      'triggers': _triggers.map((t) => t.toJson()).toList(),
      'updateUrl':
          advancedValues['updateUrl']?.toString().trim().isEmpty == true
              ? null
              : advancedValues['updateUrl']?.toString().trim(),
      'localScriptPath': _localScriptPath,
    };

    // 保存配置文件（如果有配置表单字段）
    if (_configFormFields.isNotEmpty) {
      _ensureProfiles();
      scriptData['config'] = {
        'profiles': _profiles.map((p) => p.toJson()).toList(),
        'defaultProfileId': _defaultProfileId ?? _profiles.first.id,
      };
    }

    // 保存配置表单字段定义（如果有）
    if (_configFormFields.isNotEmpty) {
      scriptData['configFormFields'] = _configFormFields;
    }

    // 再次检查mounted，因为这是在异步回调中
    if (mounted) {
      Navigator.of(context).pop(scriptData);
    }
  }

  /// 添加输入参数
  Future<void> _addInput() async {
    final input = await showDialog<ScriptInput>(
      context: context,
      builder: (context) => const ScriptInputEditDialog(),
    );

    if (input != null) {
      setState(() {
        _inputs.add(input);
      });
    }
  }

  /// 编辑输入参数
  Future<void> _editInput(int index) async {
    final input = await showDialog<ScriptInput>(
      context: context,
      builder: (context) => ScriptInputEditDialog(input: _inputs[index]),
    );

    if (input != null) {
      setState(() {
        _inputs[index] = input;
      });
    }
  }

  /// 删除输入参数
  void _deleteInput(int index) {
    setState(() {
      _inputs.removeAt(index);
    });
  }

  /// 根据输入类型获取对应图标
  IconData _getInputTypeIcon(String type) {
    switch (type) {
      case 'string':
        return Icons.text_fields;
      case 'number':
        return Icons.numbers;
      case 'boolean':
        return Icons.toggle_on;
      case 'select':
        return Icons.list;
      default:
        return Icons.input;
    }
  }

  /// 选择本地脚本文件
  Future<void> _pickLocalScriptFile() async {
    final files = await FilePickerHelper.pickFiles(multiple: false);
    if (files.isNotEmpty) {
      final file = files.first;
      setState(() {
        _localScriptPath = file.path;
      });

      // 自动加载文件内容
      try {
        final content = await file.readAsString();
        _codeController.text = content;
        toastService.showToast('已加载文件内容');
      } catch (e) {
        toastService.showToast('加载文件失败: $e');
      }
    }
  }

  /// 清除本地文件路径
  void _clearLocalScriptPath() {
    setState(() {
      _localScriptPath = null;
    });
  }

  /// 获取基本信息表单字段配置
  List<FormFieldConfig> _getBasicInfoFields() {
    final theme = DSThemeBridge.resolve(context);
    final script = widget.script;
    final initialData = widget.initialData;

    // 优先使用initialData中的值，其次使用script中的值
    final iconName = initialData?['icon'] as String? ?? script?.icon ?? 'code';
    final iconData = _getIconData(iconName);

    return [
      // 图标选择 - 使用 circleIconPicker
      FormFieldConfig(
        name: 'icon',
        type: FormFieldType.circleIconPicker,
        labelText: 'scripts_center_icon'.tr,
        initialValue: {'icon': iconData, 'color': theme.primary},
        extra: {
          'initialBackgroundColor': theme.primary,
          'showLabel': true,
          'labelText': 'scripts_center_selectIcon'.tr,
        },
      ),

      // 脚本名称
      FormFieldConfig(
        name: 'name',
        type: FormFieldType.text,
        labelText: 'scripts_center_scriptName'.tr,
        hintText: '例如：自动备份助手',
        prefixIcon: Icons.title,
        initialValue: initialData?['name'] as String? ?? script?.name ?? '',
        required: true,
        validationMessage: '请输入脚本名称',
      ),

      // 脚本ID
      FormFieldConfig(
        name: 'id',
        type: FormFieldType.text,
        labelText: 'scripts_center_scriptId'.tr,
        hintText: '例如：auto_backup',
        prefixIcon: Icons.fingerprint,
        initialValue: initialData?['id'] as String? ?? script?.id ?? '',
        required: true,
        enabled: !isEditMode, // 编辑模式下不可修改
        validationMessage: '请输入脚本ID',
        extra: {
          'inputFormatters': [RegExp(r'^[a-z0-9_]+$')],
        },
      ),

      // 描述
      FormFieldConfig(
        name: 'description',
        type: FormFieldType.textArea,
        labelText: 'scripts_center_description'.tr,
        hintText: '简短描述脚本的功能',
        prefixIcon: Icons.description,
        initialValue:
            initialData?['description'] as String? ?? script?.description ?? '',
        extra: {'maxLines': 3},
      ),

      // 作者
      FormFieldConfig(
        name: 'author',
        type: FormFieldType.text,
        labelText: 'scripts_center_author'.tr,
        hintText: '例如：张三',
        prefixIcon: Icons.person,
        initialValue: initialData?['author'] as String? ?? script?.author ?? '',
      ),

      // 版本号
      FormFieldConfig(
        name: 'version',
        type: FormFieldType.text,
        labelText: 'scripts_center_version'.tr,
        hintText: '例如：1.0.0',
        prefixIcon: Icons.tag,
        initialValue:
            initialData?['version'] as String? ?? script?.version ?? '1.0.0',
        required: true,
        validationMessage: '请输入版本号',
      ),
    ];
  }

  /// 获取高级设置表单字段配置
  List<FormFieldConfig> _getAdvancedFields() {
    final script = widget.script;
    return [
      // 脚本类型
      FormFieldConfig(
        name: 'type',
        type: FormFieldType.select,
        labelText: 'scripts_center_scriptType'.tr,
        prefixIcon: Icons.category,
        initialValue: script?.type ?? 'module',
        required: true,
        items: [
          DropdownMenuItem(
            value: 'module',
            child: Text('scripts_center_moduleType'.tr),
          ),
          DropdownMenuItem(
            value: 'standalone',
            child: Text('scripts_center_standaloneType'.tr),
          ),
        ],
      ),

      // 更新地址
      FormFieldConfig(
        name: 'updateUrl',
        type: FormFieldType.text,
        labelText: 'scripts_center_updateUrl'.tr,
        hintText: '例如：https://example.com/script.js',
        prefixIcon: Icons.cloud_download,
        initialValue: script?.updateUrl ?? '',
      ),

      // 启用开关
      FormFieldConfig(
        name: 'enabled',
        type: FormFieldType.switchField,
        labelText: 'scripts_center_enableScript'.tr,
        hintText: script?.enabled == true ? '脚本将在触发条件满足时执行' : '脚本已禁用，不会执行',
        prefixIcon: script?.enabled == true ? Icons.check_circle : Icons.cancel,
        initialValue: script?.enabled ?? true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return Scaffold(
            backgroundColor: theme.background,
            body: Column(
              children: [
                // Super Cupertino 风格的固定 header（super_cupertino_navigation_bar
                // 包内 PersistentNavigationBar，与 SuperAppBar 展开态同源；
                // 自带默认工具栏高度，无需再给定高父级）
                PersistentNavigationBar(
                  components: NavigationBarStaticComponents(
                    keys: _navBarKeys,
                    route: null,
                    // NavigationToolbar 对 leading 施加紧高度约束会把按钮
                    // 拉变形，用 Align 转成宽松约束保持正圆（包内返回键同款）
                    userLeading: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DSIconButton(
                        icon: DsIconKind.chevronLeft,
                        size: 36,
                        color: theme.surfaceAlt,
                        iconColor: theme.textSub,
                        tooltip: 'core_back'.tr,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    automaticallyImplyLeading: false,
                    automaticallyImplyTitle: false,
                    previousPageTitle: null,
                    userMiddle: Text(
                      isEditMode
                          ? 'scripts_center_editScript'.tr
                          : 'scripts_center_createNewScript'.tr,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                    userTrailing: DSIconButton(
                      icon: DsIconKind.check,
                      size: 36,
                      color: theme.primary,
                      iconColor: theme.onPrimary,
                      tooltip:
                          isEditMode
                              ? 'scripts_center_save'.tr
                              : 'scripts_center_create'.tr,
                      onPressed: _saveScript,
                    ),
                    userLargeTitle: null,
                    largeTitleActions: null,
                    appbarBottom: null,
                    padding: null,
                    large: false,
                  ),
                ),

                // 已访问的编辑分区，IndexedStack 保留各分区状态
                Expanded(
                  child: IndexedStack(
                    index: _visitedTabs.indexOf(_currentTabIndex),
                    children: [for (final tab in _visitedTabs) _buildTab(tab)],
                  ),
                ),

                // 底部弧形导航：基本信息 / 代码 / 高级设置 / 配置
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.all(theme.spacing.lg),
                    child: DSBottomNavigation(
                      currentIndex: _currentTabIndex,
                      onTap: (index) {
                        setState(() {
                          if (!_visitedTabs.contains(index)) {
                            _visitedTabs.add(index);
                          }
                          _currentTabIndex = index;
                        });
                      },
                      items: [
                        DSNavItem(
                          icon: DsIconKind.info,
                          label: 'scripts_center_basicInfo'.tr,
                        ),
                        DSNavItem(
                          icon: DsIconKind.code,
                          label: 'scripts_center_codeEditor'.tr,
                        ),
                        DSNavItem(
                          icon: DsIconKind.gear,
                          label: 'scripts_center_advancedSettings'.tr,
                        ),
                        DSNavItem(
                          icon: DsIconKind.tune,
                          label: 'scripts_center_config'.tr,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 按分区序号构建对应内容
  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return _buildBasicInfoTab();
      case 1:
        return _buildCodeEditorTab();
      case 2:
        return _buildAdvancedTab();
      default:
        return _buildConfigTab();
    }
  }

  /// 构建基本信息标签页
  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: FormBuilderWrapper(
        formKey: _basicInfoFormKey,
        onStateReady: (state) => _basicInfoWrapperState = state,
        config: FormConfig(
          fields: _getBasicInfoFields(),
          showSubmitButton: false,
          showResetButton: false,
          fieldSpacing: 16,
          onSubmit: _handleBasicInfoSubmit,
        ),
      ),
    );
  }

  /// 构建代码编辑器标签页
  Widget _buildCodeEditorTab() {
    final theme = DSThemeBridge.resolve(context);
    return Column(
      children: [
        // 工具栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: theme.surfaceAlt,
          child: Row(
            children: [
              DsIcon(DsIconKind.code, size: 20, color: theme.primary),
              const SizedBox(width: 8),
              Text(
                'JavaScript 代码',
                style: DsTypography.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  // TODO: 添加代码格式化功能
                  toastService.showToast('代码格式化功能即将推出');
                },
                icon: const Icon(Icons.format_align_left, size: 18),
                label: Text('scripts_center_format'.tr),
              ),
            ],
          ),
        ),
        // 代码编辑器
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _codeController,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              decoration: const InputDecoration(
                hintText:
                    '// 在此输入 JavaScript 代码\n'
                    '// 例如：\n'
                    '// function execute(context, args) {\n'
                    '//   console.log("Hello from script!");\n'
                    '//   return { success: true };\n'
                    '// }',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(16),
              ),
              textAlignVertical: TextAlignVertical.top,
            ),
          ),
        ),
        // 本地文件路径选择
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: theme.backgroundAlt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DsIcon(DsIconKind.pin, size: 18, color: theme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '本地文件链接',
                    style: DsTypography.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.text,
                    ),
                  ),
                  const Spacer(),
                  if (_localScriptPath != null)
                    TextButton.icon(
                      onPressed: _clearLocalScriptPath,
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('清除'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.danger,
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _pickLocalScriptFile,
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('选择文件'),
                  ),
                ],
              ),
              if (_localScriptPath != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: theme.stroke),
                  ),
                  child: Row(
                    children: [
                      DsIcon(
                        DsIconKind.copy,
                        size: 16,
                        color: theme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _localScriptPath!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '初始化时将从此文件同步最新代码',
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ],
            ],
          ),
        ),
        // 提示信息
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: theme.surfaceAlt,
          child: Row(
            children: [
              DsIcon(DsIconKind.info, size: 16, color: theme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '脚本将在满足触发条件时执行。可以访问 context 对象获取应用上下文。',
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

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

  /// 构建高级设置标签页（含触发条件、输入参数）
  Widget _buildAdvancedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 使用 FormBuilderWrapper 构建高级设置表单
          FormBuilderWrapper(
            formKey: _advancedFormKey,
            onStateReady: (state) => _advancedWrapperState = state,
            config: FormConfig(
              fields: _getAdvancedFields(),
              showSubmitButton: false,
              showResetButton: false,
              fieldSpacing: 24,
              onSubmit: _handleAdvancedSubmit,
            ),
          ),

          const SizedBox(height: 24),

          // 触发条件（自动运行开关 + 触发器列表）
          _buildTriggersSection(),

          const SizedBox(height: 24),

          // 输入参数设置（保留原有逻辑）
          _buildInputsSection(),
        ],
      ),
    );
  }

  /// 构建输入参数部分
  Widget _buildInputsSection() {
    final theme = DSThemeBridge.resolve(context);
    final scriptType =
        _advancedFormKey.currentState?.value['type'] ??
        widget.script?.type ??
        'module';

    if (scriptType != 'module') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DsIcon(DsIconKind.clipboard, size: 20, color: theme.primary),
            const SizedBox(width: 8),
            Text(
              '输入参数',
              style: DsTypography.heading.copyWith(color: theme.text),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 参数列表
        if (_inputs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: theme.stroke),
              borderRadius: theme.radii.lg,
            ),
            child: Column(
              children: [
                DsIcon(DsIconKind.info, size: 40, color: theme.disabled),
                const SizedBox(height: 12),
                Text(
                  '暂无输入参数',
                  style: DsTypography.body.copyWith(color: theme.textSub),
                ),
                const SizedBox(height: 8),
                Text(
                  '为 Module 类型脚本添加输入参数，执行时会显示表单收集用户输入',
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._inputs.asMap().entries.map((entry) {
            final index = entry.key;
            final input = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border.all(color: theme.stroke),
                borderRadius: theme.radii.lg,
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.primary.withValues(alpha: 0.1),
                  child: Icon(
                    _getInputTypeIcon(input.type),
                    color: theme.primary,
                    size: 20,
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      input.label,
                      style: DsTypography.body.copyWith(
                        color: theme.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${input.key})',
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                    if (input.required) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.warning.withValues(alpha: 0.1),
                          borderRadius: theme.radii.sm,
                        ),
                        child: Text(
                          '必填',
                          style: DsTypography.caption.copyWith(
                            color: theme.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  input.description ?? '类型: ${input.type}',
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      color: theme.textSub,
                      onPressed: () => _editInput(index),
                      tooltip: '编辑',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      color: theme.danger,
                      onPressed: () => _deleteInput(index),
                      tooltip: '删除',
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 12),

        // 添加参数按钮
        DSButton(
          label: 'scripts_center_addInputParameter'.tr,
          icon: DsIconKind.plus,
          variant: DSButtonVariant.outline,
          onPressed: _addInput,
        ),
      ],
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
                        const Text(
                          '选择事件 *',
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
            // key 绑定当前配置文件 id：切换时表单重建，initialValue 换为新配置文件的值
            FormBuilderWrapper(
              key: ValueKey('config_profile_$_currentProfileId'),
              formKey: _configFormKey,
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
            child: const Text('确定'),
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
        title: const Text('删除配置文件'),
        content: Text('确定删除配置文件「${current.name}」？其配置值将丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('scripts_center_cancel'.tr),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
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
    return _iconMap[iconName];
  }
}
