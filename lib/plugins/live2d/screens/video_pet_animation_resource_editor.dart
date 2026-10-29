import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_player.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 单个动画的 facing / moving 资源编辑器。
///
/// 朝向：`''` / `'left'` / `'right'` 三选一；移动：`null`（默认连续移动）/
/// `[]`（全程不位移）/ 非空（分段移动）三态用独立下拉显式切换。
/// 分段移动不再使用行内表单：段以列表展示（点按编辑、可删除），新增/编辑
/// 通过 [SmoothBottomSheet] 弹出分帧网格，在精灵图帧上点选起点与终点，
/// 确认后按默认速度 1.0（可改）插入/更新段；重叠与非法速度在弹层内校验。
class VideoPetAnimationResourceEditor extends StatefulWidget {
  const VideoPetAnimationResourceEditor({
    super.key,
    required this.animation,
    required this.onChanged,
    this.baseUri = '',
    this.resolvedSources = const {},
  });

  /// 当前动画；父级用 `ValueKey(animation.id)` 包裹本 widget。
  final VideoPetAnimation animation;

  /// 仅在能构成「合法单动画」时回调。
  final ValueChanged<VideoPetAnimation> onChanged;

  /// 资源基址与已解析来源（用于在弹层中加载精灵图原图）。
  final String baseUri;
  final Map<String, String> resolvedSources;

  @override
  State<VideoPetAnimationResourceEditor> createState() =>
      _VideoPetAnimationResourceEditorState();
}

/// 分段移动的三种模式值，与 `VideoPetAnimation.moving` 三态一一对应。
const String _modeDefault = 'default';
const String _modeNone = 'none';
const String _modeSegments = 'segments';

class _VideoPetAnimationResourceEditorState
    extends State<VideoPetAnimationResourceEditor> {
  /// 最近一次已提交 / 父级传入的动画。
  late VideoPetAnimation _latest;
  String _mode = _modeDefault;

  VideoPetSpritesheet? get _spritesheet => _latest.spritesheet;

  List<VideoPetLocomotion> get _segments =>
      _mode == _modeSegments ? (_latest.moving ?? const []) : const [];

  @override
  void initState() {
    super.initState();
    _latest = widget.animation;
    _syncFromAnimation();
  }

  @override
  void didUpdateWidget(covariant VideoPetAnimationResourceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有切到另一个动画才重建模式；同 id 的父级重建由本 widget
    // 自己的提交触发，绝不能重置状态。
    if (widget.animation.id != oldWidget.animation.id) {
      _latest = widget.animation;
      _syncFromAnimation();
    }
  }

  String _t(String zh, String en) =>
      (Get.locale?.languageCode ?? 'zh') == 'zh' ? zh : en;

  /// 按当前动画的三态语义重建本地下拉模式。
  void _syncFromAnimation() {
    final moving = _latest.moving;
    if (moving == null) {
      _mode = _modeDefault;
      return;
    }
    if (moving.isEmpty) {
      _mode = _modeNone;
      return;
    }
    _mode = _modeSegments;
  }

  void _emit(VideoPetAnimation next) {
    _latest = next;
    widget.onChanged(next);
  }

  void _setFacing(String value) => _emit(_latest.copyWith(facing: value));

  /// 解析当前动画精灵图原图的可用 URI（供分帧弹层加载）。
  String? get _resolvedImageUri {
    final source = _latest.imageSource;
    if (source == null) return null;
    final resolved = Uri.parse(widget.baseUri).resolve(source).toString();
    return widget.resolvedSources[resolved] ?? resolved;
  }

  /// 切换三态移动模式；切到 default / none 是显式操作，直接提交对应语义。
  void _changeMode(String? next) {
    if (next == null || next == _mode) return;
    if (next == _modeDefault) {
      _mode = _modeDefault;
      setState(() {});
      _emit(_latest.copyWith(moving: null));
      return;
    }
    if (next == _modeNone) {
      _mode = _modeNone;
      setState(() {});
      _emit(_latest.copyWith(moving: const <VideoPetLocomotion>[]));
      return;
    }
    // 切到分段模式：空列表起步，点「新增区间」从帧网格选择。
    _mode = _modeSegments;
    setState(() {});
    _emit(_latest.copyWith(moving: const <VideoPetLocomotion>[]));
  }

  /// 新增 / 编辑移动区间：弹出分帧网格 sheet，选择起止帧与速度。
  Future<void> _openSegmentSheet({int? editIndex}) async {
    final others = <VideoPetLocomotion>[
      for (var i = 0; i < _segments.length; i++)
        if (i != editIndex) _segments[i],
    ];
    final result = await SmoothBottomSheet.showWithTitle<VideoPetLocomotion>(
      context: context,
      title: editIndex == null
          ? _t('新增移动区间', 'Add moving segment')
          : _t('编辑移动区间', 'Edit moving segment'),
      showCloseButton: true,
      child: _MovingSegmentSheet(
        sheet: _spritesheet,
        imageUri: _resolvedImageUri,
        others: others,
        initial: editIndex == null ? null : _segments[editIndex],
      ),
    );
    if (result == null) return;
    final next = <VideoPetLocomotion>[
      if (editIndex == null) ..._segments else ...others,
      result,
    ]..sort((a, b) => a.startFrame.compareTo(b.startFrame));
    _emit(_latest.copyWith(moving: next));
  }

  void _deleteSegment(int index) {
    if (index < 0 || index >= _segments.length) return;
    final next = <VideoPetLocomotion>[..._segments]..removeAt(index);
    if (next.isEmpty) {
      // 删光所有段 = 明确「全程不位移」，不是回到默认连续移动。
      _mode = _modeNone;
      _emit(_latest.copyWith(moving: const <VideoPetLocomotion>[]));
      return;
    }
    _emit(_latest.copyWith(moving: next));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spritesheet = _spritesheet;
    final facing = <String>['', 'left', 'right'].contains(_latest.facing)
        ? _latest.facing
        : '';
    // 自带主题桥：脱离 DS 主题树（如测试）也能安全使用 DS 组件。
    return DSThemeBridge(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DropdownButtonFormField<String>(
            key: const ValueKey('videoPetFacing'),
            initialValue: facing,
            decoration: InputDecoration(
              labelText: _t('原始朝向 facing', 'Original facing'),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: '',
                child: Text(_t('未设置', 'Not set')),
              ),
              DropdownMenuItem<String>(
                value: 'left',
                child: Text(_t('原始朝左', 'Facing left')),
              ),
              DropdownMenuItem<String>(
                value: 'right',
                child: Text(_t('原始朝右', 'Facing right')),
              ),
            ],
            onChanged: (value) => _setFacing(value ?? ''),
          ),
          const SizedBox(height: 8),
          Text(
            _frameInfo(),
            key: const ValueKey('videoPetFrameInfo'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const ValueKey('videoPetMovingMode'),
            initialValue: _mode,
            decoration: InputDecoration(
              labelText: _t('移动方式', 'Movement'),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: _modeDefault,
                child: Text(_t('默认连续移动', 'Default continuous movement')),
              ),
              DropdownMenuItem<String>(
                value: _modeNone,
                enabled: spritesheet != null,
                child: Text(_t('全程不位移', 'No movement')),
              ),
              DropdownMenuItem<String>(
                value: _modeSegments,
                enabled: spritesheet != null,
                child: Text(_t('分段移动', 'Moving segments')),
              ),
            ],
            onChanged: _changeMode,
          ),
          if (spritesheet == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _t(
                  '缺少 spritesheet：无法使用「全程不位移」与「分段移动」（moving requires a spritesheet）',
                  'moving requires a spritesheet',
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (_mode == _modeSegments) ...<Widget>[
            const SizedBox(height: 8),
            if (_segments.isEmpty)
              Text(
                _t('尚无移动区间，点下方按钮从精灵图帧中选择', 'No segments yet'),
                style: theme.textTheme.bodySmall,
              ),
            for (var i = 0; i < _segments.length; i++)
              _buildSegmentTile(context, i),
            if (spritesheet != null)
              Align(
                alignment: Alignment.centerLeft,
                child: DSButton(
                  key: const ValueKey('videoPetMovingAdd'),
                  label: _t('新增区间', 'Add segment'),
                  icon: DsIconKind.plus,
                  variant: DSButtonVariant.dashed,
                  size: DSButtonSize.sm,
                  onPressed: () => _openSegmentSheet(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// 帧信息文案：帧数 / 合法帧范围 / fps，降低帧号误填概率。
  String _frameInfo() {
    final spritesheet = _spritesheet;
    if (spritesheet == null) {
      return _t(
        '该动作没有 spritesheet，无法配置分段移动',
        'This animation has no spritesheet, so moving segments are unavailable',
      );
    }
    final last = spritesheet.frameCount - 1;
    return _t(
      '帧数 ${spritesheet.frameCount} · 合法帧 0..$last · fps ${spritesheet.fps}',
      'frames ${spritesheet.frameCount} · valid frames 0..$last · fps ${spritesheet.fps}',
    );
  }

  /// 单段展示：帧区间 + 帧数 + 速度；点按编辑，右侧删除。
  Widget _buildSegmentTile(BuildContext context, int index) {
    final dsTheme = DSThemeBridge.resolve(context);
    final segment = _segments[index];
    final frames = segment.endFrame - segment.startFrame + 1;
    return Padding(
      key: ValueKey('videoPetMovingSegment-$index'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: dsSketchDecoration(
          theme: dsTheme,
          fillColor: dsTheme.surface,
          radius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: Row(
          children: <Widget>[
            DsIcon(DsIconKind.animation, size: 16, color: dsTheme.textSub),
            const SizedBox(width: 6),
            Expanded(
              child: InkWell(
                key: ValueKey('videoPetMovingEdit-$index'),
                onTap: () => _openSegmentSheet(editIndex: index),
                child: Text(
                  _t(
                    '帧 ${segment.startFrame}–${segment.endFrame}（$frames 帧）· ${segment.speed} 像素/帧',
                    'frames ${segment.startFrame}-${segment.endFrame} ($frames) · ${segment.speed} px/frame',
                  ),
                ),
              ),
            ),
            DSIconButton(
              key: ValueKey('videoPetMovingDelete-$index'),
              icon: DsIconKind.trash,
              size: 30,
              color: dsTheme.surfaceAlt,
              iconColor: dsTheme.danger,
              tooltip: _t('删除该段', 'Delete this segment'),
              onPressed: () => _deleteSegment(index),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分帧选择弹层：精灵图按网格拆成帧缩略图，点选起点与终点，
/// 输入速度后确认返回新的 [VideoPetLocomotion]；取消弹回 null。
class _MovingSegmentSheet extends StatefulWidget {
  const _MovingSegmentSheet({
    required this.sheet,
    required this.imageUri,
    required this.others,
    this.initial,
  });

  final VideoPetSpritesheet? sheet;
  final String? imageUri;
  final List<VideoPetLocomotion> others;
  final VideoPetLocomotion? initial;

  @override
  State<_MovingSegmentSheet> createState() => _MovingSegmentSheetState();
}

class _MovingSegmentSheetState extends State<_MovingSegmentSheet> {
  /// 切好的每帧图片（与精灵图网格逐帧对应，直接交给 RawImage 显示）。
  List<ui.Image> _frameImages = const [];
  Object? _loadError;
  final _speed = TextEditingController();
  int? _start;
  int? _end;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _start = initial.startFrame;
      _end = initial.endFrame;
      _speed.text = _formatNumber(initial.speed);
    } else {
      _speed.text = '1';
    }
    final uri = widget.imageUri;
    if (uri == null || widget.sheet == null) {
      _loadError = StateError('缺少精灵图来源');
      return;
    }
    _splitFrames();
  }

  @override
  void dispose() {
    for (final frame in _frameImages) {
      frame.dispose();
    }
    _speed.dispose();
    super.dispose();
  }

  /// 解码一次精灵图，按网格把每帧切成独立 [ui.Image]（drawImageRect + toImage），
  /// 帧格用 RawImage 直接显示，无需再编码/解码。
  Future<void> _splitFrames() async {
    final sheet = widget.sheet!;
    try {
      final bytes = await readVideoPetImageBytes(Uri.parse(widget.imageUri!));
      final codec = await ui.instantiateImageCodec(bytes);
      final full = (await codec.getNextFrame()).image;
      final frameW = full.width ~/ sheet.columns;
      final frameH = full.height ~/ sheet.rows;
      final frames = <ui.Image>[];
      final paint = ui.Paint()..filterQuality = FilterQuality.none;
      for (var index = 0; index < sheet.frameCount; index++) {
        final src = ui.Rect.fromLTWH(
          (index % sheet.columns) * frameW.toDouble(),
          (index ~/ sheet.columns) * frameH.toDouble(),
          frameW.toDouble(),
          frameH.toDouble(),
        );
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawImageRect(
          full,
          src,
          ui.Offset.zero & src.size,
          paint,
        );
        frames.add(await recorder.endRecording().toImage(frameW, frameH));
      }
      full.dispose();
      codec.dispose();
      if (mounted) setState(() => _frameImages = frames);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  String _t(String zh, String en) =>
      (Get.locale?.languageCode ?? 'zh') == 'zh' ? zh : en;

  static String _formatNumber(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  /// 该帧是否落在其他既有区间内（禁选）。
  bool _occupied(int frame) => widget.others.any(
        (segment) =>
            frame >= segment.startFrame && frame <= segment.endFrame,
      );

  void _tapFrame(int frame) {    if (_occupied(frame)) return;
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        // 开始新一轮选择。
        _start = frame;
        _end = null;
        return;
      }
      // 第二次点击：自动保证 start <= end。
      if (frame < _start!) {
        _end = _start;
        _start = frame;
      } else {
        _end = frame;
      }
    });
  }

  /// 新区间是否与既有区间重叠。
  bool get _overlaps =>
      _start != null &&
      _end != null &&
      widget.others.any(
        (segment) => _start! <= segment.endFrame && segment.startFrame <= _end!,
      );

  double? get _speedValue {
    final text = _speed.text.trim();
    final value = double.tryParse(text);
    if (value == null || !value.isFinite || value <= 0) return null;
    return value;
  }

  bool get _valid => _start != null && _end != null && !_overlaps && _speedValue != null;

  String? get _errorText {
    if (_start == null || _end == null) {
      return _t('请点选起点帧与终点帧', 'Pick a start and an end frame');
    }
    if (_overlaps) return _t('与既有区间重叠', 'Overlaps an existing segment');
    if (_speedValue == null) {
      return _t('速度必须是大于 0 的数字（像素/动画帧）', 'Speed must be positive');
    }
    return null;
  }

  void _confirm() {
    if (!_valid) return;
    Navigator.of(context).pop(
      VideoPetLocomotion(
        startFrame: _start!,
        endFrame: _end!,
        speed: _speedValue!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dsTheme = DSThemeBridge.resolve(context);
    final sheet = widget.sheet;
    return Padding(
      key: const ValueKey('videoPetMovingSheet'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            _t(
              '先点起点帧，再点终点帧（灰色为既有区间）',
              'Tap a start frame then an end frame',
            ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Flexible(
            child: _buildFrameGrid(context, sheet, dsTheme),
          ),
          if (_loadError != null)
            Text(
              _t('精灵图缩略图加载失败，仅显示帧号', 'Thumbnail load failed'),
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 10),
          DSInput(
            key: const ValueKey('videoPetMovingSheetSpeed'),
            controller: _speed,
            hint: _t('速度（像素/动画帧）', 'Speed (px/frame)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Text(
            _errorText ?? '',
            key: const ValueKey('videoPetMovingSheetError'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: dsTheme.textSub,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              DSButton(
                key: const ValueKey('videoPetMovingSheetCancel'),
                label: _t('取消', 'Cancel'),
                variant: DSButtonVariant.ghost,
                size: DSButtonSize.sm,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              DSButton(
                key: const ValueKey('videoPetMovingSheetConfirm'),
                label: widget.initial == null
                    ? _t('插入区间', 'Insert')
                    : _t('保存', 'Save'),
                size: DSButtonSize.sm,
                onPressed: _valid ? _confirm : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 分帧网格：[_splitFrames] 已把精灵图逐帧切成独立小图，格子直接显示。
  Widget _buildFrameGrid(
    BuildContext context,
    VideoPetSpritesheet? sheet,
    AppThemeData dsTheme,
  ) {
    if (sheet == null) {
      return Text(
        _t('缺少精灵图配置', 'Missing spritesheet'),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    // 放大格子：按最大宽度自适应列数（每格约 160px 宽），行序仍与帧序一致。
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        childAspectRatio: sheet.frameWidth / sheet.frameHeight,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      shrinkWrap: true,
      itemCount: sheet.frameCount,
      itemBuilder: (context, frame) =>
          _buildFrameCell(context, dsTheme, frame),
    );
  }

  Widget _buildFrameCell(
    BuildContext context,
    AppThemeData dsTheme,
    int frame,
  ) {
    final occupied = _occupied(frame);
    final isStart = _start == frame;
    final isEnd = _end == frame;
    final inRange =
        _start != null && _end != null && frame >= _start! && frame <= _end!;
    final borderColor = isStart || isEnd
        ? dsTheme.primary
        : inRange
        ? dsTheme.hatch
        : dsTheme.textSub.withValues(alpha: .35);
    final provider = frame < _frameImages.length ? _frameImages[frame] : null;
    return InkWell(
      key: ValueKey('videoPetFrameCell-$frame'),      onTap: occupied ? null : () => _tapFrame(frame),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: occupied
                ? dsTheme.disabled
                : borderColor,
            width: (isStart || isEnd) && !occupied ? 2.4 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
          color: occupied
              ? dsTheme.disabled.withValues(alpha: .3)
              : inRange
              ? dsTheme.hatch.withValues(alpha: .5)
              : null,
        ),
        padding: const EdgeInsets.all(1),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (provider != null)
              RawImage(image: provider, fit: BoxFit.contain),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: Text(
                  '$frame',
                  style: TextStyle(
                    fontSize: 9,
                    color: DSThemeBridge.resolve(context).text,
                    backgroundColor: DSThemeBridge.resolve(
                      context,
                    ).surface.withValues(alpha: .7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
