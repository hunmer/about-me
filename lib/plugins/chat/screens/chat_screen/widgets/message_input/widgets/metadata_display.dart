import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'dart:io' show Process;
import 'package:universal_platform/universal_platform.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

class MetadataDisplay extends StatelessWidget {
  final Map<String, dynamic>? selectedFile;
  final List<Map<String, String>> selectedAgents;
  final Function() onShowAgentListDrawer;
  final Function() onFileRemove;
  final Function(String) onAgentRemove;
  final int contextRange;
  final Function(int) onContextRangeChange;

  static const int minRange = 0;
  static const int maxRange = 50;
  static const int defaultRange = 10;

  const MetadataDisplay({
    super.key,
    this.selectedFile,
    required this.selectedAgents,
    required this.onShowAgentListDrawer,
    required this.onFileRemove,
    required this.onAgentRemove,
    this.contextRange = defaultRange,
    required this.onContextRangeChange,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedFile == null && selectedAgents.isEmpty) {
      // 没有文件和智能体时不显示任何内容
      return const SizedBox();
    }

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // 文件状态展示
                if (selectedFile != null)
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: EdgeInsets.zero,
                      child: GestureDetector(
                        onTap: () async {
                          // 预览文件
                          if (selectedFile != null) {
                            final fileInfo =
                                selectedFile!['fileInfo']
                                    as Map<String, dynamic>?;
                            if (fileInfo != null && fileInfo['path'] != null) {
                              final filePath = fileInfo['path'] as String;
                              if (UniversalPlatform.isWindows) {
                                Process.run('explorer', [filePath]);
                              } else if (UniversalPlatform.isMacOS) {
                                Process.run('open', [filePath]);
                              } else if (UniversalPlatform.isLinux) {
                                Process.run('xdg-open', [filePath]);
                              }
                            }
                          }
                        },
                        child: DSChip(
                          icon:
                              (selectedFile!['fileInfo']?['type'] as String?) ==
                                      'image'
                                  ? DsIconKind.image
                                  : DsIconKind.copy,
                          label: 'chat_singleFile'.tr,
                          onDeleted: onFileRemove,
                        ),
                      ),
                    ),
                  ),
                // 如果两者都存在，添加一个间隔
                if (selectedFile != null && selectedAgents.isNotEmpty)
                  const SizedBox(width: 8),

                // 只有在选择了智能体时才显示上下文范围
                if (selectedAgents.isNotEmpty) ...[
                  _buildContextRangeChip(context, theme),
                  const SizedBox(width: 8),
                ],

                // 智能体状态展示
                if (selectedAgents.isNotEmpty)
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: onShowAgentListDrawer,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            selectedAgents.map((agent) {
                              return DSChip(
                                icon: DsIconKind.bot,
                                label: agent['name'] ?? '',
                                onDeleted:
                                    () => onAgentRemove(agent['id'] ?? ''),
                              );
                            }).toList(),
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

  Widget _buildContextRangeChip(BuildContext context, AppThemeData theme) {
    return Container(
      padding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: () => _showContextRangeDialog(context),
        child: DSChip(
          icon: DsIconKind.clock,
          label: '${'chat_contextRange'.tr}: $contextRange',
        ),
      ),
    );
  }

  Future<void> _showContextRangeDialog(BuildContext context) async {
    double currentValue = contextRange.toDouble();

    await showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => DSThemeBridge(
                  child: Builder(
                    builder: (context) {
                      final theme = DSThemeBridge.resolve(context);
                      return JellyBox(
                        radius: theme.radii.xxl,
                        padding: EdgeInsets.all(theme.spacing.xl),
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'chat_setContextRange'.tr,
                              textAlign: TextAlign.center,
                              style: DsTypography.title.copyWith(
                                color: theme.text,
                              ),
                            ),
                            SizedBox(height: theme.spacing.lg),
                            Text(
                              '${'chat_currentRange'.tr}: ${currentValue.round()}',
                              textAlign: TextAlign.center,
                              style: DsTypography.body.copyWith(
                                color: theme.text,
                              ),
                            ),
                            DSSlider(
                              value:
                                  (currentValue - minRange) /
                                  (maxRange - minRange),
                              onChanged: (value) {
                                setState(() {
                                  currentValue =
                                      minRange + value * (maxRange - minRange);
                                });
                              },
                            ),
                            Text(
                              'chat_rangeHint'.tr,
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                            SizedBox(height: theme.spacing.lg),
                            Row(
                              children: [
                                Expanded(
                                  child: DSButton(
                                    label: 'app_cancel'.tr,
                                    variant: DSButtonVariant.outline,
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                  ),
                                ),
                                SizedBox(width: theme.spacing.md),
                                Expanded(
                                  child: DSButton(
                                    label: 'app_ok'.tr,
                                    onPressed: () {
                                      onContextRangeChange(
                                        currentValue.round(),
                                      );
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
          ),
    );
  }
}
