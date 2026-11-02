import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:live2d_flutter/live2d_flutter.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_models.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_live2d_models.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 区域编辑器内文案：跟随 Get.locale 在中英文间切换（与表单 _videoText 同风格）
String live2dRegionText(String zh, String en) =>
    (Get.locale?.languageCode ?? 'zh') == 'zh' ? zh : en;

/// 模型自带 HitArea（.model3.json 中 `HitAreas` 数组的项）。
///
/// 运行时原生侧回调的 hitAreaId/hitAreaName 即来源于此，
/// 编辑器用它列出可配置的模型部位。
class Live2DModelHitArea {
  const Live2DModelHitArea({required this.id, required this.name});

  final String id;
  final String name;

  /// 展示名：Name 优先；为空时退回去掉 `HitArea` 前缀的 Id
  /// （内置 Mao 模型的 Name 全为空、Id 形如 HitAreaHead）。
  String get rawDisplayName {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return id.startsWith('HitArea') ? id.substring(7) : id;
  }

  /// 中文界面下若 Id/Name 命中常见部位关键词，则显示「部位（原名）」
  String get displayName {
    if ((Get.locale?.languageCode ?? 'zh') != 'zh') return rawDisplayName;
    final lower = rawDisplayName.toLowerCase();
    for (final part in live2DTapParts) {
      if (part.id == 'miss') continue;
      for (final keyword in part.keywords) {
        if (lower.contains(keyword.toLowerCase())) {
          return '${part.label}（$rawDisplayName）';
        }
      }
    }
    return rawDisplayName;
  }
}

/// 读取模型 `.model3.json` 中声明的 HitAreas 列表。
///
/// [model] 必须是本地模型：内置 assets 模型走 [rootBundle]，
/// zip 导入 / 在线缓存模型走文件系统；在线（http）模型请先经
/// `Live2DOnlineCatalog.cacheDefinition` 落地后再调用。
Future<List<Live2DModelHitArea>> readModelHitAreas(
  Live2DModelDefinition model,
) async {
  if (model.modelDir.startsWith('http')) {
    throw StateError('在线模型需先缓存到本地再读取 HitAreas');
  }
  final path = '${model.modelDir}${model.modelFile}';
  final raw = model.modelDir.startsWith('assets/')
      ? await rootBundle.loadString(path)
      : await File(path).readAsString();
  final Object? data = jsonDecode(raw);
  if (data is! Map) return const [];
  final Object? areas = data['HitAreas'];
  if (areas is! List) return const [];
    final result = <Live2DModelHitArea>[];
    for (final Object? area in areas) {
      if (area is! Map) continue;
      final id = (area['Id'] ?? area['id'] ?? '').toString();
      if (id.isEmpty) continue;
      result.add(
        Live2DModelHitArea(id: id, name: (area['Name'] ?? '').toString()),
      );
    }
    return result;
}

/// 实时 Live2D 模型预览：内部持有 [Live2DViewController]，
/// 加载链与 jelly_live2d 运行时一致（在线模型先缓存再加载）。
///
/// [overlay] 叠加在模型之上且不参与命中（画区域矩形层），
/// [scrim] 位于模型与 [overlay] 之间的背景蒙层（如绘制模式的
/// 半透明黑色覆盖层，同样不参与命中），
/// [foreground] 叠加在其上并接收手势（绘制/选择手势层），
/// [topRight] 固定在预览右上角（模式切换按钮等，始终位于占位层之上）。
class Live2DModelPreview extends StatefulWidget {
  const Live2DModelPreview({
    super.key,
    required this.definition,
    this.aspectRatio = 0.5,
    this.overlay,
    this.scrim,
    this.foreground,
    this.topRight,
    this.onControllerReady,
    this.onModelLoaded,
  });

  /// 待加载的模型定义；null 或视频模型时显示占位
  final Live2DModelDefinition? definition;

  /// 模型完整视口纵横比，须与运行时一致（Live2D 默认 0.5），
  /// 归一化点击区域坐标即相对该视口。
  final double aspectRatio;
  final Widget? overlay;

  /// 模型与区域叠加层之间的背景蒙层（绘制模式的半透明黑色覆盖层），
  /// 不参与命中测试。
  final Widget? scrim;
  final Widget? foreground;

  /// 悬浮在预览右上角的内容（如交互模式按钮组），不被加载占位遮挡
  final Widget? topRight;
  final void Function(Live2DViewController controller)? onControllerReady;
  final void Function(Live2DModelDefinition localModel)? onModelLoaded;

  @override
  State<Live2DModelPreview> createState() => _Live2DModelPreviewState();
}

class _Live2DModelPreviewState extends State<Live2DModelPreview> {
  final Live2DViewController _controller = Live2DViewController();
  bool _loading = false;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.onControllerReady?.call(_controller);
    _load();
  }

  @override
  void didUpdateWidget(Live2DModelPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldDef = oldWidget.definition;
    final newDef = widget.definition;
    final changed = oldDef?.modelDir != newDef?.modelDir ||
        oldDef?.modelFile != newDef?.modelFile ||
        oldDef?.isOnline != newDef?.isOnline;
    if (changed) _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 与 jelly_live2d_loader 相同的加载顺序：
  /// 在线模型缓存 → whenAttached → 卸载旧模型 → loadModel
  Future<void> _load() async {
    final definition = widget.definition;
    if (definition == null ||
        definition.isVideo ||
        definition.modelDir.isEmpty) {
      setState(() {
        _error = StateError(live2dRegionText('未选择模型', 'No model selected'));
        _loading = false;
      });
      return;
    }
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final local = await Live2DOnlineCatalog.cacheDefinition(definition);
      if (!mounted || generation != _generation) return;
      await _controller.whenAttached;
      if (!mounted || generation != _generation) return;
      if (_controller.value.isLoaded) {
        await _controller.unloadModel();
      }
      final ok = await _controller.loadModel(
        modelDir: local.modelDir,
        modelFileName: local.modelFile,
      );
      if (!mounted || generation != _generation) return;
      if (!ok) {
        setState(() {
          _error = _controller.value.lastError ?? StateError('模型加载失败');
          _loading = false;
        });
        return;
      }
      setState(() => _loading = false);
      widget.onModelLoaded?.call(local);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Live2DView(controller: _controller),
                // 绘制模式的半透明黑色蒙层：压暗模型但保留轮廓，位于区域层之下
                if (widget.scrim != null)
                  Positioned.fill(
                    child: IgnorePointer(child: widget.scrim!),
                  ),
                if (widget.overlay != null)
                  Positioned.fill(
                    child: IgnorePointer(child: widget.overlay!),
                  ),
                if (widget.foreground != null)
                  Positioned.fill(child: widget.foreground!),
                Positioned.fill(
                  child: ValueListenableBuilder<Live2DViewState>(
                    valueListenable: _controller,
                    builder: (context, state, _) {
                      if (_error != null && !state.isLoaded) {
                        return _placeholder(
                          theme,
                          icon: DsIconKind.info,
                          message: live2dRegionText(
                            '模型加载失败，点击重试',
                            'Failed to load model, tap to retry',
                          ),
                          onTap: _load,
                        );
                      }
                      if (_loading || state.isLoadingModel || !state.isLoaded) {
                        return _placeholder(
                          theme,
                          icon: DsIconKind.heart,
                          message: live2dRegionText(
                            '模型加载中…',
                            'Loading model…',
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                if (widget.topRight != null)
                  Positioned(top: 8, right: 8, child: widget.topRight!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(
    AppThemeData theme, {
    required DsIconKind icon,
    required String message,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: theme.surface.withValues(alpha: 0.88),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsIcon(icon, color: theme.primary),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(fontSize: 12, color: theme.text)),
          ],
        ),
      ),
    );
  }
}

/// 弹出模型自带 HitArea 选择面板，返回所选部位（取消返回 null）。
///
/// [available] 应传入尚未配置台词的 HitArea（按 id 去重）。
Future<Live2DModelHitArea?> showLive2DHitAreaPickerSheet(
  BuildContext context, {
  required List<Live2DModelHitArea> available,
}) {
  return SmoothBottomSheet.show<Live2DModelHitArea>(
    context: context,
    builder: (_) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final area in available)
          ListTile(
            title: Text(area.displayName),
            subtitle: area.displayName == area.id ? null : Text(area.id),
            onTap: () => Navigator.pop(context, area),
          ),
      ],
    ),
  );
}

/// 解析档案对应的本地模型定义（供预览与 HitArea 读取复用），
/// 与运行时 `modelDefinitionForArchive` 的导入模型来源保持一致。
Live2DModelDefinition? localDefinitionForArchive(Live2DArchive archive) {
  return modelDefinitionForArchive(
    archive,
    importedModels: Live2DPlugin.instance.importedModels,
  );
}
