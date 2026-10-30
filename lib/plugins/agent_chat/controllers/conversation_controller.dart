import 'package:flutter/foundation.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/item_event_args.dart';
import 'package:aboutme/plugins/agent_chat/services/conversation_service.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';

/// 会话控制器
///
/// 统一管理会话和消息服务，提供状态管理
class ConversationController extends ChangeNotifier {
  final StorageManager storage;
  late final ConversationService conversationService;
  late final MessageService messageService;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 当前选中的会话ID
  String? _currentConversationId;

  /// 搜索关键词
  String _searchQuery = '';

  /// 选中的分组过滤器（空列表表示显示所有）
  final List<String> _selectedGroupFilters = [];

  /// 选中的Agent过滤器（null表示不显示带 Agent 的会话）
  /// Agent 过滤哨兵值：表示【本插件】（agentId == null 的手动创建会话）
  static const String localPluginFilter = '__local_plugin__';

  /// "全部"（null 或空串）：不按 Agent 过滤；
  /// [localPluginFilter]：仅本插件手动创建会话；其他：指定 Agent 的会话
  String? _selectedAgentFilter = localPluginFilter;

  /// 默认上下文消息数量（全局设置）
  int _defaultContextMessageCount = 10;

  ConversationController({required this.storage}) {
    conversationService = ConversationService(storage: storage);
    messageService = MessageService(storage: storage);

    // 监听服务变化
    conversationService.addListener(_onServiceChanged);
    messageService.addListener(_onServiceChanged);

    // 远端变更（REST/MCP/其它设备写入）→ 局部重载刷新
    _cancelDataSync = AboutmeDataService.instance.onPluginChanged(
      'agent_chat',
      refresh,
    );
  }

  /// 数据同步事件订阅取消句柄
  VoidCallback? _cancelDataSync;

  // ========== Getters ==========

  bool get isInitialized => _isInitialized;
  bool get isLoading => conversationService.isLoading;

  List<Conversation> get conversations => _getFilteredConversations();

  String? get currentConversationId => _currentConversationId;
  Conversation? get currentConversation =>
      _currentConversationId != null
          ? conversationService.getConversation(_currentConversationId!)
          : null;

  List<ChatMessage> get currentMessages => messageService.currentMessages;

  /// 获取所有会话（包括未过滤的），用于提取分组名称
  /// 注意：只返回非临时会话，临时会话不会显示在列表中
  List<Conversation> get allConversations => conversationService.getNonTemporaryConversations();

  /// 建议问题测试创建的会话（不进主列表，展示于测试会话列表）
  List<Conversation> get testConversations =>
      conversationService.getTestConversations();

  String get searchQuery => _searchQuery;
  List<String> get selectedGroupFilters => _selectedGroupFilters;
  String? get selectedAgentFilter => _selectedAgentFilter;
  int get defaultContextMessageCount => _defaultContextMessageCount;

  // ========== 初始化 ==========

  /// 初始化控制器
  Future<void> initialize() async {
    if (_isInitialized) return;

    await conversationService.initialize();

    // 加载全局配置
    await _loadGlobalConfig();

    _isInitialized = true;
    notifyListeners();
  }

  /// 加载全局配置
  Future<void> _loadGlobalConfig() async {
    try {
      final res = await AboutmeDataService.instance.get(
        'agent_chat',
        'getConfig',
      );
      final config = res['success'] == true ? res['data'] : null;
      if (config is Map<String, dynamic>) {
        _defaultContextMessageCount =
            config['defaultContextMessageCount'] as int? ?? 10;
      }
    } catch (e) {
      debugPrint('加载全局配置失败: $e');
      // 使用默认值
      _defaultContextMessageCount = 10;
    }
  }

  /// 保存全局配置
  Future<void> _saveGlobalConfig() async {
    try {
      await AboutmeDataService.instance.call('agent_chat', 'updateConfig', {
        'defaultContextMessageCount': _defaultContextMessageCount,
      });
    } catch (e) {
      debugPrint('保存全局配置失败: $e');
    }
  }

  /// 服务变化回调
  void _onServiceChanged() {
    notifyListeners();
  }

  // ========== 会话操作 ==========

  /// 创建新会话
  Future<Conversation> createConversation({
    required String title,
    String? agentId,
    List<String>? groups,
    int? contextMessageCount,
    Map<String, dynamic>? metadata,
  }) async {
    final conversation = await conversationService.createConversation(
      title: title,
      agentId: agentId,
      groups: groups,
      contextMessageCount: contextMessageCount,
      metadata: metadata,
    );

    // 触发会话创建事件
    _notifyConversationEvent('added', conversation);

    return conversation;
  }

  /// 选择会话
  Future<void> selectConversation(String conversationId) async {
    _currentConversationId = conversationId;
    await messageService.setCurrentConversation(conversationId);

    // 清除未读计数
    await conversationService.clearUnreadCount(conversationId);

    notifyListeners();
  }

  /// 更新会话
  Future<void> updateConversation(Conversation conversation) async {
    await conversationService.updateConversation(conversation);
    // 触发会话更新事件
    _notifyConversationEvent('updated', conversation);
  }

  /// 删除会话
  Future<void> deleteConversation(String conversationId) async {
    // 获取会话信息用于事件
    final conversation = conversationService.getConversation(conversationId);

    if (_currentConversationId == conversationId) {
      _currentConversationId = null;
    }
    await conversationService.deleteConversation(conversationId);

    // 触发会话删除事件
    if (conversation != null) {
      _notifyConversationEvent('deleted', conversation);
    }
  }

  /// 切换置顶状态
  Future<void> togglePin(String conversationId) async {
    await conversationService.togglePin(conversationId);
  }

  // ========== 筛选和搜索 ==========

  /// 设置搜索关键词
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// 切换分组过滤器
  void toggleGroupFilter(String groupName) {
    if (_selectedGroupFilters.contains(groupName)) {
      _selectedGroupFilters.remove(groupName);
    } else {
      _selectedGroupFilters.add(groupName);
    }
    notifyListeners();
  }

  /// 清除分组过滤器
  void clearGroupFilters() {
    _selectedGroupFilters.clear();
    notifyListeners();
  }

  /// 设置Agent过滤器
  void setAgentFilter(String? agentId) {
    _selectedAgentFilter = agentId;
    notifyListeners();
  }

  /// 获取过滤后的会话列表
  List<Conversation> _getFilteredConversations() {
    // 临时/隐藏会话（hideInList，如聊天助手、Live2D 的路由会话）不进列表
    var filtered = conversationService.getNonTemporaryConversations();

    // 应用搜索
    if (_searchQuery.isNotEmpty) {
      final visibleIds = filtered.map((c) => c.id).toSet();
      filtered = conversationService
          .searchConversations(_searchQuery)
          .where((c) => visibleIds.contains(c.id))
          .toList();
    }

    // 应用分组过滤
    if (_selectedGroupFilters.isNotEmpty) {
      filtered = filtered.where((conv) {
        return conv.groups
            .any((group) => _selectedGroupFilters.contains(group));
      }).toList();
    }

    // 应用Agent过滤：null/空 = 全部不过滤；
    // [localPluginFilter] = 本插件手动创建会话（agentId == null）；
    // 其他 = 指定 Agent 的会话
    final agentFilter = _selectedAgentFilter;
    if (agentFilter != null && agentFilter.isNotEmpty) {
      if (agentFilter == localPluginFilter) {
        filtered = filtered.where((conv) => conv.agentId == null).toList();
      } else {
        filtered =
            filtered.where((conv) => conv.agentId == agentFilter).toList();
      }
    }

    return filtered;
  }

  // ========== 全局设置 ==========

  /// 设置默认上下文消息数量
  Future<void> setDefaultContextMessageCount(int count) async {
    _defaultContextMessageCount = count;
    await _saveGlobalConfig();
    notifyListeners();
  }

  /// 获取会话的上下文消息数量
  int getContextMessageCount(String conversationId) {
    final conversation = conversationService.getConversation(conversationId);
    return conversation?.contextMessageCount ?? _defaultContextMessageCount;
  }

  // ========== 刷新 ==========

  /// 刷新数据
  Future<void> refresh() async {
    await Future.wait([
      conversationService.refresh(),
      if (_currentConversationId != null) messageService.refresh(),
    ]);
  }

  /// 触发会话事件
  void _notifyConversationEvent(String action, Conversation conversation) {
    final eventArgs = ItemEventArgs(
      eventName: 'agent_chat_conversation_$action',
      itemId: conversation.id,
      title: conversation.title,
      action: action,
    );
    EventManager.instance.broadcast('agent_chat_conversation_$action', eventArgs);
  }

  @override
  void dispose() {
    _cancelDataSync?.call();
    conversationService.removeListener(_onServiceChanged);
    messageService.removeListener(_onServiceChanged);
    conversationService.dispose();
    messageService.dispose();
    super.dispose();
  }
}
