import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:universal_platform/universal_platform.dart';

/// Agent Chat 插件设置界面
class AgentChatSettingsScreen extends StatefulWidget {
  final PluginBase plugin;

  const AgentChatSettingsScreen({super.key, required this.plugin});

  @override
  State<AgentChatSettingsScreen> createState() =>
      _AgentChatSettingsScreenState();
}

class _AgentChatSettingsScreenState extends State<AgentChatSettingsScreen> {
  bool _isLoading = false;
  bool _preferToolTemplates = false; // 优先使用工具模版开关

  // 后台服务设置
  bool _enableBackgroundService = true; // 启用后台服务（仅Android）
  bool _showTokenInNotification = true; // 在通知中显示token消耗

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = widget.plugin.settings;

      // 加载工具模版设置
      _preferToolTemplates = settings['preferToolTemplates'] as bool? ?? false;

      // 加载后台服务设置
      _enableBackgroundService =
          settings['enableBackgroundService'] as bool? ?? true;
      _showTokenInNotification =
          settings['showTokenInNotification'] as bool? ?? true;
    } catch (e) {
      _showError('加载设置失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 保存开关设置
  Future<void> _saveSwitchSettings() async {
    try {
      await widget.plugin.updateSettings({
        'preferToolTemplates': _preferToolTemplates,
        'enableBackgroundService': _enableBackgroundService,
        'showTokenInNotification': _showTokenInNotification,
      });

      debugPrint('🔧 [设置页面] 开关设置已自动保存');
    } catch (e) {
      debugPrint('❌ [设置页面] 自动保存失败: $e');
      _showError('自动保存失败: $e');
    }
  }

  /// 显示错误
  void _showError(String message) {
    if (!mounted) return;

    toastService.showToast(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('agent_chat_agentChatSettings'.tr)),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 工具调用设置标题
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        '工具调用设置',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // 优先使用工具模版开关
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Card(
                        child: SwitchListTile(
                          title: Text('agent_chat_prioritizeToolTemplate'.tr),
                          subtitle: Text(
                            'agent_chat_prioritizeToolTemplateDescription'.tr,
                          ),
                          value: _preferToolTemplates,
                          onChanged: (value) {
                            setState(() {
                              _preferToolTemplates = value;
                            });
                            _saveSwitchSettings(); // 自动保存
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),

                    // 后台服务设置标题（仅Android）
                    if (!kIsWeb && UniversalPlatform.isAndroid) ...[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          '后台服务设置',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),

                      // 启用后台服务开关
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Card(
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: Text(
                                  'agent_chat_enableBackgroundService'.tr,
                                ),
                                subtitle: Text(
                                  'agent_chat_enableBackgroundServiceDescription'
                                      .tr,
                                ),
                                value: _enableBackgroundService,
                                onChanged: (value) {
                                  setState(() {
                                    _enableBackgroundService = value;
                                  });
                                  _saveSwitchSettings(); // 自动保存
                                },
                              ),

                              if (_enableBackgroundService) ...[
                                const Divider(height: 1),

                                // Token消耗显示开关
                                SwitchListTile(
                                  title: Text(
                                    'agent_chat_showTokenConsumption'.tr,
                                  ),
                                  subtitle: Text(
                                    'agent_chat_showTokenConsumptionDescription'
                                        .tr,
                                  ),
                                  value: _showTokenInNotification,
                                  onChanged: (value) {
                                    setState(() {
                                      _showTokenInNotification = value;
                                    });
                                    _saveSwitchSettings(); // 自动保存
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
    );
  }
}
