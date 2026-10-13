import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../models/app_store_models.dart';
import '../../services/app_store_manager.dart';

/// 源管理界面
class SourceManagementScreen extends StatelessWidget {
  const SourceManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final appStoreManager = context.watch<AppStoreManager>();
          return Scaffold(
            backgroundColor: theme.background,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // 顶行：返回 / 标题 / 添加源（design.md §2.1 轻量手绘顶栏）
                  DSLightHeader(
                    title: 'webview_manage_sources'.tr,
                    trailing: DSIconButton(
                      icon: DsIconKind.plus,
                      size: 38,
                      color: theme.surface,
                      iconColor: theme.text,
                      onPressed: () => _showAddSourceDialog(context),
                    ),
                  ),
                  Expanded(
                    child: appStoreManager.sources.isEmpty
                        ? Center(
                            child: DSEmptyState(
                              emoji: '📦',
                              title: 'webview_no_sources'.tr,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: appStoreManager.sources.length,
                            itemBuilder: (context, index) {
                              final source = appStoreManager.sources[index];
                              // 供 DSPopover 回调使用的屏幕 context(其 contentBuilder
                              // 的 context 位于根 Overlay,读不到本屏的 Provider)
                              final screenContext = context;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: DSCard(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: theme.spacing.md,
                                    vertical: theme.spacing.sm,
                                  ),
                                  // 点击卡片直接应用该源（切换 currentSource 并拉取）
                                  onTap: () =>
                                      _applySource(screenContext, source),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              source.name,
                                              style: DsTypography.body.copyWith(
                                                color: theme.text,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              source.url,
                                              style: DsTypography.caption
                                                  .copyWith(color: theme.text),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${'webview_source_base_url'.tr}: ${source.baseUrl}',
                                              style: DsTypography.caption
                                                  .copyWith(
                                                    color: theme.textSub,
                                                    fontSize: 11,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (source.lastFetchedAt != null)
                                              Text(
                                                'webview_source_last_fetched'
                                                    .trParams({
                                                      'date': _formatDate(
                                                        source.lastFetchedAt!,
                                                      ),
                                                      'count':
                                                          '${source.appCount ?? 0}',
                                                    }),
                                                style: DsTypography.caption
                                                    .copyWith(
                                                      color: theme.textSub,
                                                      fontSize: 11,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (appStoreManager.currentSource?.id ==
                                          source.id) ...[
                                        DsIcon(
                                          DsIconKind.check,
                                          size: 18,
                                          color: theme.success,
                                        ),
                                        SizedBox(width: theme.spacing.xs),
                                      ],
                                      if (source.isDefault) ...[
                                        DSBadge(
                                          label: 'webview_default_badge'.tr,
                                        ),
                                        SizedBox(width: theme.spacing.sm),
                                      ],
                                      // DSPopover 经根 Overlay 展示,内容已自带主题
                                      DSPopover(
                                        width: 190,
                                        contentBuilder: (context, close) {
                                          final menuTheme =
                                              DSThemeBridge.resolve(context);
                                          return Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              _SourceMenuRow(
                                                icon: DsIcon(
                                                  DsIconKind.edit,
                                                  size: 20,
                                                  color: menuTheme.primary,
                                                ),
                                                label: 'webview_edit_source'.tr,
                                                theme: menuTheme,
                                                onTap: () {
                                                  close();
                                                  _showEditSourceDialog(
                                                    screenContext,
                                                    source,
                                                  );
                                                },
                                              ),
                                              if (!source.isDefault)
                                                _SourceMenuRow(
                                                  icon: DsIcon(
                                                    DsIconKind.star,
                                                    size: 20,
                                                    color: menuTheme.primary,
                                                  ),
                                                  label:
                                                      'webview_set_default'.tr,
                                                  theme: menuTheme,
                                                  onTap: () {
                                                    close();
                                                    _setAsDefault(
                                                      screenContext,
                                                      source,
                                                    );
                                                  },
                                                ),
                                              _SourceMenuRow(
                                                icon: DsIcon(
                                                  DsIconKind.trash,
                                                  size: 20,
                                                  color: menuTheme.danger,
                                                ),
                                                label: 'delete'.tr,
                                                theme: menuTheme,
                                                danger: true,
                                                onTap: () {
                                                  close();
                                                  _confirmDelete(
                                                    screenContext,
                                                    source,
                                                  );
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                        child: DSIconButton(
                                          icon: DsIconKind.more,
                                          size: 36,
                                          color: theme.surfaceAlt,
                                          iconColor: theme.textSub,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
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

  /// 应用源：切换 currentSource 并拉取应用列表
  Future<void> _applySource(BuildContext context, AppStoreSource source) async {
    final manager = context.read<AppStoreManager>();
    if (manager.currentSource?.id == source.id) return;

    Toast.success('webview_source_switched'.trParams({'name': source.name}));
    await manager.switchSource(source.id);
  }

  void _showAddSourceDialog(BuildContext context) {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final baseUrlController = TextEditingController();
    final appStoreManager = context.read<AppStoreManager>();

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return JellyBox(
              radius: theme.radii.xxl,
              padding: EdgeInsets.all(theme.spacing.xl),
              constraints: const BoxConstraints(maxWidth: 380),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'webview_add_source'.tr,
                      textAlign: TextAlign.center,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                    SizedBox(height: theme.spacing.lg),
                    DSInput(
                      controller: nameController,
                      label: 'webview_source_name'.tr,
                      hint: 'My App Store',
                    ),
                    SizedBox(height: theme.spacing.md),
                    DSInput(
                      controller: urlController,
                      label: 'webview_source_url'.tr,
                      hint: 'https://example.com/apps.json',
                      keyboardType: TextInputType.url,
                    ),
                    SizedBox(height: theme.spacing.md),
                    DSInput(
                      controller: baseUrlController,
                      label: 'webview_source_base_url'.tr,
                      hint: 'https://example.com',
                      keyboardType: TextInputType.url,
                    ),
                    SizedBox(height: theme.spacing.sm),
                    Text(
                      'webview_source_base_url_hint'.tr,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                    SizedBox(height: theme.spacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: DSButton(
                            label: 'cancel'.tr,
                            variant: DSButtonVariant.outline,
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ),
                        SizedBox(width: theme.spacing.md),
                        Expanded(
                          child: DSButton(
                            label: 'add'.tr,
                            onPressed: () {
                              if (nameController.text.isNotEmpty &&
                                  urlController.text.isNotEmpty &&
                                  baseUrlController.text.isNotEmpty) {
                                final source = AppStoreSource(
                                  id: const Uuid().v4(),
                                  name: nameController.text,
                                  url: urlController.text,
                                  baseUrl: baseUrlController.text,
                                  createdAt: DateTime.now(),
                                );
                                appStoreManager.addSource(source);
                                Navigator.of(dialogContext).pop();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showEditSourceDialog(BuildContext context, AppStoreSource source) {
    final nameController = TextEditingController(text: source.name);
    final urlController = TextEditingController(text: source.url);
    final baseUrlController = TextEditingController(text: source.baseUrl);
    final appStoreManager = context.read<AppStoreManager>();

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return JellyBox(
              radius: theme.radii.xxl,
              padding: EdgeInsets.all(theme.spacing.xl),
              constraints: const BoxConstraints(maxWidth: 380),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'webview_edit_source'.tr,
                      textAlign: TextAlign.center,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                    SizedBox(height: theme.spacing.lg),
                    DSInput(
                      controller: nameController,
                      label: 'webview_source_name'.tr,
                    ),
                    SizedBox(height: theme.spacing.md),
                    DSInput(
                      controller: urlController,
                      label: 'webview_source_url'.tr,
                      keyboardType: TextInputType.url,
                    ),
                    SizedBox(height: theme.spacing.md),
                    DSInput(
                      controller: baseUrlController,
                      label: 'webview_source_base_url'.tr,
                      keyboardType: TextInputType.url,
                    ),
                    SizedBox(height: theme.spacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: DSButton(
                            label: 'cancel'.tr,
                            variant: DSButtonVariant.outline,
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ),
                        SizedBox(width: theme.spacing.md),
                        Expanded(
                          child: DSButton(
                            label: 'save'.tr,
                            onPressed: () {
                              if (nameController.text.isNotEmpty &&
                                  urlController.text.isNotEmpty &&
                                  baseUrlController.text.isNotEmpty) {
                                final updated = source.copyWith(
                                  name: nameController.text,
                                  url: urlController.text,
                                  baseUrl: baseUrlController.text,
                                );
                                appStoreManager.updateSource(updated);
                                Navigator.of(dialogContext).pop();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppStoreSource source) async {
    final appStoreManager = context.read<AppStoreManager>();
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (dialogContext) => DSDialog(
            title: 'confirm'.tr,
            message: 'webview_delete_source_confirm'.trParams({
              'name': source.name,
            }),
            confirmText: 'delete'.tr,
            cancelText: 'cancel'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () => Navigator.of(dialogContext).pop(true),
            onCancel: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      appStoreManager.deleteSource(source.id);
    }
  }

  void _setAsDefault(BuildContext context, AppStoreSource source) {
    final manager = context.read<AppStoreManager>();

    // 将所有源的 isDefault 设为 false
    for (var s in manager.sources) {
      if (s.id != source.id && s.isDefault) {
        manager.updateSource(s.copyWith(isDefault: false));
      }
    }

    // 将当前源设为默认
    manager.updateSource(source.copyWith(isDefault: true));
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// 源菜单行(果冻风格)
class _SourceMenuRow extends StatelessWidget {
  const _SourceMenuRow({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.danger = false,
  });

  final Widget icon;
  final String label;
  final AppThemeData theme;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? theme.danger : theme.primary;
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: Pressable(
        onPressed: onTap,
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return JellyBox(
            radius: theme.radii.md,
            raised: false,
            color: pressed ? accent.mixWhite(0.9) : theme.surfaceAlt,
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.sm + 2,
            ),
            child: Row(
              children: [
                icon,
                SizedBox(width: theme.spacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: DsTypography.body.copyWith(
                      color: danger ? theme.danger : theme.text,
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
}
