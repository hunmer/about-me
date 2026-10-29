import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';

/// 单个动画的 facing / moving 资源编辑器。
///
/// 朝向：`''` / `'left'` / `'right'` 三选一；移动：`null`（默认连续移动）/
/// `[]`（全程不位移）/ 非空（分段移动）三态用独立下拉显式切换，不用「删光所有段」
/// 隐式表达默认态。分段输入先落在本 widget 的 [TextEditingController] 草稿里，
/// 只有整段列表通过单动画校验时才回调 [onChanged]，中间态绝不外泄；不做静默修复
/// （不截断小数帧号、不调小结束帧、不合并重叠、不 clamp 速度）。
class VideoPetAnimationResourceEditor extends StatefulWidget {
  const VideoPetAnimationResourceEditor({
    super.key,
    required this.animation,
    required this.onChanged,
  });

  /// 当前动画；父级用 `ValueKey(animation.id)` 包裹本 widget。
  final VideoPetAnimation animation;

  /// 仅在能构成「合法单动画」时回调。
  final ValueChanged<VideoPetAnimation> onChanged;

  @override
  State<VideoPetAnimationResourceEditor> createState() =>
      _VideoPetAnimationResourceEditorState();
}

/// 分段移动的三种模式值，与 `VideoPetAnimation.moving` 三态一一对应。
const String _modeDefault = 'default';
const String _modeNone = 'none';
const String _modeSegments = 'segments';

/// 单段解析结果：`error` 与 `value` 恰好一个非空。
typedef _SegmentParse = ({VideoPetLocomotion? value, String? error});

class _VideoPetAnimationResourceEditorState
    extends State<VideoPetAnimationResourceEditor> {
  /// 最近一次已提交 / 父级传入的动画，避免同一帧内连续提交用到过期快照。
  late VideoPetAnimation _latest;
  String _mode = _modeDefault;
  List<_SegmentDraft> _segments = <_SegmentDraft>[];

  VideoPetSpritesheet? get _spritesheet => _latest.spritesheet;
  int? get _frameCount => _spritesheet?.frameCount;

  @override
  void initState() {
    super.initState();
    _latest = widget.animation;
    _syncFromAnimation();
  }

  @override
  void didUpdateWidget(covariant VideoPetAnimationResourceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _latest = widget.animation;
    // 只有切到另一个动画才重建本地控制器与模式；同 id 的父级重建由本 widget
    // 自己的提交触发，绝不能重置正在输入的文本。
    if (widget.animation.id != oldWidget.animation.id) {
      _retireSegments(_segments);
      _segments = <_SegmentDraft>[];
      _syncFromAnimation();
    }
  }

  @override
  void dispose() {
    for (final draft in _segments) {
      draft.dispose();
    }
    super.dispose();
  }

  String _t(String zh, String en) =>
      (Get.locale?.languageCode ?? 'zh') == 'zh' ? zh : en;

  /// 数值展示：整数不带小数点，其余保留原始精度（不做四舍五入）。
  static String _formatNumber(double value) {
    if (!value.isFinite) return value.toString();
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  /// 按当前动画的三态语义重建本地下拉模式与分段草稿。
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
    _segments = <_SegmentDraft>[
      for (final segment in moving)
        _SegmentDraft(segment.startFrame, segment.endFrame, segment.speed),
    ];
  }

  /// 延后到本帧重建后再释放：控件卸载时会先从旧控制器移除监听，立刻 dispose
  /// 会触发 debug 下的「used after being disposed」。
  void _retireSegments(List<_SegmentDraft> drafts) {
    if (drafts.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final draft in drafts) {
        draft.dispose();
      }
    });
  }

  void _emit(VideoPetAnimation next) {
    _latest = next;
    widget.onChanged(next);
  }

  void _setFacing(String value) => _emit(_latest.copyWith(facing: value));

  /// 切换三态移动模式；切到 default / none 是显式操作，直接提交对应语义。
  void _changeMode(String? next) {
    if (next == null || next == _mode) return;
    _retireSegments(_segments);
    _segments = <_SegmentDraft>[];
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
    // 切到分段模式：无可继承分段时补一段默认段（start = min(上一段 end + 1,
    // frameCount - 1)，无上一段则 0；end = start；speed = 1.0）。
    _mode = _modeSegments;
    _segments = <_SegmentDraft>[_createDefaultSegment()];
    setState(() {});
    final valid = _validMoving();
    if (valid != null) _emit(_latest.copyWith(moving: valid));
  }

  /// 新增一段：起始帧取「上一段结束帧 + 1」，被帧数上限压住时即上限值——
  /// 这可能产生重叠，交由用户看到错误后自行调整（不静默修正）。
  void _addSegment() {
    final frameCount = _frameCount;
    if (frameCount == null || _mode != _modeSegments) return;
    int? previousEnd;
    for (final draft in _segments.reversed) {
      final parsed = int.tryParse(draft.endController.text.trim());
      if (parsed != null) {
        previousEnd = parsed;
        break;
      }
    }
    setState(() {
      _segments = <_SegmentDraft>[
        ..._segments,
        _createDefaultSegment(previousEnd: previousEnd),
      ];
    });
    final valid = _validMoving();
    if (valid != null) _emit(_latest.copyWith(moving: valid));
  }

  void _deleteSegment(int index) {
    if (index < 0 || index >= _segments.length) return;
    final removed = _segments[index];
    setState(() => _segments = <_SegmentDraft>[..._segments]..removeAt(index));
    _retireSegments(<_SegmentDraft>[removed]);
    if (_segments.isEmpty) {
      // 删光所有段 = 明确「全程不位移」，不是回到默认连续移动。
      _mode = _modeNone;
      _emit(_latest.copyWith(moving: const <VideoPetLocomotion>[]));
      return;
    }
    final valid = _validMoving();
    if (valid != null) _emit(_latest.copyWith(moving: valid));
  }

  _SegmentDraft _createDefaultSegment({int? previousEnd}) {
    final last = (_frameCount ?? 1) - 1;
    final start = previousEnd == null
        ? 0
        : (previousEnd + 1 < last ? previousEnd + 1 : last);
    return _SegmentDraft(start, start, 1);
  }

  /// 显式排序：按起始帧升序稳定排序，无法解析的段保持相对顺序排在末尾；
  /// 只重排文本槽位，不新建也不释放控制器。
  void _sortSegments() {
    if (_segments.length < 2) return;
    final starts = <int?>[
      for (final draft in _segments)
        int.tryParse(draft.startController.text.trim()),
    ];
    final order = List<int>.generate(_segments.length, (index) => index);
    order.sort((a, b) {
      final left = starts[a];
      final right = starts[b];
      if (left == null && right == null) return a.compareTo(b);
      if (left == null) return 1;
      if (right == null) return -1;
      final byStart = left.compareTo(right);
      return byStart != 0 ? byStart : a.compareTo(b);
    });
    final texts = <_SegmentTexts>[
      for (final index in order)
        (
          start: _segments[index].startController.text,
          end: _segments[index].endController.text,
          speed: _segments[index].speedController.text,
        ),
    ];
    for (var i = 0; i < _segments.length; i++) {
      _segments[i].setTexts(
        start: texts[i].start,
        end: texts[i].end,
        speed: texts[i].speed,
      );
    }
    setState(() {});
    final valid = _validMoving();
    if (valid != null) _emit(_latest.copyWith(moving: valid));
  }

  void _onSegmentEdited() {
    final valid = _validMoving();
    setState(() {});
    if (valid != null) _emit(_latest.copyWith(moving: valid));
  }

  /// 整段列表通过「单动画」校验时返回可提交值，否则返回 null。
  List<VideoPetLocomotion>? _validMoving() {
    if (_mode != _modeSegments) return null;
    final values = <VideoPetLocomotion>[];
    for (var i = 0; i < _segments.length; i++) {
      final parsed = _parseSegment(i);
      if (parsed.value == null) return null;
      values.add(parsed.value!);
    }
    if (values.isEmpty) return null;
    return List<VideoPetLocomotion>.unmodifiable(values);
  }

  /// 解析第 [index] 段文本（不依赖 VideoPetManifest，逐条给出原因）。
  _SegmentParse _parseSegment(int index) {
    final frameCount = _frameCount;
    if (frameCount == null) {
      return (value: null, error: _t('缺少 spritesheet，无法校验帧号', 'Missing spritesheet'));
    }
    _SegmentParse fail(String message) => (value: null, error: message);
    final draft = _segments[index];
    final startText = draft.startController.text.trim();
    final endText = draft.endController.text.trim();
    final speedText = draft.speedController.text.trim();
    if (startText.isEmpty) return fail(_t('请输入起始帧', 'Start frame is required'));
    final start = int.tryParse(startText);
    if (start == null) {
      return fail(_t('起始帧必须是整数', 'Start frame must be an integer'));
    }
    if (endText.isEmpty) return fail(_t('请输入结束帧', 'End frame is required'));
    final end = int.tryParse(endText);
    if (end == null) return fail(_t('结束帧必须是整数', 'End frame must be an integer'));
    if (speedText.isEmpty) return fail(_t('请输入速度', 'Speed is required'));
    if (!_speedPattern.hasMatch(speedText)) {
      return fail(_t('速度必须是正数数字', 'Speed must be a positive number'));
    }
    final speed = double.tryParse(speedText);
    if (speed == null || !speed.isFinite) {
      return fail(_t('速度必须是有限数字', 'Speed must be a finite number'));
    }
    if (start < 0 || start >= frameCount) {
      return fail(
        _t(
          '起始帧越界（合法范围 0..${frameCount - 1}）',
          'Start frame out of range (0..${frameCount - 1})',
        ),
      );
    }
    if (end < 0 || end >= frameCount) {
      return fail(
        _t(
          '结束帧越界（合法范围 0..${frameCount - 1}）',
          'End frame out of range (0..${frameCount - 1})',
        ),
      );
    }
    if (start > end) {
      return fail(_t('起始帧不能大于结束帧', 'Start frame must not exceed end frame'));
    }
    if (speed <= 0) return fail(_t('速度必须大于 0', 'Speed must be positive'));
    final previousEnd = index == 0
        ? null
        : int.tryParse(_segments[index - 1].endController.text.trim());
    if (previousEnd != null && start <= previousEnd) {
      return fail(
        _t('与上一段重叠（起始帧需大于上一段结束帧）', 'Overlaps the previous segment'),
      );
    }
    return (
      value: VideoPetLocomotion(startFrame: start, endFrame: end, speed: speed),
      error: null,
    );
  }

  static final RegExp _speedPattern = RegExp(r'^[+-]?\d+(\.\d+)?$');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dsTheme = DSThemeBridge.resolve(context);
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
            DropdownMenuItem<String>(value: '', child: Text(_t('未设置', 'Not set'))),
            DropdownMenuItem<String>(value: 'left', child: Text(_t('原始朝左', 'Facing left'))),
            DropdownMenuItem<String>(value: 'right', child: Text(_t('原始朝右', 'Facing right'))),
          ],
          onChanged: (value) => _setFacing(value ?? ''),
        ),
        const SizedBox(height: 8),
        Text(_frameInfo(), key: const ValueKey('videoPetFrameInfo'), style: theme.textTheme.bodySmall),
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
            DropdownMenuItem<String>(value: _modeDefault, child: Text(_t('默认连续移动', 'Default continuous movement'))),
            DropdownMenuItem<String>(value: _modeNone, enabled: spritesheet != null, child: Text(_t('全程不位移', 'No movement'))),
            DropdownMenuItem<String>(value: _modeSegments, enabled: spritesheet != null, child: Text(_t('分段移动', 'Moving segments'))),
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
          Row(
            children: <Widget>[
              if (spritesheet != null)
                DSIconButton(
                  key: const ValueKey('videoPetMovingAdd'),
                  icon: DsIconKind.plus,
                  size: 32,
                  color: dsTheme.surfaceAlt,
                  iconColor: dsTheme.textSub,
                  tooltip: _t('新增一段移动区间', 'Add a moving segment'),
                  onPressed: _addSegment,
                ),
              if (_segments.length >= 2)
                TextButton(
                  key: const ValueKey('videoPetMovingSort'),
                  onPressed: _sortSegments,
                  child: Text(_t('按起始帧排序', 'Sort by start frame')),
                ),
            ],
          ),
          for (var i = 0; i < _segments.length; i++)
            _buildSegmentRow(context, i),
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
      '帧数 ${spritesheet.frameCount} · 合法帧 0..$last · fps ${_formatNumber(spritesheet.fps)}',
      'frames ${spritesheet.frameCount} · valid frames 0..$last · fps ${_formatNumber(spritesheet.fps)}',
    );
  }

  Widget _buildSegmentRow(BuildContext context, int index) {
    final dsTheme = DSThemeBridge.resolve(context);
    final draft = _segments[index];
    final parsed = _parseSegment(index);
    final errorStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error);
    return Container(
      key: ValueKey('videoPetMovingSegment-$index'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _segmentField(
                  key: ValueKey('videoPetMovingStart-$index'),
                  controller: draft.startController,
                  label: _t('起始帧', 'Start'),
                  decimal: false,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _segmentField(
                  key: ValueKey('videoPetMovingEnd-$index'),
                  controller: draft.endController,
                  label: _t('结束帧', 'End'),
                  decimal: false,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _segmentField(
                  key: ValueKey('videoPetMovingSpeed-$index'),
                  controller: draft.speedController,
                  label: _t('速度（像素/帧）', 'Speed (px/frame)'),
                  decimal: true,
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
          if (parsed.error != null)
            Text(
              parsed.error!,
              key: ValueKey('videoPetMovingError-$index'),
              style: errorStyle,
            ),
        ],
      ),
    );
  }

  Widget _segmentField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required bool decimal,
  }) {
    return DSInput(
      key: key,
      controller: controller,
      hint: label,
      keyboardType: TextInputType.numberWithOptions(
        decimal: decimal,
        signed: decimal,
      ),
      onChanged: (_) => _onSegmentEdited(),
    );
  }
}

/// 一段移动区间三个输入框的文本快照，用于排序时交换槽位内容。
typedef _SegmentTexts = ({String start, String end, String speed});

/// 一段移动区间的输入草稿：控制器由本 widget 持有并负责释放。
class _SegmentDraft {
  _SegmentDraft(int start, int end, double speed)
    : startController = TextEditingController(text: '$start'),
      endController = TextEditingController(text: '$end'),
      speedController = TextEditingController(
        text: _VideoPetAnimationResourceEditorState._formatNumber(speed),
      );

  final TextEditingController startController;
  final TextEditingController endController;
  final TextEditingController speedController;

  void setTexts({
    required String start,
    required String end,
    required String speed,
  }) {
    startController.text = start;
    endController.text = end;
    speedController.text = speed;
  }

  void dispose() {
    startController.dispose();
    endController.dispose();
    speedController.dispose();
  }
}
