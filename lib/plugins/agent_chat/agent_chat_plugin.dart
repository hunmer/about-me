import 'package:flutter/foundation.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/config_manager.dart';
import 'package:aboutme/core/services/plugin_data_selector/index.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'controllers/conversation_controller.dart';
import 'screens/conversation_list_screen/conversation_list_screen.dart';
import 'screens/chat_screen/chat_screen.dart';
import 'screens/agent_chat_settings_screen.dart';
import 'services/tool_template_service.dart';
import 'services/widget_service.dart';
import 'services/route_agent_config_service.dart';
import 'services/shortcuts_handler_service.dart';
import 'services/conversation_sync_service.dart';
import 'services/watch_connectivity_service.dart';
import 'models/agent_chain_node.dart';
import 'repositories/client_agent_chat_repository.dart';
import 'package:shared_models/shared_models.dart';

part 'agent_chat_data_selectors.dart';

/// Agent Chat 插件
///
/// 专注于一对一AI对话的极简聊天插件
///
/// 主要功能：
/// - 多会话管理（分组、搜索、筛选）
/// - Agent绑定（每个会话一个Agent）
/// - 文件上传（图片+文档，多文件）
/// - 上下文管理（全局+会话级设置）
/// - Token统计（全局+每条消息）
/// - 流式响应（打字机效果）
/// - 消息编辑/删除/重新生成
/// - Markdown渲染
class AgentChatPlugin extends PluginBase with ChangeNotifier {
  static AgentChatPlugin? _instance;
  static AgentChatPlugin get instance => _instance!;

  ConversationController? _conversationController;
  ConversationController? get conversationController => _conversationController;

  @override
  List<PluginSampleDataGroup> getSampleDataGroups() => [
    PluginSampleDataGroup(
      id: 'conversations',
      title: 'agentChat_sampleConversationsTitle'.tr,
      description: 'agentChat_sampleConversationsDesc'.tr,
      apply: () async {
        final controller = _conversationController;
        if (controller == null) return;
        await controller.conversationService.loadSampleData();
      },
    ),
  ];

  ToolTemplateService? _templateService;
  ToolTemplateService? get templateService =>
      _templateService ??= ToolTemplateService(storage);

  RouteAgentConfigService? _routeConfigService;
  RouteAgentConfigService? get routeConfigService => _routeConfigService;

  /// UseCase 业务逻辑层
  late final AgentChatUseCase agentChatUseCase;

  /// 检查是否已初始化
  bool get isInitialized =>
      _conversationController != null && _conversationController!.isInitialized;

  AgentChatPlugin() {
    // BuiltinPlugins.createAll() is also used to list disabled plugins in
    // settings. Those temporary instances must not replace the registered one.
    _instance ??= this;
  }

  @override
  String get id => 'agent_chat';

  @override
  IconData? get icon => Icons.chat_bubble_outline;

  @override
  Color? get color => const Color(0xFF2196F3);

  @override
  Future<void> initialize() async {
    // 加载插件配置（包括语音识别配置等）
    await loadSettings({});

    // 初始化控制器
    _conversationController = ConversationController(storage: storage);
    await _conversationController!.initialize();

    // 创建 Repository 实例
    final repository = ClientAgentChatRepository(
      conversationService: _conversationController!.conversationService,
      messageService: _conversationController!.messageService,
      pluginColor: color ?? Colors.blue,
    );

    // 初始化 UseCase
    agentChatUseCase = AgentChatUseCase(repository);

    // 初始化路由配置服务
    _routeConfigService = RouteAgentConfigService(storage: storage);
    await _routeConfigService!.initialize();

    // 初始化小组件服务
    await AgentChatWidgetService.initialize();

    // 初始化 iOS Shortcuts 处理服务（仅 iOS）
    if (!kIsWeb && UniversalPlatform.isIOS) {
      ShortcutsHandlerService.instance.initialize();
      debugPrint('[AgentChatPlugin] iOS Shortcuts 处理服务已启动');

      // 初始同步频道列表到 iOS
      await ConversationSyncService.instance.syncConversationsToIOS(
        _conversationController!.conversationService,
      );

      // 初始化 WatchConnectivity 服务（用于与 Apple Watch 通信）
      WatchConnectivityService.initialize(
        conversationService: _conversationController!.conversationService,
        messageService: _conversationController!.messageService,
      );
      debugPrint('[AgentChatPlugin] WatchConnectivity 服务已启动');
    }

    // 注册数据选择器
    _registerDataSelectors();
  }

  @override
  Future<void> registerToApp(
    PluginManager pluginManager,
    ConfigManager configManager,
  ) async {
    // 调用初始化方法
    // 插件已在 initialize() 中完成初始化
    // 这里可以添加额外的应用级注册逻辑
  }

  @override
  Widget buildMainView(BuildContext context) {
    return const AgentChatMainView();
  }

  @override
  String? getPluginName(context) {
    return 'agent_chat_pluginName'.tr;
  }

  @override
  Future<bool> refreshData([PluginRefreshDataArgs? args]) async {
    final controller = _conversationController;
    if (controller == null) return false;
    try {
      await controller.refresh();
      return true;
    } catch (e) {
      debugPrint('[AgentChatPlugin] 刷新会话失败: $e');
      return false;
    }
  }

  @override
  bool get hasSettingsView => true;

  @override
  Widget buildSettingsView(BuildContext context) {
    return AgentChatSettingsScreen(plugin: this);
  }

  // ==================== 小组件统计方法 ====================

  /// 获取总对话数
  int getTotalConversationsCount() {
    try {
      return conversationController?.conversations.length ?? 0;
    } catch (e) {
      debugPrint('获取总对话数失败: $e');
      return 0;
    }
  }

  /// 获取今日消息数
  /// 统计所有会话中今天发送的消息总数（本地时区当天，与 SDK handler 同源）
  Future<int> getTodayMessagesCount() async {
    try {
      final res = await AboutmeDataService.instance.get(
        'agent_chat',
        'getStats',
      );
      if (res['success'] == true && res['data'] is Map) {
        return ((res['data'] as Map)['todayMessageCount'] as int?) ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('获取今日消息数失败: $e');
      return 0;
    }
  }

  /// 获取活跃会话数
  /// 定义: 最近7天内有消息的会话
  Future<int> getActiveConversationsCount() async {
    try {
      final controller = conversationController;
      if (controller == null) {
        debugPrint('conversationController 未初始化');
        return 0;
      }

      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      int count = 0;

      for (final conversation in controller.conversations) {
        // 检查lastMessageAt是否在7天内
        if (conversation.lastMessageAt != null &&
            conversation.lastMessageAt.isAfter(sevenDaysAgo)) {
          count++;
        }
      }

      return count;
    } catch (e) {
      debugPrint('获取活跃会话数失败: $e');
      return 0;
    }
  }

  // ==================== 临时频道管理 ====================

  /// 为上下文查询创建全新临时会话
  ///
  /// 同路由已存在临时会话时先删除（含消息），保证每次打开都是全新会话；
  /// 路由的 Agent 配置记忆（saveRouteAgentConfig）不受影响
  Future<Conversation> createFreshTemporaryConversation({
    required String routeName,
    required String title,
    String? agentId,
    List<AgentChainNode>? agentChain,
  }) async {
    final controller = conversationController;
    if (controller == null) {
      throw Exception('conversationController 未初始化');
    }

    // 删除同路由的旧临时会话（含消息），避免历史残留与堆积
    final existing = controller.conversationService
        .getTemporaryConversationForRoute(routeName);
    if (existing != null) {
      await controller.conversationService.deleteConversation(existing.id);
    }

    debugPrint('为路由 $routeName 创建全新的临时会话');
    return controller.conversationService.createTemporaryConversation(
      title: title,
      routeName: routeName,
      agentId: agentId,
      agentChain: agentChain,
    );
  }

  /// 保存路由的 Agent 配置
  Future<void> saveRouteAgentConfig(
    String routeName,
    String? agentId,
    List<AgentChainNode>? agentChain,
  ) async {
    final routeConfig = _routeConfigService;
    if (routeConfig == null) {
      debugPrint('routeConfigService 未初始化');
      return;
    }

    final config = RouteAgentConfig(agentId: agentId, agentChain: agentChain);

    await routeConfig.saveConfig(routeName, config);
    debugPrint('已保存路由 $routeName 的 Agent 配置');
  }

  /// 获取路由的 Agent 配置
  RouteAgentConfig? getRouteAgentConfig(String routeName) {
    return _routeConfigService?.getConfig(routeName);
  }
}

/// Agent Chat 主视图（路由入口）
class AgentChatMainView extends StatefulWidget {
  /// 可选的对话ID - 如果提供，将直接打开该对话的聊天界面
  final String? conversationId;

  const AgentChatMainView({super.key, this.conversationId});

  @override
  State<AgentChatMainView> createState() => _AgentChatMainViewState();
}

class _AgentChatMainViewState extends State<AgentChatMainView> {
  late Future<void> _initializeFuture;

  @override
  void initState() {
    super.initState();
    final plugin = AgentChatPlugin.instance;

    // 如果已初始化，直接完成；否则等待初始化
    _initializeFuture = plugin.isInitialized
        ? Future.value()
        : _waitForInitialization();

    // 如果传入了conversationId，在初始化完成后直接打开对话
    if (widget.conversationId != null) {
      _initializeFuture.then((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openConversation();
        });
      });
    }
  }

  Future<void> _waitForInitialization() async {
    final plugin = AgentChatPlugin.instance;

    // 等待插件初始化（最多等待5秒）
    int attempts = 0;
    while (!plugin.isInitialized && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (!plugin.isInitialized) {
      throw Exception('插件初始化超时');
    }
  }

  /// 打开指定的对话
  Future<void> _openConversation() async {
    if (!mounted || widget.conversationId == null) return;

    try {
      final plugin = AgentChatPlugin.instance;
      final controller = plugin.conversationController;

      if (controller == null) {
        debugPrint('conversationController 未初始化');
        return;
      }

      // 查找指定的对话
      final conversation = controller.conversations.firstWhere(
        (c) => c.id == widget.conversationId,
        orElse: () => throw Exception('对话不存在'),
      );

      // 导航到聊天界面
      await NavigationHelper.push(
        context,
        ChatScreen(
          conversation: conversation,
          storage: controller.storage,
          conversationService: controller.conversationService,
          getSettings: () => plugin.settings,
        ),
      );
    } catch (e) {
      if (mounted) {
        toastService.showToast('打开对话失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: DSThemeBridge(child: DSLoadingDots())),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: DSThemeBridge(
              child: Builder(
                builder: (context) {
                  final theme = DSThemeBridge.resolve(context);
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DsIcon(DsIconKind.close, size: 48, color: theme.danger),
                        const SizedBox(height: 16),
                        Text(
                          'agent_chat_initializationFailed'.trParams({
                            'error': '${snapshot.error}',
                          }),
                          style: DsTypography.body.copyWith(color: theme.text),
                        ),
                        const SizedBox(height: 16),
                        DSButton(
                          label: 'agent_chat_goBack'.tr,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        }

        return const ConversationListScreen();
      },
    );
  }
}
