import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/models/service_provider.dart';
import 'package:aboutme/plugins/openai/controllers/provider_controller.dart';
import 'provider_edit_screen.dart';
import 'package:aboutme/core/services/toast_service.dart';

class ProviderSettingsScreen extends StatefulWidget {
  const ProviderSettingsScreen({super.key});

  @override
  State<ProviderSettingsScreen> createState() => _ProviderSettingsScreenState();
}

class _ProviderSettingsScreenState extends State<ProviderSettingsScreen> {
  final ProviderController _controller = ProviderController();
  List<ServiceProvider> _providers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final providers = await _controller.getProviders();
      final defaultProviders = _controller.getDefaultProviders();

      if (providers.isEmpty) {
        // 如果没有服务商，添加默认服务商
        await _controller.saveProviders(defaultProviders);
        _providers = defaultProviders;
      } else {
        // 合并逻辑：添加默认列表中存在但用户数据中缺失的服务商
        final existingIds = providers.map((p) => p.id).toSet();
        final missingProviders =
            defaultProviders
                .where(
                  (defaultProvider) =>
                      !existingIds.contains(defaultProvider.id),
                )
                .toList();

        if (missingProviders.isNotEmpty) {
          // 将缺失的默认服务商添加到列表末尾
          final mergedProviders = [...providers, ...missingProviders];
          await _controller.saveProviders(mergedProviders);
          _providers = mergedProviders;
        } else {
          _providers = providers;
        }
      }
    } catch (e) {
      _showErrorSnackBar('${'openai_loadProvidersError'.tr}: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    toastService.showToast(message);
  }

  Future<void> _addProvider() async {
    final result = await NavigationHelper.push<bool>(
      context,
      const ProviderEditScreen(),
    );

    if (result == true) {
      await _loadProviders();
    }
  }

  Future<void> _editProvider(ServiceProvider provider) async {
    final result = await NavigationHelper.push<bool>(
      context,
      ProviderEditScreen(provider: provider),
    );

    if (result == true) {
      await _loadProviders();
    }
  }

  Future<void> _deleteProvider(ServiceProvider provider) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder:
                  (dialogContext) => DSDialog(
                    title: 'openai_confirmDeleteProviderTitle'.tr,
                    message: 'openai_confirmDeleteProviderMessage'.tr
                        .replaceAll('{providerLabel}', provider.label),
                    confirmText: 'app_delete'.tr,
                    cancelText: 'app_cancel'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                    onConfirm: () => Navigator.of(dialogContext).pop(true),
                    onCancel: () => Navigator.of(dialogContext).pop(false),
                  ),
            ),
          ),
    );

    if (confirmed == true) {
      try {
        await _controller.deleteProvider(provider.id);
        await _loadProviders();
      } catch (e) {
        _showErrorSnackBar('${'openai_deleteFailed'.tr}: $e');
      }
    }
  }

  Future<void> _cloneProvider(ServiceProvider provider) async {
    try {
      final clonedProvider = provider.copyWith(
        id: '${provider.id}_clone_${DateTime.now().millisecondsSinceEpoch}',
        label: '${provider.label} (副本)',
      );
      await _controller.addProvider(clonedProvider);
      await _loadProviders();
      if (!mounted) return;
      toastService.showToast('openai_cloneProviderSuccess'.tr);
    } catch (e) {
      _showErrorSnackBar('${'openai_cloneProviderFailed'.tr}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold/AppBar 属结构性组件,刻意保留 Material
    return DSThemeBridge(
      child: Scaffold(
        appBar: AppBar(
          title: Text('openai_providerSettingsTitle'.tr),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addProvider,
              tooltip: 'openai_addProviderTooltip'.tr,
            ),
          ],
        ),
        body: Builder(
          builder:
              (context) =>
                  _isLoading
                      ? const Center(child: DSLoadingDots())
                      : _providers.isEmpty
                      ? _buildEmptyState()
                      : _buildProviderList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: DSEmptyState(
        emoji: '☁️',
        title: 'openai_noProvidersConfigured'.tr,
        message: 'openai_addProviderTooltip'.tr,
        actionLabel: 'openai_addProviderButton'.tr,
        onAction: _addProvider,
      ),
    );
  }

  Widget _buildProviderList() {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return ListView.builder(
          itemCount: _providers.length,
          itemBuilder: (context, index) {
            final provider = _providers[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DSCard(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.md,
                  vertical: theme.spacing.sm,
                ),
                onTap: () => _editProvider(provider),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            provider.label,
                            style: DsTypography.body.copyWith(
                              color: theme.text,
                            ),
                          ),
                          Text(
                            provider.baseUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DSIconButton(
                      icon: DsIconKind.copy,
                      size: 36,
                      color: theme.surfaceAlt,
                      iconColor: theme.textSub,
                      onPressed: () => _cloneProvider(provider),
                      tooltip: 'openai_cloneAgent'.tr,
                    ),
                    DSIconButton(
                      icon: DsIconKind.edit,
                      size: 36,
                      color: theme.surfaceAlt,
                      iconColor: theme.textSub,
                      onPressed: () => _editProvider(provider),
                      tooltip: 'openai_editAgent'.tr,
                    ),
                    DSIconButton(
                      icon: DsIconKind.trash,
                      size: 36,
                      color: theme.danger,
                      iconColor: theme.onDanger,
                      onPressed: () => _deleteProvider(provider),
                      tooltip: 'openai_deleteAgent'.tr,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
