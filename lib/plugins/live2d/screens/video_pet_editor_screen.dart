import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/video/pet_store_catalog.dart';
import 'package:aboutme/plugins/live2d/video/pet_store_service.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_import.dart';
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
    this.petStoreService,
    this.onActionInstalled,
  });

  final VideoPetManifest manifest;
  final String baseUri;
  final Map<String, String> resolvedSources;

  /// 宠物商店服务（服务端动作下载）；null 时若 manifest 带商店标记
  /// 则按默认配置自建（测试可注入）
  final PetStoreService? petStoreService;

  /// 动作下载成功（资源文件已落盘）后立即回调：参数是
  /// 「进入编辑器时的 manifest + 迄今已下载的动作」，不含草稿中的
  /// 其它编辑；调用方应把它写回存档，保证未点保存退出也不丢
  /// 已下载的资源。下载 ≠ 启用：新动作 enabled 恒为 false。
  final void Function(VideoPetManifest manifest)? onActionInstalled;

  @override
  State<VideoPetEditorScreen> createState() => _VideoPetEditorScreenState();
}

class _VideoPetEditorScreenState extends State<VideoPetEditorScreen>
    with SingleTickerProviderStateMixin {
  late VideoPetManifest _draft;
  final _animationRequest = ValueNotifier<String?>(null);
  // AB 循环点播（动作编辑的移动区间预览）；测试模式注入舞台、
  // 编辑模式直连播放器，见 [_previewSegmentLoop]。
  final _frameLoopRequest = ValueNotifier<VideoPetManualAnimation?>(null);
  VideoPetManualAnimation? _loopPreview;
  int _loopPreviewNonce = 0;
  final _walkEnabled = ValueNotifier<bool>(true);
  final _stageKey = GlobalKey<JellyVideoPetStageState>();
  final _searchController = TextEditingController();
  final _jsonController = TextEditingController();
  // 窄屏 Tab 的控制器：供「动作预设 → 编辑」等外部入口跳转指定 tab。
  late final TabController _narrowTabs = TabController(length: 4, vsync: this);

  String? _selectedRegionId;
  String? _selectedAnimationId;
  String _category = 'all';
  bool _isAddingRegion = false;
  bool _isPaused = false;
  bool _isTestMode = true;
  bool _showRegions = true;
  double _narrowToolsHeight = 300;
  // 窄屏工具区高度持久化 key（经 SharedPreferences 存取）
  static const _narrowToolsHeightPrefKey =
      'video_pet_editor.narrowToolsHeight';
  String? _lastHitRegion;
  String? _lastActionAnimation;
  // 测试模式点击区域随机挑台词用（避免与走动等其它随机共用）
  final math.Random _messageRandom = math.Random();
  Rect? _gestureRect;
  Offset? _gestureOrigin;
  Rect? _gestureInitialRect;
  String? _gestureRegionId;
  _RegionGestureMode _gestureMode = _RegionGestureMode.none;

  // ===== 服务端动作（动作商店）状态 =====
  /// 服务端未下载动作列表（加载成功后）
  List<VideoPetAnimation> _serverAnimations = const [];
  bool _serverLoading = false;
  String? _serverError;

  /// 正在下载的动作 id 集合
  final Set<String> _downloadingIds = {};

  /// 下载失败待重试的动作 id 集合（按钮显示重试图标）
  final Set<String> _downloadFailedIds = {};

  /// 是否正在批量下载全部服务端动作
  bool _downloadingAll = false;

  /// 编辑器自建的商店服务（dispose 时释放；注入的由宿主管理）
  PetStoreService? _ownStoreService;

  /// 已入档快照：进入编辑器时的 manifest + 迄今已下载的动作，
  /// 经 [widget.onActionInstalled] 增量回传（不含草稿的其它编辑）
  late VideoPetManifest _installedManifest;

  @override
  void initState() {
    super.initState();
    _draft = VideoPetManifest.fromJson(
      Map<String, dynamic>.from(widget.manifest.toJson()),
    );
    _installedManifest = widget.manifest;
    _loadNarrowToolsHeight();
    _selectedRegionId = _draft.regions.isEmpty ? null : _draft.regions.first.id;
    // manifest 带商店标记时自动拉取服务端动作列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _serverActionsEnabled) _loadServerActions();
    });
  }

  @override
  void dispose() {
    _ownStoreService?.close();
    _narrowTabs.dispose();
    _animationRequest.dispose();
    _frameLoopRequest.dispose();
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

  // ===== 窄屏工具区高度持久化（拖完写盘，进入时恢复）=====

  Future<void> _loadNarrowToolsHeight() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_narrowToolsHeightPrefKey);
      if (saved == null || saved < 140 || !mounted) return;
      setState(() {
        // 保存时已在合法区间；再 clamp 防跨设备屏高变化的布局溢出
        _narrowToolsHeight = saved
            .clamp(140.0, MediaQuery.sizeOf(context).height * .8)
            .toDouble();
      });
    } catch (error) {
      debugPrint('[VideoPetEditor] 恢复工具区高度失败：$error');
    }
  }

  Future<void> _saveNarrowToolsHeight() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_narrowToolsHeightPrefKey, _narrowToolsHeight);
    } catch (error) {
      debugPrint('[VideoPetEditor] 保存工具区高度失败：$error');
    }
  }

  /// 用编辑后的单动画替换草稿中的对应项（按 id 匹配）。
  void _updateAnimation(VideoPetAnimation next) => _setDraft(
    _draft.copyWith(
      animations: [
        for (final item in _draft.animations) item.id == next.id ? next : item,
      ],
    ),
  );

  // ===== 服务端动作（动作商店）=====

  /// manifest metadata 携带商店动作地址时启用服务端动作区块
  bool get _serverActionsEnabled =>
      (widget.manifest.metadata[kPetStoreMetadataActionsUrl] ?? '').isNotEmpty;

  /// 商店服务：优先注入实例；未注入且区块启用时自建默认实例
  PetStoreService? get _storeService =>
      widget.petStoreService ??
      (_serverActionsEnabled ? (_ownStoreService ??= PetStoreService()) : null);

  /// 拉取服务端动作列表；草稿中已有的动作不再展示
  Future<void> _loadServerActions() async {
    final service = _storeService;
    if (service == null) return;
    setState(() {
      _serverLoading = true;
      _serverError = null;
    });
    try {
      // 始终访问商店目录的最新动作地址（metadata 地址安装后可能过期）
      final actions = await service.fetchLatestActions(widget.manifest);
      if (!mounted) return;
      setState(() {
        _serverAnimations = actions
            .where(
              (action) =>
                  !_draft.animations.any((owned) => owned.id == action.id),
            )
            .toList();
        _serverLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _serverError = '$error';
        _serverLoading = false;
      });
    }
  }

  /// 下载服务端动作：成功后合入草稿并立即点播预览。
  ///
  /// 取消编辑时草稿整体丢弃，未保存的下载动作不会写回档案。
  /// 下载服务端动作：成功后合入草稿；手动单个下载立即点播预览，
  /// 批量下载（[autoplay] 为 false）不触发自动播放。
  ///
  /// 取消编辑时草稿整体丢弃，未保存的下载动作不会写回档案。
  Future<void> _downloadServerAction(
    VideoPetAnimation animation, {
    bool autoplay = true,
  }) async {
    final service = _storeService;
    if (service == null) return;
    if (_downloadingIds.contains(animation.id)) return;
    // 幂等：已在草稿中的动作不重复下载
    if (_draft.animations.any((owned) => owned.id == animation.id)) return;
    setState(() {
      _downloadingIds.add(animation.id);
      _downloadFailedIds.remove(animation.id);
    });
    try {
      final package = await service.downloadAction(
        package: VideoPetPackage(
          manifest: _draft,
          baseUri: widget.baseUri,
          resolvedSources: widget.resolvedSources,
        ),
        animation: animation,
      );
      // 仅合入该动作，不整包替换（避免覆盖草稿中的其它修改）
      final resolved = package.manifest.animation(animation.id);
      if (resolved == null) {
        throw FormatException('下载结果缺少动作 ${animation.id}');
      }
      if (!mounted) return;
      _setDraft(_draft.copyWith(animations: [..._draft.animations, resolved]));
      // 下载即入档：不等保存，把「进入时的 manifest + 已下载动作」
      // 增量回传调用方写回存档（未保存退出也不丢已下载资源）
      _installedManifest = _installedManifest.copyWith(
        animations: [..._installedManifest.animations, resolved],
      );
      widget.onActionInstalled?.call(_installedManifest);
      setState(() {
        _serverAnimations = _serverAnimations
            .where((item) => item.id != animation.id)
            .toList();
        _downloadingIds.remove(animation.id);
        _downloadFailedIds.remove(animation.id);
      });
      // 手动单个下载立即点播，方便预览新动作
      if (autoplay) _requestAnimation(resolved.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloadingIds.remove(animation.id);
        // 标记失败态：按钮转为重试图标，可再次点击重试
        _downloadFailedIds.add(animation.id);
      });
      _showMessage(
        'videoPet_serverDownloadFailed'.trParams({'error': '$error'}),
      );
    }
  }

  void _save() {
    try {
      _draft.validate();
      Navigator.of(context).pop(_draft);
    } catch (error) {
      _showMessage('$error');
    }
  }

  /// 是否还有未下载的服务端动作（按当前草稿 id 过滤）
  bool get _hasPendingServerActions => _serverAnimations.any(
    (action) => !_draft.animations.any((owned) => owned.id == action.id),
  );

  /// 一键下载全部未下载的服务端动作（串行逐个下载；
  /// 单项失败不中断其余，失败项保留重试态）。
  Future<void> _downloadAllServerActions() async {
    if (_downloadingAll) return;
    final pending = _serverAnimations
        .where((action) => !_draft.animations.any((o) => o.id == action.id))
        .toList();
    if (pending.isEmpty) return;
    setState(() => _downloadingAll = true);
    try {
      for (final action in pending) {
        // 串行逐个下载，且不触发自动播放
        await _downloadServerAction(action, autoplay: false);
      }
    } finally {
      if (mounted) setState(() => _downloadingAll = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _requestAnimation(String id) {
    _selectedAnimationId = id;
    _cancelSegmentLoop();
    // Reset first so tapping the same animation restarts the player request.
    _animationRequest.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _animationRequest.value = id;
    });
    setState(() {});
  }

  /// AB 循环预览：在预览区循环播放 [startFrame, endFrame] 区间。
  /// 测试模式经舞台注入（busy 暂停走动），编辑模式直连播放器。
  void _previewSegmentLoop(String animationId, int startFrame, int endFrame) {
    final request = VideoPetManualAnimation(
      animationId: animationId,
      startFrame: startFrame,
      endFrame: endFrame,
      loop: true,
      nonce: ++_loopPreviewNonce,
    );
    _animationRequest.value = null;
    setState(() => _loopPreview = request);
    if (_isTestMode) {
      _stageKey.currentState?.playFrameAnimation(request);
    } else {
      _frameLoopRequest.value = request;
    }
  }

  /// 取消 AB 循环预览，恢复正常播放。
  void _cancelSegmentLoop() {
    final active = _loopPreview;
    _loopPreview = null;
    _frameLoopRequest.value = null;
    _stageKey.currentState?.cancelFrameAnimation();
    if (active != null) setState(() {});
  }

  /// 动画列表条目：本地草稿动作与服务端未下载动作融合展示
  List<_AnimationListItem> get _visibleAnimations {
    bool matches(VideoPetAnimation animation) {
      final query = _searchController.text.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          animation.name.toLowerCase().contains(query) ||
          animation.id.toLowerCase().contains(query);
      final matchesCategory =
          _category == 'all' || animation.category == _category;
      return matchesQuery && matchesCategory;
    }

    return [
      // 本地动作在前（保持草稿顺序），未下载的服务端动作随后
      for (final animation in _draft.animations)
        if (matches(animation))
          _AnimationListItem(animation: animation, isRemote: false),
      // 远程项在下载完成前不进入草稿/播放器，仅作列表占位；
      // 按当前草稿 id 再过滤（导入 JSON 等修改后避免本地/远程同 id 重复）
      if (_serverActionsEnabled)
        for (final action in _serverAnimations)
          if (matches(action) &&
              !_draft.animations.any((owned) => owned.id == action.id))
            _AnimationListItem(animation: action, isRemote: true),
    ];
  }

  /// 分类筛选并集：本地草稿 + 未下载服务端动作
  Set<String> get _categories => {
    'all',
    ..._draft.animations
        .map((animation) => animation.category)
        .where((category) => category.isNotEmpty),
    ..._serverAnimations
        .map((action) => action.category)
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

/// 动画列表条目：[animation] 为动作数据，[isRemote] 标记是否为
/// 服务端未下载动作（下载完成前不进入草稿，仅展示与下载入口）。
class _AnimationListItem {
  const _AnimationListItem({required this.animation, required this.isRemote});

  final VideoPetAnimation animation;
  final bool isRemote;
}
