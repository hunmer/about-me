import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/models/service_provider.dart';
import 'package:aboutme/plugins/openai/controllers/provider_controller.dart';
import 'package:aboutme/plugins/openai/widgets/provider_logo.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
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

  /// 长按提供商卡片弹出的操作抽屉
  Future<void> _showProviderActions(ServiceProvider provider) {
    return SmoothBottomSheet.showWithTitle(
      context: context,
      title: provider.label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SmoothSheetAction(
            icon: DsIconKind.edit,
            label: 'openai_editProvider'.tr,
            onTap: () {
              Navigator.pop(context);
              _editProvider(provider);
            },
          ),
          SmoothSheetAction(
            icon: DsIconKind.copy,
            label: 'openai_cloneProvider'.tr,
            onTap: () {
              Navigator.pop(context);
              _cloneProvider(provider);
            },
          ),
          SmoothSheetAction(
            icon: DsIconKind.trash,
            label: 'app_delete'.tr,
            destructive: true,
            onTap: () {
              Navigator.pop(context);
              _deleteProvider(provider);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _cloneProvider(ServiceProvider provider) async {
    try {
      final clonedProvider = provider.copyWith(
        id: '${provider.id}_clone_${DateTime.now().millisecondsSinceEpoch}',
        label: '${provider.label}${'openai_cloneSuffix'.tr}',
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
    return SuperCupertinoNavigationWrapper(
      title: Text('openai_providerSettingsTitle'.tr),
      enableLargeTitle: false,
      actions: [_buildAddButton()],
      body:
          _isLoading
              ? const Center(child: DSLoadingDots())
              : _providers.isEmpty
              ? _buildEmptyState()
              : _buildProviderList(),
    );
  }

  Widget _buildAddButton() {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return DSIconButton(
          icon: DsIconKind.plus,
          size: 36,
          color: theme.surfaceAlt,
          iconColor: theme.textSub,
          onPressed: _addProvider,
          tooltip: 'openai_addProviderTooltip'.tr,
        );
      },
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
        // 手绘便签列表:倾斜姿态由 provider.id 确定性生成
        return HandDrawnListView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          tiltKeyOf: (index) => _providers[index].id,
          itemCount: _providers.length,
          itemBuilder: (context, index) {
            final provider = _providers[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // 长按弹出操作抽屉（编辑/克隆/删除）
              child: GestureDetector(
                onLongPress: () => _showProviderActions(provider),
                child: DSCard(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.spacing.md,
                    vertical: theme.spacing.sm,
                  ),
                  onTap: () => _editProvider(provider),
                  child: Row(
                    children: [
                      if (ProviderLogo.hasLogo(provider.id)) ...[
                        ProviderLogo(id: provider.id, size: 22),
                        SizedBox(width: theme.spacing.sm),
                      ],
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
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
