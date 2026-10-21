import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:uuid/uuid.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/speech_recognition_config_service.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/services/speech/speech_recognition_config.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/screens/agent_edit_screen.dart';

/// 语音识别设置对话框（手绘风）
class SpeechRecognitionSettingsDialog extends StatefulWidget {
  const SpeechRecognitionSettingsDialog({super.key});

  /// 统一入口：手绘对话框（自带墨线描画入场）
  static Future<bool?> show(BuildContext context) {
    return showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => const SpeechRecognitionSettingsDialog(),
    );
  }

  @override
  State<SpeechRecognitionSettingsDialog> createState() =>
      _SpeechRecognitionSettingsDialogState();
}

class _SpeechRecognitionSettingsDialogState
    extends State<SpeechRecognitionSettingsDialog> {
  final _appIdController = TextEditingController();
  final _secretIdController = TextEditingController();
  final _secretKeyController = TextEditingController();

  bool _obscureSecretKey = true;
  bool _isLoading = false;
  bool _hasChanges = false;

  String? _appIdError;
  String? _secretIdError;
  String? _secretKeyError;

  // AI纠错Agent相关
  AIAgent? _correctionAgent;

  @override
  void initState() {
    super.initState();
    _loadSettings();

    // 监听文本变化
    _appIdController.addListener(_onTextChanged);
    _secretIdController.addListener(_onTextChanged);
    _secretKeyController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _appIdController.dispose();
    _secretIdController.dispose();
    _secretKeyController.dispose();
    super.dispose();
  }

  /// 文本改变回调
  void _onTextChanged() {
    if (!_hasChanges ||
        _appIdError != null ||
        _secretIdError != null ||
        _secretKeyError != null) {
      setState(() {
        _hasChanges = true;
        _appIdError = null;
        _secretIdError = null;
        _secretKeyError = null;
      });
    }
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final config = SpeechRecognitionConfigService.instance.config;

      if (config != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _appIdController.text = config.appId;
          _secretIdController.text = config.secretId;
          _secretKeyController.text = config.secretKey;
          // 回填文本会触发监听器置脏，这里复位避免保存按钮误启用
          if (mounted) {
            setState(() {
              _hasChanges = false;
            });
          }
        });
      }

      // 加载AI纠错Agent信息
      _correctionAgent =
          SpeechRecognitionConfigService.instance.correctionAgent;
    } catch (e) {
      _showError('settings_screen_speechLoadFailed'.trParams({
        'error': e.toString(),
      }));
    } finally {
      setState(() {
        _isLoading = false;
        _hasChanges = false;
      });
    }
  }

  /// 校验表单，失败时展示各输入框错误
  bool _validate() {
    final appIdError =
        _appIdController.text.trim().isEmpty
            ? 'settings_screen_speechAppIdRequired'.tr
            : null;
    final secretIdError =
        _secretIdController.text.trim().isEmpty
            ? 'settings_screen_speechSecretIdRequired'.tr
            : null;
    final secretKeyError =
        _secretKeyController.text.trim().isEmpty
            ? 'settings_screen_speechSecretKeyRequired'.tr
            : null;

    setState(() {
      _appIdError = appIdError;
      _secretIdError = secretIdError;
      _secretKeyError = secretKeyError;
    });

    return appIdError == null && secretIdError == null && secretKeyError == null;
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    if (!_validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final config = TencentASRConfig(
        appId: _appIdController.text.trim(),
        secretId: _secretIdController.text.trim(),
        secretKey: _secretKeyController.text.trim(),
        sampleRate: 16000,
        engineModelType: '16k_zh',
        needVad: false,
        filterDirty: 0,
        wordInfo: false,
      );

      await SpeechRecognitionConfigService.instance.saveConfig(config);

      setState(() {
        _hasChanges = false;
      });

      if (mounted) {
        toastService.showToast('settings_screen_speechSaved'.tr);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showError(
        'settings_screen_speechSaveFailed'.trParams({'error': e.toString()}),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 测试配置
  Future<void> _testConnection() async {
    if (!_validate()) {
      return;
    }

    try {
      final config = TencentASRConfig(
        appId: _appIdController.text.trim(),
        secretId: _secretIdController.text.trim(),
        secretKey: _secretKeyController.text.trim(),
      );

      if (!config.isValid()) {
        _showError('settings_screen_speechInvalidConfig'.tr);
        return;
      }

      if (mounted) {
        toastService.showToast('settings_screen_speechVerifyPassed'.tr);
      }
    } catch (e) {
      _showError(
        'settings_screen_speechVerifyFailed'.trParams({
          'error': e.toString(),
        }),
      );
    }
  }

  /// 显示错误
  void _showError(String message) {
    if (!mounted) return;
    toastService.showToast(message);
  }

  /// 配置AI纠错Agent
  Future<void> _configureCorrectionAgent() async {
    // 如果没有配置，创建默认的Agent（模板文案按当前语言生成快照）
    final agentToEdit =
        _correctionAgent ??
        AIAgent(
          id: const Uuid().v4(),
          name: 'settings_screen_speechDefaultAgentName'.tr,
          description: 'settings_screen_speechDefaultAgentDesc'.tr,
          tags: ['settings_screen_speechDefaultAgentTag'.tr],
          serviceProviderId: 'openai',
          baseUrl: '',
          headers: const {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          model: 'gpt-4o-mini',
          temperature: 0.3,
          maxLength: 2000,
          topP: 1.0,
          frequencyPenalty: 0.0,
          presencePenalty: 0.0,
          messages: [
            Prompt(
              type: 'system',
              content: 'settings_screen_speechDefaultAgentPrompt'.tr,
            ),
          ],
        );

    // 使用回调模式，不保存到 agent 插件
    final savedAgent = await NavigationHelper.push<AIAgent>(
      context,
      AgentEditScreen(
        agent: agentToEdit,
        onSave: (agent) async {
          // 保存到自定义配置文件
          await SpeechRecognitionConfigService.instance.saveCorrectionAgent(
            agent,
          );
          return agent; // 返回保存后的 agent
        },
      ),
    );

    // 如果用户保存了Agent，更新UI
    if (savedAgent != null && mounted) {
      setState(() {
        _correctionAgent = savedAgent;
      });
      toastService.showToast('settings_screen_speechAgentSaved'.tr);
    }
  }

  /// 清除AI纠错Agent
  Future<void> _clearCorrectionAgent() async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: AppTheme.of(context),
      builder:
          (dialogContext) => DSDialog(
            title: 'settings_screen_confirmClear'.tr,
            message: 'settings_screen_confirmClearAiCorrection'.tr,
            cancelText: 'app_cancel'.tr,
            confirmText: 'app_delete'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
    );

    if (confirmed == true) {
      try {
        await SpeechRecognitionConfigService.instance.saveCorrectionAgent(null);
        setState(() {
          _correctionAgent = null;
        });
        toastService.showToast('settings_screen_speechAgentCleared'.tr);
      } catch (e) {
        _showError(
          'settings_screen_speechClearFailed'.trParams({
            'error': e.toString(),
          }),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      // 大容器走手绘面板：纸底 + 淡排线 + 墨线框
      // （showDSDialog 外层已包 WiredDraw，这里消费描画进度做墨线入场）
      child: DsSketchPanel(
        theme: theme,
        radius: theme.radii.xxl,
        padding: EdgeInsets.all(theme.spacing.lg),
        progress: WiredDrawTransition.progressOf(context),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DsIcon(DsIconKind.mic, color: theme.primary),
                  SizedBox(width: theme.spacing.sm),
                  Flexible(
                    child: Text(
                      'settings_screen_speechRecognitionSettings'.tr,
                      textAlign: TextAlign.center,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.sm),

              // 说明文本
              Text(
                'settings_screen_speechDesc'.tr,
                textAlign: TextAlign.center,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
              SizedBox(height: theme.spacing.sm),

              // 获取凭证链接提示
              Text(
                'settings_screen_speechCredHint'.tr,
                textAlign: TextAlign.center,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
              SizedBox(height: theme.spacing.lg),

              // 表单
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: DSLoadingDots()),
                )
              else ...[
                // App ID 输入框
                DSInput(
                  controller: _appIdController,
                  label: 'App ID',
                  hint: 'settings_screen_speechAppIdHint'.tr,
                  errorText: _appIdError,
                ),
                SizedBox(height: theme.spacing.md),

                // Secret ID 输入框
                DSInput(
                  controller: _secretIdController,
                  label: 'Secret ID',
                  hint: 'settings_screen_speechSecretIdHint'.tr,
                  errorText: _secretIdError,
                ),
                SizedBox(height: theme.spacing.md),

                // Secret Key 输入框
                DSInput(
                  controller: _secretKeyController,
                  label: 'Secret Key',
                  hint: 'settings_screen_speechSecretKeyHint'.tr,
                  errorText: _secretKeyError,
                  obscureText: _obscureSecretKey,
                  suffix: DSIconButton(
                    icon: _obscureSecretKey ? DsIconKind.eyeOff : DsIconKind.eye,
                    size: 34,
                    color: theme.surfaceAlt,
                    iconColor: theme.textSub,
                    onPressed: () {
                      setState(() {
                        _obscureSecretKey = !_obscureSecretKey;
                      });
                    },
                  ),
                ),
              ],

              SizedBox(height: theme.spacing.lg),
              Container(
                height: 1,
                color: theme.textSub.withValues(alpha: 0.25),
              ),
              SizedBox(height: theme.spacing.lg),

              // AI智能纠错设置
              Row(
                children: [
                  DsIcon(DsIconKind.sparkle, color: theme.primary),
                  SizedBox(width: theme.spacing.sm),
                  Text(
                    'settings_screen_speechAiCorrectionTitle'.tr,
                    style: DsTypography.heading.copyWith(color: theme.text),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.md),
              _buildAgentSection(theme),

              SizedBox(height: theme.spacing.xl),

              // 操作按钮
              Wrap(
                alignment: WrapAlignment.end,
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                children: [
                  DSButton(
                    label: 'app_cancel'.tr,
                    variant: DSButtonVariant.ghost,
                    size: DSButtonSize.sm,
                    onPressed:
                        _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                  DSButton(
                    label: 'settings_screen_verifyConfiguration'.tr,
                    variant: DSButtonVariant.outline,
                    size: DSButtonSize.sm,
                    onPressed: _isLoading ? null : _testConnection,
                  ),
                  DSButton(
                    label: 'app_save'.tr,
                    icon: DsIconKind.check,
                    size: DSButtonSize.sm,
                    onPressed:
                        _isLoading || !_hasChanges ? null : _saveSettings,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// AI纠错Agent 配置卡片
  Widget _buildAgentSection(AppThemeData theme) {
    if (_correctionAgent != null) {
      final initial =
          _correctionAgent!.name.isNotEmpty ? _correctionAgent!.name[0] : 'A';

      return Container(
        padding: EdgeInsets.all(theme.spacing.md),
        decoration: dsSketchDecoration(
          theme: theme,
          radius: theme.radii.lg,
          fillColor: theme.surfaceAlt,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: dsSketchDecoration(
                    theme: theme,
                    radius: BorderRadius.circular(18),
                    fillColor: theme.primary,
                  ),
                  child: Text(
                    initial,
                    style: DsTypography.body.copyWith(
                      color: theme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _correctionAgent!.name,
                        style: DsTypography.body.copyWith(color: theme.text),
                      ),
                      Text(
                        'settings_screen_aiCorrectionConfigured'.tr,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
                DSIconButton(
                  icon: DsIconKind.trash,
                  size: 34,
                  color: theme.surface,
                  iconColor: theme.danger,
                  tooltip: 'app_delete'.tr,
                  onPressed: _clearCorrectionAgent,
                ),
              ],
            ),
            SizedBox(height: theme.spacing.md),
            DSButton(
              label: 'settings_screen_editAiCorrectionAgent'.tr,
              icon: DsIconKind.edit,
              size: DSButtonSize.sm,
              onPressed: _configureCorrectionAgent,
            ),
          ],
        ),
      );
    }

    // 未配置
    return Container(
      padding: EdgeInsets.all(theme.spacing.md),
      decoration: dsSketchDecoration(
        theme: theme,
        radius: theme.radii.lg,
        fillColor: theme.surfaceAlt,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'settings_screen_speechAiCorrectionDesc'.tr,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
          SizedBox(height: theme.spacing.md),
          DSButton(
            label: 'settings_screen_configureAiCorrectionAgent'.tr,
            icon: DsIconKind.plus,
            variant: DSButtonVariant.outline,
            size: DSButtonSize.sm,
            onPressed: _configureCorrectionAgent,
          ),
        ],
      ),
    );
  }
}
