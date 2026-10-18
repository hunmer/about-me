// 单动画播放调试页：选定一个状态持续播放，可切换身形/墨色、触发特技。
// 不包含多动画连续轮换（onboarding）界面。
import 'package:flutter/material.dart';

import 'src/grok_character.dart';
import 'src/grok_geometry.dart';
import 'src/grok_painter.dart';
import 'src/grok_tables.dart' as t;

class GrokStudyScreen extends StatefulWidget {
  const GrokStudyScreen({super.key});

  @override
  State<GrokStudyScreen> createState() => _GrokStudyScreenState();
}

class _GrokStudyScreenState extends State<GrokStudyScreen> {
  late final GrokCharacter bot;
  late final GrokCharacter bot64;
  String _state = 'curious';
  String _shape = 'blob';
  String _color = 'black';
  bool _follow = true;
  bool _emphasis = false;

  @override
  void initState() {
    super.initState();
    bot = GrokCharacter(
      mode: 'hold',
      state: _state,
      shapeName: _shape,
      colorId: _color,
      seed: 7,
    )..followPointer = _follow;
    bot64 = GrokCharacter(
      mode: 'hold',
      state: _state,
      shapeName: _shape,
      colorId: _color,
      seed: 8,
    );
    // 与源码 playground 一致：跳过首个 idle，从 curious 起播
    bot.setStateName('curious', resetEyes: true);
    bot64.setStateName('curious', resetEyes: true);
  }

  @override
  void dispose() {
    bot.dispose();
    bot64.dispose();
    super.dispose();
  }

  void _applyState(String name) {
    setState(() => _state = name);
    for (final b in [bot, bot64]) {
      b.setMode('hold');
      b.setStateName(name, resetEyes: false);
    }
  }

  void _applyShape(String id) {
    setState(() => _shape = id);
    for (final b in [bot, bot64]) {
      b.setShape(id);
    }
  }

  void _applyColor(String id) {
    setState(() => _color = id);
    for (final b in [bot, bot64]) {
      b.setColor(id, 'light');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Grok 角色动效')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Disk(child: GrokCharacterView(character: bot, pointerFollow: _follow)),
              const SizedBox(width: 24),
              Column(
                children: [
                  _Disk(
                    size: 96,
                    child: GrokCharacterView(character: bot64, sizePx: 64),
                  ),
                  const SizedBox(height: 6),
                  Text('登录 sizePx: 64', style: TextStyle(fontSize: 10, color: scheme.outline)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Readout(bot: bot),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('转一圈'),
                onPressed: () => [bot, bot64].forEach((b) => b.spinOnce(1)),
              ),
              ActionChip(
                label: const Text('跳一下'),
                onPressed: () => [bot, bot64].forEach((b) => b.bounceOnce()),
              ),
              ActionChip(
                label: const Text('粒子'),
                onPressed: () => [bot, bot64].forEach((b) => b.burstOnce()),
              ),
              FilterChip(
                label: const Text('跟随指针'),
                selected: _follow,
                onSelected: (v) {
                  setState(() => _follow = v);
                  bot.setFollowPointer(v);
                },
              ),
              FilterChip(
                label: const Text('emphasis'),
                selected: _emphasis,
                onSelected: (v) {
                  setState(() => _emphasis = v);
                  [bot, bot64].forEach((b) => b.setEmphasis(v));
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final group in t.grokGroups) ...[
            Text(
              '情绪状态 · ${group.label}',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                color: scheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in group.states)
                  ChoiceChip(
                    label: Text(name, style: const TextStyle(fontSize: 12)),
                    selected: _state == name,
                    onSelected: (_) => _applyState(name),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            '身形 · ${GrokGeometry.shapes.length} 种',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              color: scheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in GrokGeometry.shapes.entries)
                ChoiceChip(
                  label: Text(entry.value.label, style: const TextStyle(fontSize: 12)),
                  selected: _shape == entry.key,
                  onSelected: (_) => _applyShape(entry.key),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '墨色 · ${GrokGeometry.palette.length} 色',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              color: scheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in GrokGeometry.palette.entries)
                GestureDetector(
                  onTap: () => _applyColor(entry.key),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(entry.value.$1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == entry.key ? scheme.primary : Colors.black,
                        width: _color == entry.key ? 3 : 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '引擎按源码 $_t + 登录包装 sd() 移植：math / tables / pose / tricks / '
            'eyes / fx / character。64px 带 pose.scale ≈ 1.04；thinking / orbit / '
            'writing / loading 等会切 overlay；celebrate 会 spinWild；换身形走弹簧并轮换一记特技。',
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
        ],
      ),
    );
  }
}

const String _t = '\$_t';

class _Disk extends StatelessWidget {
  final Widget child;
  final double size;

  const _Disk({required this.child, this.size = 280});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFF3EFE6),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(width: size * 0.68, height: size * 0.68, child: child),
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  final GrokCharacter bot;

  const _Readout({required this.bot});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: bot,
      builder: (context, _) {
        final s = bot.snapshot();
        final style = const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(child: Text('状态  ${s.state}', style: style)),
              Expanded(child: Text('眼睛  ${s.eyeFrom} → ${s.eyeTo}', style: style)),
              Expanded(child: Text('旋转  ${s.spin.toStringAsFixed(2)}°', style: style)),
              Expanded(child: Text('挤压  ${s.squash.toStringAsFixed(3)}', style: style)),
              Expanded(child: Text('overlay  ${s.overlay ?? '—'}', style: style)),
            ],
          ),
        );
      },
    );
  }
}
