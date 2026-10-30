import 'package:flutter/material.dart';

import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
import 'package:aboutme/plugins/openai/aliveness/services/keepalive_service.dart';

import 'package:get/get.dart';
/// 活人感决策层（Jev）与运行配置对话框。
/// 入口：插件设置页 + agent 编辑页活人感分组（两处复用）。
Future<void> showJevSettingsDialog(BuildContext context) async {
  final store = AlivenessStore.instance;
  final settings = await store.loadSettings();

  final baseUrlCtrl = TextEditingController(
    text: settings['jevBaseUrl'] as String? ?? '',
  );
  final apiKeyCtrl = TextEditingController(
    text: settings['jevApiKey'] as String? ?? '',
  );
  final modelCtrl = TextEditingController(
    text: settings['jevModel'] as String? ?? 'jev-latest',
  );
  final proxyCtrl = TextEditingController(
    text: settings['jevProxy'] as String? ?? '',
  );
  final thresholdCtrl = TextEditingController(
    text: '${settings['confidenceThreshold'] ?? 0.65}',
  );
  var keepAlive = settings['keepAliveEnabled'] as bool? ?? false;

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text('openai_jevDecisionModel'.tr),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: baseUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://api.typesafe.ai/v1/systemone',
                ),
              ),
              TextField(
                controller: apiKeyCtrl,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: '未填写时使用内置 Key',
                ),
                obscureText: true,
              ),
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(
                  labelText: '模型',
                  hintText: 'jev-latest',
                ),
              ),
              TextField(
                controller: proxyCtrl,
                decoration: const InputDecoration(
                  labelText: 'HTTP 代理（可选，绕过地区限制）',
                  hintText: '127.0.0.1:7890 或 http://127.0.0.1:7890',
                  helperText: '留空直连；不支持 SOCKS 与带认证代理',
                ),
              ),
              TextField(
                controller: thresholdCtrl,
                decoration: const InputDecoration(
                  labelText: '置信度阈值（0~1，低于则走保守规则）',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('openai_foregroundKeepAlive'.tr),
                subtitle: Text('openai_foregroundKeepAliveDesc'.tr),
                value: keepAlive,
                onChanged: (v) => setDialogState(() => keepAlive = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('app_cancel'.tr),
          ),
          TextButton(
            onPressed: () async {
              final threshold =
                  double.tryParse(thresholdCtrl.text.trim()) ?? 0.65;
              await store.saveSettings({
                'jevBaseUrl': baseUrlCtrl.text.trim().isEmpty
                    ? 'https://api.typesafe.ai/v1/systemone'
                    : baseUrlCtrl.text.trim(),
                'jevApiKey': apiKeyCtrl.text.trim(),
                'jevModel': modelCtrl.text.trim().isEmpty
                    ? 'jev-latest'
                    : modelCtrl.text.trim(),
                'jevProxy': proxyCtrl.text.trim(),
                'confidenceThreshold': threshold.clamp(0.0, 1.0),
                'keepAliveEnabled': keepAlive,
                // 语音声线已改为 per-agent 配置（编辑页 TTS 选择器），保留旧值兼容
                'voiceServiceId': settings['voiceServiceId'],
              });
              // 立即同步前台保活状态
              if (keepAlive) {
                await AlivenessKeepAliveService.instance.start();
              } else {
                await AlivenessKeepAliveService.instance.stop();
              }
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: Text('app_save'.tr),
          ),
        ],
      ),
    ),
  );
}
