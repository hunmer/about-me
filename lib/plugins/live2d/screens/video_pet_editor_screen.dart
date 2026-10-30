import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_player.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_video_pet_movement.dart';

import 'video_pet_animation_resource_editor.dart';
part 'video_pet_editor_gestures.dart';
part 'video_pet_editor_region_panel.dart';
part 'video_pet_editor_preset_panel.dart';
part 'video_pet_editor_layout.dart';

const _unchanged = Object();

String videoPetText(String zh, String en) =>
    (Get.locale?.languageCode ?? 'zh') == 'zh' ? zh : en;

/// Editor for a [VideoPetManifest].
///
/// The draft is isolated so cancel never mutates the incoming manifest.
class VideoPetEditorScreen extends StatefulWidget {
  const VideoPetEditorScreen({
    super.key,
    required this.manifest,
    required this.baseUri,
    this.resolvedSources = const {},
  });

  final VideoPetManifest manifest;
  final String baseUri;
  final Map<String, String> resolvedSources;

  @override
  State<VideoPetEditorScreen> createState() => _VideoPetEditorScreenState();
}

class _VideoPetEditorScreenState extends State<VideoPetEditorScreen> {
  late VideoPetManifest _draft;
  final _animationRequest = ValueNotifier<String?>(null);
  final _walkEnabled = ValueNotifier<bool>(true);
  final _stageKey = GlobalKey<JellyVideoPetStageState>();
  final _searchController = TextEditingController();
  final _jsonController = TextEditingController();

  String? _selectedRegionId;
  String? _selectedAnimationId;
  String _category = 'all';
  bool _isAddingRegion = false;
  bool _isPaused = false;
  bool _isTestMode = true;
  bool _showRegions = true;
  double _narrowToolsHeight = 300;
  String? _lastHitRegion;
  String? _lastActionAnimation;
  Rect? _gestureRect;
  Offset? _gestureOrigin;
  Rect? _gestureInitialRect;
  String? _gestureRegionId;
  _RegionGestureMode _gestureMode = _RegionGestureMode.none;

  @override
  void initState() {
    super.initState();
    _draft = VideoPetManifest.fromJson(
      Map<String, dynamic>.from(widget.manifest.toJson()),
    );
    _selectedRegionId = _draft.regions.isEmpty ? null : _draft.regions.first.id;
  }

  @override
  void dispose() {
    _animationRequest.dispose();
    _walkEnabled.dispose();
    _searchController.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  String _text(String key, String fallback) {
    if (key.isEmpty) return fallback;
    // 优先查统一翻译表（live2d/core 等），缺 key 时回退内置中文
    final translated = key.tr;
    return translated == key ? videoPetText(fallback, fallback) : translated;
  }

  VideoPetRegion? get _selectedRegion => _draft.regions
      .where((region) => region.id == _selectedRegionId)
      .firstOrNull;

  // 逐动画资源编辑（facing / moving）针对的是「点播选中的动画」，
  // 与交互区域选中状态无关。
  VideoPetAnimation? get _selectedAnimation => _draft.animations
      .where((animation) => animation.id == _selectedAnimationId)
      .firstOrNull;

  void _setDraft(VideoPetManifest value) {
    setState(() => _draft = value);
  }

  /// 用编辑后的单动画替换草稿中的对应项（按 id 匹配）。
  void _updateAnimation(VideoPetAnimation next) => _setDraft(
    _draft.copyWith(
      animations: [
        for (final item in _draft.animations) item.id == next.id ? next : item,
      ],
    ),
  );

  void _save() {
    try {
      _draft.validate();
      Navigator.of(context).pop(_draft);
    } catch (error) {
      _showMessage('$error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _requestAnimation(String id) {
    _selectedAnimationId = id;
    // Reset first so tapping the same animation restarts the player request.
    _animationRequest.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _animationRequest.value = id;
    });
    setState(() {});
  }

  List<VideoPetAnimation> get _visibleAnimations {
    final query = _searchController.text.trim().toLowerCase();
    return _draft.animations.where((animation) {
      final matchesQuery =
          query.isEmpty ||
          animation.name.toLowerCase().contains(query) ||
          animation.id.toLowerCase().contains(query);
      final matchesCategory =
          _category == 'all' || animation.category == _category;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  Set<String> get _categories => {
    'all',
    ..._draft.animations
        .map((animation) => animation.category)
        .where((category) => category.isNotEmpty),
  };

  void _importJson() {
    final decoded = jsonDecode(_jsonController.text);
    if (decoded is! Map) throw const FormatException('manifest JSON 必须是对象');
    final imported = VideoPetManifest.fromJson(
      Map<String, dynamic>.from(decoded),
    );
    _setDraft(imported);
    setState(() {
      _selectedRegionId = imported.regions.firstOrNull?.id;
      _selectedAnimationId = null;
    });
  }

  Future<void> _showJsonDialog({required bool importing}) async {
    _jsonController.text = importing
        ? ''
        : const JsonEncoder.withIndent('  ').convert(_draft.toJson());
    final action = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          importing
              ? _text('videoPet_importJson', '导入 JSON')
              : _text('videoPet_exportJson', '导出 JSON'),
        ),
        content: SizedBox(
          width: 680,
          child: TextField(
            controller: _jsonController,
            autofocus: importing,
            minLines: 12,
            maxLines: 24,
            readOnly: !importing,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: _text(
                'videoPet_manifestJsonHint',
                '仅粘贴或复制 manifest JSON',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_text('core_cancel', '取消')),
          ),
          if (!importing)
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: _jsonController.text),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) _showMessage(_text('videoPet_copied', '已复制 JSON'));
              },
              icon: const Icon(Icons.copy_outlined),
              label: Text(_text('videoPet_copy', '复制')),
            )
          else
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_text('videoPet_import', '导入')),
            ),
        ],
      ),
    );
    if (action != true || !importing) return;
    try {
      _importJson();
    } catch (error) {
      _showMessage('${_text('videoPet_invalidJson', 'JSON 无效')}: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 手绘纸墨风：DS 组件需要 AppTheme 祖先，由 DSThemeBridge 从
    // Material 亮暗桥接（面板等处取色走 DSThemeBridge.resolve）。
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Scaffold(
            backgroundColor: theme.background,
            body: Column(
              children: [
                // 编辑页轻量顶栏（design.md §2.1）：返回圆钮 + 居中标题 + 尾部动作。
                DSLightHeader(
                  title: _text('videoPet_editorTitle', '精灵图宠物编辑器'),
                  onBack: () => Navigator.of(context).maybePop(),
                  trailingWidth: 190,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DSIconButton(
                        icon: DsIconKind.upload,
                        size: 36,
                        color: theme.surfaceAlt,
                        iconColor: theme.textSub,
                        tooltip: _text('videoPet_importJson', '导入 JSON'),
                        onPressed: () => _showJsonDialog(importing: true),
                      ),
                      const SizedBox(width: 4),
                      DSIconButton(
                        icon: DsIconKind.download,
                        size: 36,
                        color: theme.surfaceAlt,
                        iconColor: theme.textSub,
                        tooltip: _text('videoPet_exportJson', '导出 JSON'),
                        onPressed: () => _showJsonDialog(importing: false),
                      ),
                      const SizedBox(width: 8),
                      DSButton(
                        label: _text('videoPet_save', '保存'),
                        icon: DsIconKind.save,
                        size: DSButtonSize.sm,
                        onPressed: _save,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;
                      if (wide) {
                        return Row(
                          children: [
                            SizedBox(width: 300, child: _buildRegionPanel()),
                            Expanded(child: _buildPreviewAndAnimationPanel()),
                            SizedBox(width: 330, child: _buildBindingPanel()),
                          ],
                        );
                      }
                      return _buildNarrowBody(context);
                    },
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
