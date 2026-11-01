import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/scripts_center/models/script_info.dart';
import 'package:aboutme/plugins/scripts_center/models/script_input.dart';
import 'package:aboutme/plugins/scripts_center/models/script_profile.dart';
import 'package:aboutme/plugins/scripts_center/models/script_trigger.dart';
import 'package:aboutme/plugins/scripts_center/services/script_manager.dart';
import 'package:aboutme/plugins/scripts_center/widgets/script_input_form.dart';
import 'package:aboutme/utils/file_picker_helper.dart';
import 'package:aboutme/widgets/form_fields/form_builder_wrapper.dart';
import 'package:aboutme/widgets/form_fields/config.dart';
import 'package:aboutme/widgets/form_fields/types.dart';
import 'package:aboutme/widgets/form_fields/event_multi_select_field.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:get/get.dart';

part 'script_edit_screen_advanced.dart';
part 'script_edit_screen_basic_info.dart';
part 'script_edit_screen_code.dart';
part 'script_edit_screen_config.dart';
part 'script_edit_screen_inputs.dart';
part 'script_edit_screen_save.dart';
part 'script_edit_screen_triggers.dart';

/// 脚本编辑屏幕
///
/// 完整的脚本编辑界面（DS 风格：DSLightHeader 头部 +
/// 底部弧形导航切换分区），包含：
/// - 基本信息编辑
/// - 代码编辑器
/// - 高级设置（含触发条件、输入参数）
/// - 配置
///
/// 实现按功能拆分为多个 part 文件（extension 扩展 State）：
/// - script_edit_screen_basic_info.dart：基本信息 Tab
/// - script_edit_screen_code.dart：代码编辑 Tab + 本地文件
/// - script_edit_screen_advanced.dart：高级设置 Tab 表单
/// - script_edit_screen_inputs.dart：输入参数管理
/// - script_edit_screen_triggers.dart：触发条件管理
/// - script_edit_screen_config.dart：配置 Tab + 配置文件管理
/// - script_edit_screen_save.dart：保存提交流程
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

  // 基本信息 Tab 的表单状态
  final GlobalKey<FormBuilderState> _basicInfoFormKey =
      GlobalKey<FormBuilderState>();
  FormBuilderWrapperState? _basicInfoWrapperState;

  // 高级设置 Tab 的表单状态
  final GlobalKey<FormBuilderState> _advancedFormKey =
      GlobalKey<FormBuilderState>();
  FormBuilderWrapperState? _advancedWrapperState;

  // 配置 Tab 的状态
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

  // 存储基本信息表单的值（用于提交时合并）
  Map<String, dynamic>? _basicInfoValues;

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

    // 上报路由上下文，供"询问当前上下文"识别
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isEdit = widget.script != null;
      RouteHistoryManager.updateCurrentContext(
        pageId: '/scripts_center/edit',
        title: widget.script?.name ?? 'scripts_center_newScript'.tr,
        params: {
          'mode': isEdit ? '编辑' : (widget.initialData != null ? '导入' : '新建'),
          'scriptName': widget.script?.name ?? '',
        },
      );
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return Scaffold(
            backgroundColor: dsScaffoldBackground(theme),
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // 轻量手绘顶栏：返回圆钮 + 居中标题 + 保存按钮
                  DSLightHeader(
                    title: isEditMode
                        ? 'scripts_center_editScript'.tr
                        : 'scripts_center_createNewScript'.tr,
                    trailing: DSIconButton(
                      icon: DsIconKind.check,
                      size: 38,
                      color: theme.primary,
                      iconColor: theme.onPrimary,
                      tooltip:
                          isEditMode
                              ? 'scripts_center_save'.tr
                              : 'scripts_center_create'.tr,
                      onPressed: _saveScript,
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
}
