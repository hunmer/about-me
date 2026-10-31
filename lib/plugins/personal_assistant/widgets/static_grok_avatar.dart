import 'package:flutter/material.dart';
import 'package:grok_icon_study/grok_icon_study.dart';

/// 顶栏非活动 grokbot 图标的静态渲染。
///
/// 动态 [GrokCharacterView] 每帧全量自绘（Ticker + 弹簧 + 路径重建），
/// 顶栏 bot 数量多时会整体拖低帧率，令 dt 被钳制后所有弹簧动画
/// （转一圈/弹跳等）被慢放、真实时长变长。因此非活动图标静态化：
/// 仅在外观（身形/墨色/明暗）变化时重算一帧稳定 idle 画面。
class StaticGrokAvatar extends StatefulWidget {
  const StaticGrokAvatar({
    super.key,
    required this.shapeId,
    required this.colorId,
    required this.scheme,
    this.sizePx = 28,
  });

  final String shapeId;
  final String colorId;
  final String scheme;
  final double sizePx;

  @override
  State<StaticGrokAvatar> createState() => _StaticGrokAvatarState();
}

class _StaticGrokAvatarState extends State<StaticGrokAvatar> {
  late final GrokCharacter _character;
  GrokFrame? _frame;

  @override
  void initState() {
    super.initState();
    _character = GrokCharacter(
      mode: 'hold',
      state: 'idle',
      shapeName: widget.shapeId,
      colorId: widget.colorId,
    );
    _renderFrame();
  }

  @override
  void didUpdateWidget(StaticGrokAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shapeId != widget.shapeId ||
        oldWidget.colorId != widget.colorId ||
        oldWidget.scheme != widget.scheme) {
      _renderFrame();
      setState(() {});
    }
  }

  /// 预跑若干帧让眨眼/眼睛 morph 收敛到稳定 idle 姿态，
  /// 吸附弹簧后取一帧用于静态绘制（不再挂 Ticker）。
  void _renderFrame() {
    final character = _character;
    character.setColor(widget.colorId, widget.scheme);
    character.setShape(widget.shapeId);
    for (var i = 0; i < 24; i++) {
      character.tick(16 + i * 33);
    }
    character.snapPose();
    // setShape 会触发单圈旋转彩蛋（snapPose 不覆盖该弹簧），
    // 清掉后重取一帧，避免静态帧定格在半圈歪斜姿态
    character.spinTurn = null;
    character.trick = null;
    character.tick(16 + 24 * 33);
    _frame = character.frame;
  }

  @override
  void dispose() {
    _character.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;
    if (frame == null) {
      return SizedBox(width: widget.sizePx, height: widget.sizePx);
    }
    return RepaintBoundary(
      child: SizedBox(
        width: widget.sizePx,
        height: widget.sizePx,
        child: CustomPaint(
          painter: GrokCharacterPainter(
            frame: frame,
            fg: _character.foreground,
            eyeFill: _character.eyeFill,
            badgeColor: _character.badgeColor,
          ),
        ),
      ),
    );
  }
}
