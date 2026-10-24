import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/data/sdk_media_service.dart';
import 'package:aboutme/core/services/plugin_data_selector/index.dart';
import 'package:aboutme/core/services/clipboard_service.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/core/widgets/custom_bottom_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:aboutme/plugins/base_plugin.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/config_manager.dart';
import 'package:aboutme/core/js_bridge/js_bridge_plugin.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/plugins/openai/aliveness/services/memory_service.dart';
import 'package:aboutme/plugins/openai/aliveness/services/memory_extraction_service.dart';
import 'package:aboutme/plugins/openai/aliveness/services/proactive_service.dart';
import 'package:aboutme/plugins/openai/moments/models/moment_post.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'package:aboutme/plugins/openai/moments/services/agent_assets_service.dart';
import 'package:aboutme/plugins/openai/moments/services/image_gen_service.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:shared_models/usecases/openai/openai_usecase.dart';
import 'package:aboutme/widgets/preset_edit_form.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart'
    show AgentChatMainView;
import 'repositories/client_openai_repository.dart';
import 'screens/agent_list_screen.dart';
import 'screens/plugin_settings_screen.dart';
import 'screens/prompt_preset_screen.dart';
import 'screens/agent_edit_screen.dart';
import 'screens/topic_collection_screen.dart';
import 'handlers/chat_event_handler.dart';
import 'controllers/agent_controller.dart';
import 'controllers/provider_controller.dart';
import 'controllers/service_provider_controller.dart';
import 'controllers/model_controller.dart';
import 'services/request_service.dart';
import 'services/chat_assistant_service.dart';
import 'services/topic_chat_service.dart';
import 'models/ai_agent.dart';
import 'widgets/onboarding_provider_setup.dart';
import 'services/prompt_preset_service.dart';
import 'sample_data.dart';

part 'openai_js_api.dart';
part 'openai_data_selectors.dart';
part 'moments_js_api.dart';

class OpenAIPlugin extends BasePlugin with JSBridgePlugin {
  static OpenAIPlugin? _instance;
  static OpenAIPlugin get instance {
    if (_instance == null) {
      _instance = PluginManager.instance.getPlugin('openai') as OpenAIPlugin?;
      if (_instance == null) {
        throw StateError('OpenAIPlugin has not been initialized');
      }
    }
    return _instance!;
  }

  final ChatEventHandler _chatEventHandler = ChatEventHandler();

  /// 支持刷新的文件路径前缀
  static const List<String> _refreshableFiles = ['openai/'];

  @override
  bool supportsFileRefresh(String filePath) {
    return _refreshableFiles.any((f) => filePath.startsWith(f));
  }

  @override
  Future<bool> refreshData([PluginRefreshDataArgs? args]) async {
    try {
      debugPrint('[OpenAIPlugin] 开始刷新数据, 文件: ${args?.filePath}');
      // OpenAI 插件的数据是通过 AgentController 等动态加载的
      // 重新加载数据会自动在下次访问时进行
      debugPrint('[OpenAIPlugin] 数据刷新成功');
      return true;
    } catch (e) {
      debugPrint('[OpenAIPlugin] 数据刷新失败: $e');
      return false;
    }
  }

  // UseCase 实例
  late final OpenAIUseCase _useCase;

  /// 获取 UseCase 实例
  OpenAIUseCase get useCase => _useCase;

  @override
  Map<String, Function> defineJSAPI() {
    return {
      // AI 助手管理
      'getAgents': _jsGetAgents,
      'getAgent': _jsGetAgent,
      'sendMessage': _jsSendMessage,

      // 活人感记忆查询（LLM 工具调用）
      'search_memory': _jsSearchMemory,

      // 朋友圈 / 资产图 / 生图（LLM 工具调用）
      'generate_image': _jsGenerateImage,
      'post_moment': _jsPostMoment,
      'list_agent_assets': _jsListAgentAssets,

      // 服务商管理
      'getProviders': _jsGetProviders,
      'testProvider': _jsTestProvider,
    };
  }

  @override
  String get id => 'openai';

  @override
  Color get color => Colors.deepOrange;

  @override
  Future<void> initialize() async {
    // 加载插件配置（defaultProviderId 等）
    await loadSettings(const {});

    // Initialize default service providers
    await initializeDefaultData();

    // 启动时按版本创建或升级内置聊天助手。
    await ChatAssistantService.ensureBuiltinAgent();

    // 进入 app 时按 version 同步内置话题合集目录到数据目录
    await TopicChatService.instance.syncBuiltinCollections();

    // 初始化聊天事件处理器
    _chatEventHandler.initialize();

    // 启动活人感主动消息调度（周期检查开环/闲置触发，含三重硬限制）
    ProactiveService.instance.start();
    await MemoryExtractionService.instance.start();

    // 初始化 UseCase
    _initializeUseCase();

    // 注册数据选择器
    _registerDataSelectors();

    // 注册剪贴板处理器
    _registerClipboardHandler();

    // 注册 JS API（最后一步）
    await registerJSAPI();
  }

  /// 初始化 UseCase
  void _initializeUseCase() {
    // 创建控制器实例
    final agentController = AgentController();
    final serviceProviderController = ServiceProviderController();
    final modelController = ModelController();

    // 创建 Repository 实例
    final repository = ClientOpenAIRepository(
      agentController: agentController,
      serviceProviderController: serviceProviderController,
      modelController: modelController,
    );

    // 创建 UseCase 实例
    _useCase = OpenAIUseCase(repository);
  }

  /// 注册剪贴板处理器
  void _registerClipboardHandler() {
    ClipboardService.instance.registerHandler(
      'openai_agent_import',
      _handleAgentImport,
    );
  }

  /// 处理 Agent 导入
  Future<void> _handleAgentImport(Map<String, dynamic> args) async {
    try {
      // 验证必需字段
      if (args['id'] == null || args['name'] == null) {
        debugPrint('[OpenAIPlugin] 导入失败：缺少必需字段');
        return;
      }

      final agent = AIAgent.fromJson(args);

      // 获取当前 context
      final context = Get.context;
      if (context == null) {
        debugPrint('[OpenAIPlugin] 无法获取 context');
        return;
      }

      // 显示导入确认对话框
      final confirmed = await showDSDialog<bool>(
        context: context,
        theme: DSThemeBridge.resolve(context),
        builder: (dialogContext) => DSThemeBridge(
          child: Builder(
            builder: (dialogContext) {
              final theme = DSThemeBridge.resolve(dialogContext);
              return DSDialog(
                title: 'openai_importAgent'.tr,
                message: 'openai_importAgentConfirm'.tr,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'openai_nameLabel'.tr}: ${agent.name}',
                      style: DsTypography.body.copyWith(
                        color: theme.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (agent.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${'openai_descriptionLabel'.tr}: ${agent.description}',
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ],
                    if (agent.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        children: agent.tags
                            .map((tag) => DSChip(label: tag))
                            .toList(),
                      ),
                    ],
                  ],
                ),
                confirmText: 'openai_import'.tr,
                cancelText: 'openai_cancel'.tr,
                onConfirm: () => Navigator.of(dialogContext).pop(true),
                onCancel: () => Navigator.of(dialogContext).pop(false),
              );
            },
          ),
        ),
      );

      if (confirmed != true) return;

      // 生成新的 ID 避免冲突
      final newAgent = agent.copyWith(
        id: const Uuid().v4(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 保存 Agent
      final agentController = AgentController();
      await agentController.saveAgent(newAgent);

      Toast.success('openai_agentImported'.tr);
    } catch (e) {
      debugPrint('[OpenAIPlugin] 导入 Agent 失败: $e');
      Toast.error('openai_importFailed'.tr);
    }
  }

  @override
  Future<void> initializeDefaultData() async {
    // 确保 agents.json 文件存在并初始化默认智能体
    final agentData = await _readAgentsFile();
    if (agentData == null || agentData.isEmpty) {
      // 文件为空时写入全部默认智能体（开发/正式环境一致）
      final defaultAgents = OpenAISampleData.defaultAgents;
      final avatarMap = await _copyBundledAgentAvatars(
        defaultAgents.map((agent) => agent['avatarUrl']).whereType<String>(),
      );
      for (final agent in defaultAgents) {
        final url = agent['avatarUrl'];
        if (url is String && avatarMap.containsKey(url)) {
          agent['avatarUrl'] = avatarMap[url];
        }
      }

      await AboutmeDataService.instance.call('openai', 'saveAgents', {
        'agents': {'agents': defaultAgents},
      });
      debugPrint('已初始化 ${defaultAgents.length} 个默认智能体');
    }

    // 初始化提示词预设数据
    await _initializePromptPresets();
  }

  /// 把打包在应用内的默认头像（assets/agents/）上传为 SDK 资源，
  /// 返回 旧 asset 路径 -> 'asset://...' 资源引用 映射。
  Future<Map<String, String>> _copyBundledAgentAvatars(
    Iterable<String> assetPaths,
  ) async {
    final migrated = <String, String>{};
    for (final assetPath in assetPaths.toSet()) {
      if (!assetPath.startsWith('assets/agents/')) continue;
      try {
        final byteData = await rootBundle.load(assetPath);
        final asset = await SdkMediaService.uploadBytes(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
          assetPath.substring('assets/agents/'.length),
        );
        migrated[assetPath] = asset.reference;
      } catch (e) {
        debugPrint('[OpenAIPlugin] 上传默认头像失败: $assetPath, $e');
      }
    }
    return migrated;
  }

  /// 初始化提示词预设数据
  Future<void> _initializePromptPresets() async {
    try {
      final res = await AboutmeDataService.instance.call(
        'openai',
        'getPresets',
      );
      final presetData = res['success'] == true ? res['data'] : null;
      if (presetData is! Map ||
          presetData.isEmpty ||
          presetData['presets'] == null) {
        // 如果没有预设数据，使用示例数据中的默认预设
        final defaultPresets = OpenAISampleData.defaultPresets;

        await AboutmeDataService.instance.call('openai', 'savePresets', {
          'presets': {
            'presets': defaultPresets.map((p) => p.toJson()).toList(),
          },
        });
        debugPrint('已初始化 ${defaultPresets.length} 个默认提示词预设');
      }
    } catch (e) {
      debugPrint('初始化提示词预设失败: $e');
    }
  }

  @override
  Widget buildMainView(BuildContext context) {
    return Localizations.override(
      context: context,
      child: const OpenAIMainView(),
    );
  }

  @override
  List<PluginOnboardingStep> getOnboardingSteps(BuildContext context) => [
    PluginOnboardingStep(
      icon: Icons.smart_toy,
      title: 'openai_onboardingWelcomeTitle'.tr,
      description: 'openai_onboardingWelcomeDesc'.tr,
    ),
    PluginOnboardingStep(
      icon: Icons.tune,
      title: 'openai_onboardingSetupTitle'.tr,
      description: 'openai_onboardingSetupDesc'.tr,
      builder: (context, values) => OnboardingProviderSetup(values: values),
    ),
  ];

  @override
  Future<void> onOnboardingComplete(
    BuildContext context,
    Map<String, dynamic> values,
  ) async {
    await _applyOnboardingConfig(values);
  }

  /// 应用引导收集的厂商 / 模型 / API Key 配置
  ///
  /// 未填写 API Key 时跳过（引导仍可完成）。填写后：
  /// 1. 更新 providers.json 中对应厂商（真实 Key 替换占位符 + 默认模型）
  /// 2. 应用到所有仍带占位符配置的默认 Agent（含内置 Agent）
  /// 3. 记录为新建 Agent 的默认厂商
  Future<void> _applyOnboardingConfig(Map<String, dynamic> values) async {
    final providerId = values['providerId'] as String?;
    final apiKey = (values['apiKey'] as String?)?.trim() ?? '';
    final model = (values['model'] as String?)?.trim() ?? '';
    if (providerId == null || providerId.isEmpty || apiKey.isEmpty) return;

    try {
      final providerController = ProviderController();
      final providers = await providerController.getProviders();
      final index = providers.indexWhere((p) => p.id == providerId);
      if (index == -1) return;
      final preset = providers[index];
      final updated = preset.copyWith(
        headers: preset.headers.map(
          (key, value) =>
              MapEntry(key, value.replaceAll('YOUR_API_KEY', apiKey)),
        ),
        defaultModel: model.isNotEmpty ? model : preset.defaultModel,
      );
      await providerController.updateProvider(updated);

      final agentController = AgentController();
      final agents = await agentController.loadAgents();
      final updatedAgents = <AIAgent>[];
      for (final agent in agents) {
        // 仅覆盖仍带占位符 Key 的默认 Agent，不动用户已配置的
        final hasPlaceholder = agent.headers.values.any(
          (v) => v.contains('YOUR_API_KEY'),
        );
        if (!hasPlaceholder) continue;
        updatedAgents.add(
          agent.copyWith(
            serviceProviderId: updated.id,
            baseUrl: updated.baseUrl,
            headers: Map<String, String>.from(updated.headers),
            model: model.isNotEmpty ? model : agent.model,
            apiFormat: updated.apiFormat,
            updatedAt: DateTime.now(),
          ),
        );
      }
      await agentController.bulkSaveAgents(updatedAgents);

      await updateSettings({'defaultProviderId': updated.id});
      debugPrint('[OpenAIPlugin] 已应用引导配置: ${updated.label}');
    } catch (e) {
      debugPrint('[OpenAIPlugin] 应用引导配置失败: $e');
    }
  }

  @override
  bool get hasSettingsView => true;

  @override
  Widget buildSettingsView(BuildContext context) {
    return const PluginSettingsScreen();
  }

  @override
  Future<void> registerToApp(
    PluginManager pluginManager,
    ConfigManager configManager,
  ) async {
    // 插件已在 initialize() 中完成初始化
    // 这里可以添加额外的应用级注册逻辑
    // 注意：不要写 configs/openai/settings.json——那是 loadSettings 的
    // 持久化文件，覆盖会清空 defaultProviderId / multimodalModelConfig 等设置
  }

  /// 读取 agents.json 整文件（缺失/失败返回 null，对齐旧文件层"不存在
  /// 返回空对象由调用方兜底"的语义）
  Future<Map<String, dynamic>?> _readAgentsFile() async {
    try {
      final res = await AboutmeDataService.instance.call('openai', 'getAgents');
      final data = res['success'] == true ? res['data'] : null;
      if (data is Map<String, dynamic> && data.isNotEmpty) return data;
    } catch (e) {
      debugPrint('Error reading agents data: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> _getAgentsData() async {
    final agentData = await _readAgentsFile();
    return agentData ?? {'agents': <dynamic>[]};
  }

  @override
  Future<void> uninstall() async {
    // 数据分区保留（域已封闭，重装可恢复）；如需清空走 admin 后台删除

    // 停止主动消息调度
    ProactiveService.instance.stop();
    MemoryExtractionService.instance.stop();

    // 清理事件处理器
    _chatEventHandler.dispose();
  }

  /// 获取 AgentController 实例
  AgentController get controller => AgentController();

  // ==================== 小组件统计方法 ====================

  /// 获取总助手数（用户可见的，不含内置 agent）
  Future<int> getTotalAgentsCount() async {
    try {
      final agents = await controller.loadVisibleAgents();
      return agents.length;
    } catch (e) {
      debugPrint('获取总助手数失败: $e');
      return 0;
    }
  }

  /// 获取今日请求次数
  /// 注意: 当前实现返回0,因为项目中未实现请求历史记录功能
  Future<int> getTodayRequestCount() async {
    // TODO: 实现请求历史记录功能后,从存储中读取今日请求数
    // 可能的实现路径: openai/request_history.json
    return 0;
  }

  /// 获取可用模型数
  /// 统计所有模型的总数
  Future<int> getAvailableModelsCount() async {
    try {
      final modelController = ModelController();
      final modelGroups = await modelController.getModels();

      int totalModels = 0;
      for (final group in modelGroups) {
        totalModels += group.models.length;
      }

      return totalModels;
    } catch (e) {
      debugPrint('获取可用模型数失败: $e');
      return 0;
    }
  }

  @override
  IconData get icon => Icons.smart_toy;

  @override
  Widget buildCardView(BuildContext context) {
    return Localizations.override(
      context: context,
      child: _buildCardViewContent(context),
    );
  }

  @override
  String? getPluginName(context) {
    return 'openai_name'.tr;
  }

  Widget _buildCardViewContent(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return FutureBuilder<Map<String, dynamic>>(
      future: _getAgentsData(),
      builder: (context, snapshot) {
        final agentsCount = (snapshot.data?['agents'] as List?)?.length ?? 0;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部图标和标题(插件注册表图标 Icons.smart_toy,属持久化 IconData,刻意保留 Material)
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 24, color: color),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'openai_name'.tr,
                    style: DsTypography.heading.copyWith(
                      color: theme.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 统计信息卡片
              Column(
                children: [
                  // 第一行 - 智能体总数和活跃智能体
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // 智能体总数
                      Column(
                        children: [
                          Text(
                            'openai_totalAgents'.tr,
                            style: DsTypography.body.copyWith(
                              color: theme.textSub,
                            ),
                          ),
                          Text(
                            '$agentsCount',
                            style: DsTypography.body.copyWith(
                              color: theme.text,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class OpenAIMainView extends StatefulWidget {
  const OpenAIMainView({super.key});

  @override
  State<OpenAIMainView> createState() => _OpenAIMainViewState();
}

class _OpenAIMainViewState extends State<OpenAIMainView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _currentPage;
  final GlobalKey _bottomBarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentPage = 0;
    _tabController = TabController(length: 4, vsync: this);
    _tabController.animation?.addListener(() {
      final value = _tabController.animation!.value.round();
      if (value != _currentPage && mounted) {
        setState(() {
          _currentPage = value;
        });
        // 更新路由上下文
        _updateRouteContext(value);
      }
    });

    // 初始化时设置路由上下文
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateRouteContext(_currentPage);
    });
  }

  /// 更新路由上下文，使"询问当前上下文"功能能获取到当前tab状态
  void _updateRouteContext(int tabIndex) {
    String pageId;
    String title;

    switch (tabIndex) {
      case 1:
        pageId = '/openai/presets';
        title = 'openai_promptPreset'.tr;
        break;
      case 2:
        pageId = '/openai/chat';
        title = 'agent_chat_aiChat'.tr;
        break;
      case 3:
        pageId = '/openai/topics';
        title = 'openai_topicsTab'.tr;
        break;
      default:
        pageId = '/openai/agents';
        title = 'openai_agentsTab'.tr;
    }

    RouteHistoryManager.updateCurrentContext(
      pageId: pageId,
      title: title,
      params: {'tabIndex': tabIndex},
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showPresetEditPage() async {
    // 预设编辑页为无名路由，手动上报编辑上下文，关闭后恢复当前tab上下文
    RouteHistoryManager.updateCurrentContext(
      pageId: '/openai/preset_edit',
      title: 'openai_promptPreset'.tr,
      params: {'mode': '新建', 'name': ''},
    );
    await showPresetEditPage(
      context: context,
      onSave: (preset, prompts) async {
        final service = PromptPresetService();
        await service.addPreset(preset);

        if (mounted) {
          Toast.success('openai_presetSaved'.tr);
          setState(() {});
        }
      },
    );
    if (mounted) _updateRouteContext(_currentPage);
  }

  /// 构建 FAB
  Widget _buildFab() {
    return DSThemeBridge(
      // DSFab 内部取 AppTheme，需包桥
      child: DSFab(
        onPressed: () {
          if (_currentPage == 0) {
            _showCreateAgentMenu();
          } else {
            _showPresetEditPage();
          }
        },
        color: Colors.deepOrange,
        iconColor: Colors.white,
        icon: _currentPage == 0 ? DsIconKind.bot : DsIconKind.clipboard,
      ),
    );
  }

  /// 新建智能体菜单：新建空白 / 智能创建（Soul Forge）
  void _showCreateAgentMenu() {
    SmoothBottomSheet.showWithTitle<void>(
      context: context,
      title: 'openai_newAgentMenu'.tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SmoothSheetAction(
            icon: DsIconKind.plus,
            label: 'openai_createBlankAgent'.tr,
            onTap: () {
              Navigator.pop(context);
              NavigationHelper.openContainerWithHero(context, (
                BuildContext context,
              ) {
                return AgentEditScreen();
              });
            },
          ),
          SmoothSheetAction(
            icon: DsIconKind.star,
            label: 'openai_smartCreate'.tr,
            onTap: () {
              Navigator.pop(context);
              NavigationHelper.openContainerWithHero(context, (
                BuildContext context,
              ) {
                return AgentEditScreen(autoOpenSoulForge: true);
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomBottomBar(
      currentIndex: _currentPage,
      tabController: _tabController,
      bottomBarKey: _bottomBarKey,
      body: (context, controller) => TabBarView(
        controller: _tabController,
        dragStartBehavior: DragStartBehavior.down,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          AgentListScreen(),
          PromptPresetScreen(),
          AgentChatMainView(),
          TopicCollectionScreen(),
        ],
      ),
      // 会话列表自带导航栏"+"入口，话题 tab 的操作在页内，
      // 该两个 tab 下隐藏 FAB 避免重复
      fab: _currentPage >= 2 ? null : _buildFab(),
      items: [
        DSNavItem(icon: DsIconKind.bot, label: 'openai_agentsTab'.tr),
        DSNavItem(icon: DsIconKind.book, label: 'openai_promptPreset'.tr),
        DSNavItem(icon: DsIconKind.chat, label: 'agent_chat_aiChat'.tr),
        DSNavItem(icon: DsIconKind.category, label: 'openai_topicsTab'.tr),
      ],
    );
  }
}
