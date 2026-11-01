import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import '../models/ai_agent.dart';
import '../openai_plugin.dart';
import '../services/ai_auto_reply_service.dart';

/// AI 自动回复独立设置页：总开关、逐事件开关、Agent 与提示模板。
/// 迁自 ai_encouragement_bot 在线脚本，事件目录以服务核实的真实事件为准。
class AiAutoReplySettingsScreen extends StatefulWidget {
  const AiAutoReplySettingsScreen({super.key});

  @override
  State<AiAutoReplySettingsScreen> createState() =>
      _AiAutoReplySettingsScreenState();
}

class _AiAutoReplySettingsScreenState extends State<AiAutoReplySettingsScreen> {
  /// 总开关
  bool _enabled = false;

  /// 自动回复使用的 Agent
  String? _agentId;

  /// 提示模板输入控制器
  late final TextEditingController _templateController;

  /// 已启用的事件名集合（保存时序列化为列表；显式空列表 = 全关）
  Set<String> _enabledEvents = {};

  /// 可选 Agent 列表
  List<AIAgent> _agents = [];

  @override
  void initState() {
    super.initState();
    final settings = OpenAIPlugin.instance.settings;
    _enabled = settings[AiAutoReplyService.kSettingEnabled] == true;
    _agentId = settings[AiAutoReplyService.kSettingAgentId] as String?;
    final template = settings[AiAutoReplyService.kSettingTemplate] as String?;
    _templateController = TextEditingController(
      text: template != null && template.trim().isNotEmpty
          ? template
          : AiAutoReplyService.defaultPromptTemplate,
    );
    _enabledEvents = AiAutoReplyService.readConfiguredEvents(settings).toSet();
    _loadAgents();
  }

  @override
  void dispose() {
    _templateController.dispose();
    super.dispose();
  }

  Future<void> _loadAgents() async {
    try {
      final agents = await OpenAIPlugin.instance.controller.loadVisibleAgents();
      if (mounted) setState(() => _agents = agents);
    } catch (e) {
      debugPrint('[AiAutoReply] 加载Agent列表失败: $e');
    }
  }

  /// 保存队列：串行执行「持久化→热重载」，避免快速连续切换写入乱序
  Future<void> _saveQueue = Future.value();

  /// 保存变更并热重载订阅；失败时提示并回滚 UI 状态（revert）
  void _save(Map<String, dynamic> changes, {VoidCallback? revert}) {
    _saveQueue = _saveQueue.then((_) async {
      try {
        await OpenAIPlugin.instance.updateSettings(changes);
        AiAutoReplyService.instance.reload();
      } catch (e) {
        debugPrint('[AiAutoReply] 保存设置失败: $e');
        toastService.showToast('openai_aiAutoReplySaveFailed'.tr);
        if (revert != null && mounted) setState(revert);
      }
    });
  }

  void _onToggle(bool value) {
    final prev = _enabled;
    setState(() => _enabled = value);
    _save({
      AiAutoReplyService.kSettingEnabled: value,
    }, revert: () => _enabled = prev);
  }

  void _onAgentChanged(String? agentId) {
    final prev = _agentId;
    setState(() => _agentId = agentId);
    _save({
      AiAutoReplyService.kSettingAgentId: agentId,
    }, revert: () => _agentId = prev);
  }

  /// 逐事件开关：始终保存完整列表（全关时保存显式空列表）
  void _onEventToggle(String eventName, bool value) {
    final wasEnabled = _enabledEvents.contains(eventName);
    setState(() {
      if (value) {
        _enabledEvents.add(eventName);
      } else {
        _enabledEvents.remove(eventName);
      }
    });
    _save({
      AiAutoReplyService.kSettingEvents: _enabledEvents.toList(),
    }, revert: () => _onEventToggleRevert(eventName, wasEnabled));
  }

  /// 保存失败时恢复单个事件开关的旧状态
  void _onEventToggleRevert(String eventName, bool wasEnabled) {
    if (wasEnabled) {
      _enabledEvents.add(eventName);
    } else {
      _enabledEvents.remove(eventName);
    }
  }

  /// 弹窗编辑提示模板
  Future<void> _editTemplate() async {
    final controller = TextEditingController(text: _templateController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('openai_aiAutoReplyTemplate'.tr),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'openai_aiAutoReplyTemplateHint'.tr,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('openai_aiAutoReplyCancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text('openai_aiAutoReplySave'.tr),
          ),
        ],
      ),
    );
    // 退出动画期间 dialog 树仍引用该 controller，延后一帧释放
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (!mounted || result == null) return;
    final prev = _templateController.text;
    final text = result.trim().isEmpty
        ? AiAutoReplyService.defaultPromptTemplate
        : result.trim();
    setState(() => _templateController.text = text);
    _save({
      AiAutoReplyService.kSettingTemplate: text,
    }, revert: () => _templateController.text = prev);
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold 属结构性组件,刻意保留 Material;顶栏用 DSLightHeader,列表项用 DSListItem
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  DSLightHeader(title: 'openai_aiAutoReplyTitle'.tr),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.all(theme.spacing.lg),
                      children: [
                        // ==== 总开关 ====
                        DSListItem(
                          leading: DsIcon(
                            DsIconKind.bot,
                            size: 22,
                            color: theme.primary,
                          ),
                          title: 'openai_aiAutoReplyTitle'.tr,
                          subtitle: 'openai_aiAutoReplyDescription'.tr,
                          showChevron: false,
                          trailing: DSSwitch(
                            value: _enabled,
                            onChanged: _onToggle,
                          ),
                        ),
                        SizedBox(height: theme.spacing.sm),

                        if (_enabled) ...[
                          // ==== 自动回复 Agent ====
                          DSListItem(
                            leading: DsIcon(
                              DsIconKind.bot,
                              size: 22,
                              color: theme.primary,
                            ),
                            title: 'openai_aiAutoReplyAgent'.tr,
                            subtitle: 'openai_aiAutoReplyAgentDescription'.tr,
                            showChevron: false,
                            trailing: DSSelect<String?>(
                              width: 140,
                              value: _agentId,
                              hint: 'openai_aiAutoReplyNotSet'.tr,
                              items: [
                                DSSelectItem<String?>(
                                  label: 'openai_aiAutoReplyNotSet'.tr,
                                  value: null,
                                ),
                                ..._agents.map(
                                  (agent) => DSSelectItem<String?>(
                                    label: agent.name,
                                    value: agent.id,
                                  ),
                                ),
                              ],
                              onChanged: _onAgentChanged,
                            ),
                          ),
                          SizedBox(height: theme.spacing.sm),

                          // ==== 提示模板 ====
                          DSListItem(
                            leading: DsIcon(
                              DsIconKind.book,
                              size: 22,
                              color: theme.primary,
                            ),
                            title: 'openai_aiAutoReplyTemplate'.tr,
                            subtitle: 'openai_aiAutoReplyTemplateHint'.tr,
                            showChevron: true,
                            trailing: SizedBox(
                              width: 120,
                              child: Text(
                                _templateController.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: DsTypography.caption.copyWith(
                                  color: theme.textSub,
                                ),
                              ),
                            ),
                            onTap: _editTemplate,
                          ),
                        ],
                        SizedBox(height: theme.spacing.sm),

                        // ==== 逐事件开关（总关时仍展示已保留值，便于先配置再启用）====
                        DSListItem(
                          leading: DsIcon(
                            DsIconKind.layers,
                            size: 22,
                            color: theme.primary,
                          ),
                          title: 'openai_aiAutoReplyEventsTitle'.tr,
                          subtitle: 'openai_aiAutoReplyEventsDescription'.tr,
                          showChevron: false,
                        ),
                        SizedBox(height: theme.spacing.xs),

                        // 按目录顺序逐项开关（目录即服务核实的真实事件）
                        for (final info in AiAutoReplyService.availableEvents)
                          Padding(
                            padding: EdgeInsets.only(bottom: theme.spacing.xs),
                            child: DSListItem(
                              leading: DsIcon(
                                DsIconKind.reply,
                                size: 22,
                                color: theme.primary,
                              ),
                              title: info.description,
                              subtitle: info.eventName,
                              showChevron: false,
                              trailing: DSSwitch(
                                value: _enabledEvents.contains(info.eventName),
                                // 总开关关闭时保留值但禁用交互
                                onChanged: _enabled
                                    ? (v) => _onEventToggle(info.eventName, v)
                                    : null,
                              ),
                            ),
                          ),
                      ],
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
}
