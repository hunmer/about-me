import 'package:aboutme/core/services/ds_theme_color_controller.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'live2d_online_models.dart';

class Live2DOnlineModelPage extends StatefulWidget {
  const Live2DOnlineModelPage({super.key});

  @override
  State<Live2DOnlineModelPage> createState() => _Live2DOnlineModelPageState();
}

class _Live2DOnlineModelPageState extends State<Live2DOnlineModelPage> {
  List<Live2DOnlineModelItem> _models = const [];
  String _query = '';
  String? _category;
  String? _error;
  String? _loadingUrl;
  bool _loadingCatalog = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _error = null;
    });
    try {
      final models = await Live2DOnlineCatalog.fetchModels();
      if (!mounted) return;
      setState(() => _models = models);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error =
            'screens_jellyLive2dOnlineLoadRepoFailed'.trParams({'error': '$error'}),
      );
    } finally {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  Future<void> _selectModel(Live2DOnlineModelItem item) async {
    if (_loadingUrl != null) return;
    setState(() {
      _loadingUrl = item.url;
      _error = null;
    });
    try {
      final definition = await Live2DOnlineCatalog.loadDefinition(item);
      if (!mounted) return;
      Navigator.of(context).pop(definition);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error =
            'screens_jellyLive2dOnlineLoadConfigFailed'.trParams({'error': '$error'}),
      );
    } finally {
      if (mounted) setState(() => _loadingUrl = null);
    }
  }

  List<String> get _categories {
    final result = _models.map((model) => model.category).toSet().toList();
    result.sort();
    return result;
  }

  List<Live2DOnlineModelItem> get _filteredModels {
    final query = _query.trim().toLowerCase();
    return _models.where((model) {
      if (_category != null && model.category != _category) return false;
      if (query.isEmpty) return true;
      return model.name.toLowerCase().contains(query) ||
          model.category.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.fromPalette(DsThemeColorController().palette);
    return AppTheme(
      data: theme,
      child: ColoredBox(
        color: theme.background,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.lg),
            child: Column(
              children: [
                JellyBox(
                  radius: theme.radii.pill,
                  padding: EdgeInsets.all(theme.spacing.sm),
                  child: Row(
                    children: [
                      DSIconButton(
                        icon: DsIconKind.chevronLeft,
                        tooltip: 'core_back'.tr,
                        size: 36,
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      Expanded(
                        child: Text(
                          'screens_jellyLive2dOnlineTitle'.tr,
                          textAlign: TextAlign.center,
                          style: DsTypography.heading.copyWith(
                            color: theme.text,
                          ),
                        ),
                      ),
                      DSIconButton(
                        icon: DsIconKind.refresh,
                        tooltip: 'screens_jellyLive2dOnlineRefresh'.tr,
                        size: 36,
                        onPressed: _loadingCatalog ? null : _loadCatalog,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: theme.spacing.lg),
                DSInput.search(
                  hint: 'screens_jellyLive2dOnlineSearchHint'.tr,
                  onChanged: (value) => setState(() => _query = value),
                ),
                if (_categories.isNotEmpty) ...[
                  SizedBox(height: theme.spacing.md),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        DSChip(
                          label: 'screens_jellyLive2dOnlineAll'.tr,
                          selected: _category == null,
                          onSelected: (_) => setState(() => _category = null),
                        ),
                        for (final category in _categories) ...[
                          SizedBox(width: theme.spacing.sm),
                          DSChip(
                            label: category,
                            selected: _category == category,
                            onSelected:
                                (_) => setState(() => _category = category),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                SizedBox(height: theme.spacing.md),
                if (_error != null) ...[
                  JellyBox(
                    width: double.infinity,
                    color: theme.danger.mixWhite(0.9),
                    padding: EdgeInsets.all(theme.spacing.md),
                    child: Text(
                      _error!,
                      style: DsTypography.caption.copyWith(color: theme.danger),
                    ),
                  ),
                  SizedBox(height: theme.spacing.md),
                ],
                Expanded(child: _buildContent(theme)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AppThemeData theme) {
    if (_loadingCatalog && _models.isEmpty) {
      return Center(
        child: DSLoadingDots(label: 'screens_jellyLive2dOnlineLoading'.tr),
      );
    }
    if (_error != null && _models.isEmpty) {
      return Center(
        child: DSEmptyState(
          emoji: '!',
          title: 'screens_jellyLive2dOnlineUnavailable'.tr,
          actionLabel: 'app_retry'.tr,
          onAction: _loadCatalog,
        ),
      );
    }

    final models = _filteredModels;
    if (models.isEmpty) {
      return Center(
        child: DSEmptyState(
          emoji: '?',
          title: 'screens_jellyLive2dOnlineEmpty'.tr,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'screens_jellyLive2dOnlineCount'.trParams({
            'count': models.length.toString(),
          }),
          style: DsTypography.caption.copyWith(color: theme.textSub),
        ),
        SizedBox(height: theme.spacing.sm),
        Expanded(
          child: ListView.separated(
            itemCount: models.length,
            separatorBuilder: (_, _) => SizedBox(height: theme.spacing.sm),
            itemBuilder: (context, index) {
              final model = models[index];
              final loading = _loadingUrl == model.url;
              return DSListItem(
                title: model.name,
                subtitle: model.category,
                leading: DsIcon(DsIconKind.bot, size: 20, color: theme.primary),
                trailing:
                    loading
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: DSLoadingDots(size: 4.5),
                        )
                        : DsIcon(
                          DsIconKind.chevronRight,
                          size: 18,
                          color: theme.textSub,
                        ),
                onTap: _loadingUrl == null ? () => _selectModel(model) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
