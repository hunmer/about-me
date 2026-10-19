import 'dart:async';

import 'package:aboutme/core/services/ds_theme_color_controller.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:live2d_flutter/live2d_flutter.dart';

import 'live2d_online_models.dart';

class Live2DOnlinePreviewPage extends StatefulWidget {
  const Live2DOnlinePreviewPage({super.key, required this.item});

  final Live2DOnlineModelItem item;

  @override
  State<Live2DOnlinePreviewPage> createState() =>
      _Live2DOnlinePreviewPageState();
}

class _Live2DOnlinePreviewPageState extends State<Live2DOnlinePreviewPage> {
  final _controller = Live2DViewController();
  Live2DModelDefinition? _definition;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final definition = await Live2DOnlineCatalog.loadDefinition(widget.item);
      if (!mounted) return;
      final local = await Live2DOnlineCatalog.cacheDefinition(definition);
      if (!mounted) return;
      await _controller.whenAttached;
      if (!mounted) return;
      final loaded = await _controller.loadModel(
        modelDir: local.modelDir,
        modelFileName: local.modelFile,
      );
      if (!loaded) {
        throw _controller.value.lastError ?? StateError('Live2D load failed');
      }
      if (mounted) setState(() => _definition = definition);
    } catch (error, stackTrace) {
      debugPrint('[Live2DOnlinePreview] $error\n$stackTrace');
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.fromPalette(DsThemeColorController().palette);
    return AppTheme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.background,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 88),
                child: Live2DView(controller: _controller),
              ),
              if (_loading)
                Center(
                  child: DSLoadingDots(
                    label: 'screens_jellyLive2dOnlineLoading'.tr,
                  ),
                ),
              if (_error != null)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(theme.spacing.lg),
                    child: DSEmptyState(
                      emoji: '!',
                      title: 'screens_jellyLive2dOnlineLoadConfigFailed'
                          .trParams({'error': '$_error'}),
                      actionLabel: 'app_retry'.tr,
                      onAction: _load,
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: Center(
                  child: DSButton(
                    label: 'core_close'.tr,
                    icon: DsIconKind.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              if (_definition != null)
                Positioned(
                  top: theme.spacing.lg,
                  right: theme.spacing.lg,
                  child: DSButton(
                    label: 'app_select'.tr,
                    onPressed: () => Navigator.of(context).pop(_definition),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
