// girl.riv 是纯「状态机输入」文件（无数据绑定视图模型），
// SM inputs 是官方运行时控制它的唯一接口，忽略其 deprecated 提示。
// ignore_for_file: deprecated_member_use

import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:rive/rive.dart';

/// 果冻小屋角色：girl.riv 虚拟形象（画板 child / 状态机 State Machine 1）
///
/// 尺寸按百分比缩放：宽度 = 可用宽度 × [widthFactor]（[maxWidth] 封顶），
/// 高度 = 宽度 × [heightRatio]，且不超过 [availableHeight] × [heightFactor]
/// （[maxHeight] 封顶）——防止角色过高把下方卡片挤出视口。
///
/// 长按（触屏）或右键（桌面）弹出状态列表，点击切换角色状态：
/// - 动作（触发器）：点击触发一次，如跳跃、胜利、换装
/// - 开关（布尔）：点击开/关，如显示上衣、居家模式
/// - 数值（数字）：点击循环 +1，如表情、瞳色、坐姿
/// 列表按状态机输入动态生成，命名见 [_entryLabels]。
class JellyRiveCharacter extends StatefulWidget {
  const JellyRiveCharacter({
    super.key,
    this.widthFactor = 1.0,
    this.heightFactor = 0.38,
    this.maxWidth = 480,
    this.maxHeight = 440,
    this.heightRatio = 1.13,
    this.availableHeight,
  });

  /// 宽度占父级可用宽度的比例（0~1）
  final double widthFactor;

  /// 高度预算占可用高度（视口）的比例（0~1）
  final double heightFactor;

  /// 宽度上限（桌面宽窗口下防止角色无限放大）
  final double maxWidth;

  /// 高度上限
  final double maxHeight;

  /// 高度 = 宽度 × 该比例
  final double heightRatio;

  /// 可用高度（视口高）。组件在滚动视图里自身高度约束无界，需从外部传入；
  /// 为 null 时只按宽度规则缩放。
  final double? availableHeight;

  @override
  State<JellyRiveCharacter> createState() => _JellyRiveCharacterState();
}

/// 状态机输入 → 中文标签（未知输入回退显示原始名）
const Map<String, String> _entryLabels = {
  'starAct_Touch': '星星互动',
  'Act_Touch': '摸摸头',
  'Act_1': '互动动作',
  'win': '胜利',
  'jump': '跳跃',
  'back_in': '背饰',
  'Handobject_in': '手持物',
  'necklace_in': '项链',
  'earring_in': '耳饰',
  'hair_in': '发型',
  'glass_in': '眼镜',
  'shoes_in': '鞋子',
  'skirt_in': '裙子',
  'pants_in': '裤子',
  'top_in': '上衣',
  'hat_in': '帽子',
  'jumpright_check': '朝右跳',
  'home': '居家模式',
  'flower_check': '花环',
  'top_check': '显示上衣',
  'bottoms_check': '显示下装',
  'skirt_check': '显示裙子',
  'stateaction': '动作状态',
  'flower_state': '花朵',
  'sit': '坐姿',
  'eye_color': '瞳色',
  'face': '表情',
  'skin_color': '肤色',
};

/// 数值输入的循环上限（依据 girl.riv 内动画命名推得：
/// sit=默认站+1~6号位坐姿、face=五官0~7、eye_color=eye 0~11、
/// skin_color=sk0~sk4、flower_state=花0~7）
const Map<String, int> _numberMax = {
  'stateaction': 2,
  'flower_state': 7,
  'sit': 6,
  'eye_color': 11,
  'face': 7,
  'skin_color': 4,
};

enum _EntryKind { action, toggle, value }

class _SmEntry {
  const _SmEntry(this.input, this.kind, this.max);

  final Input input;
  final _EntryKind kind;

  /// 仅 value 用：循环上限
  final int max;

  String get label => _entryLabels[input.name] ?? input.name;
}

class _JellyRiveCharacterState extends State<JellyRiveCharacter> {
  File? _file;
  RiveWidgetController? _controller;
  List<_SmEntry> _entries = const [];
  OverlayEntry? _menu;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _closeMenu();
    for (final entry in _entries) {
      entry.input.dispose();
    }
    _controller?.dispose();
    _file?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final file = await File.asset(
      'assets/animations/girl.riv',
      riveFactory: Factory.flutter,
    );
    if (!mounted) {
      file?.dispose();
      return;
    }
    if (file == null) return; // 加载失败保持占位

    final controller = RiveWidgetController(
      file,
      stateMachineSelector: StateMachineSelector.byName('State Machine 1'),
    );
    final entries = <_SmEntry>[];
    final sm = controller.stateMachine;
    for (var i = 0;; i++) {
      final input = sm.inputAt(i);
      if (input == null) break;
      final kind = switch (input) {
        NumberInput() => _EntryKind.value,
        BooleanInput() => _EntryKind.toggle,
        TriggerInput() => _EntryKind.action,
        _ => null,
      };
      if (kind == null) continue;
      entries.add(_SmEntry(input, kind, _numberMax[input.name] ?? 2));
    }

    setState(() {
      _file = file;
      _controller = controller;
      _entries = entries;
    });
  }

  // ── 状态菜单 ──────────────────────────────────────────────

  void _openMenu(Offset globalPosition) {
    if (_entries.isEmpty || _menu != null) return;
    final overlay =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()
            as RenderBox;
    final theme = AppTheme.of(context);

    // 菜单锚点：指针位置，靠边时收回视口内（窗口过小时钉在 8px）
    const menuWidth = 208.0;
    const menuMaxHeight = 420.0;
    final anchor = overlay.globalToLocal(globalPosition);
    final maxLeft = (overlay.size.width - menuWidth - 8).clamp(8.0, double.infinity);
    final maxTop =
        (overlay.size.height - menuMaxHeight - 8).clamp(8.0, double.infinity);
    final left = anchor.dx.clamp(8.0, maxLeft);
    final top = anchor.dy.clamp(8.0, maxTop);

    _menu = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // 外部点击关闭
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeMenu,
              onSecondaryTap: _closeMenu,
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: AppTheme(
              data: theme,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.9, end: 1),
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutBack,
                builder: (context, t, child) => Opacity(
                  opacity: t.clamp(0, 1),
                  child: Transform.scale(
                    scale: t,
                    alignment: Alignment.topLeft,
                    child: child,
                  ),
                ),
                child: _buildMenuCard(),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_menu!);
  }

  void _closeMenu() {
    _menu?.remove();
    _menu = null;
  }

  Widget _buildMenuCard() {
    final theme = AppTheme.of(context);
    final sections = <_EntryKind, List<_SmEntry>>{};
    for (final entry in _entries) {
      sections.putIfAbsent(entry.kind, () => []).add(entry);
    }

    return Container(
      width: 208,
      constraints: const BoxConstraints(maxHeight: 420),
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: theme.radii.lg,
        border: Border.all(color: theme.stroke, width: 1.4),
        boxShadow: theme.shadows.float,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final kind in _EntryKind.values)
              if (sections[kind]?.isNotEmpty == true) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: theme.spacing.md)
                      .add(EdgeInsets.only(top: theme.spacing.xs)),
                  child: Text(
                    switch (kind) {
                      _EntryKind.action => '动作（点击触发）',
                      _EntryKind.toggle => '开关',
                      _EntryKind.value => '数值（点击切换）',
                    },
                    style: DsTypography.caption.copyWith(
                      color: theme.textSub,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final entry in sections[kind]!)
                  _buildMenuRow(theme, entry),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuRow(AppThemeData theme, _SmEntry entry) {
    Widget trailing;
    switch (entry.kind) {
      case _EntryKind.action:
        trailing = DsIcon(
          DsIconKind.chevronRight,
          size: 13,
          color: theme.textSub,
        );
      case _EntryKind.toggle:
        final on = (entry.input as BooleanInput).value;
        trailing = on
            ? DsIcon(DsIconKind.check, size: 13, color: theme.success)
            : Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.textSub.withValues(alpha: 0.5),
                    width: 1.6,
                  ),
                ),
              );
      case _EntryKind.value:
        trailing = Text(
          '${(entry.input as NumberInput).value.round()}',
          style: DsTypography.caption.copyWith(
            color: theme.primary,
            fontWeight: FontWeight.w600,
          ),
        );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _activate(entry),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: 7,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.label,
                style: DsTypography.body.copyWith(
                  fontSize: 13,
                  color: theme.text,
                ),
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            trailing,
          ],
        ),
      ),
    );
  }

  void _activate(_SmEntry entry) {
    switch (entry.kind) {
      case _EntryKind.action:
        (entry.input as TriggerInput).fire();
        _closeMenu(); // 动作触发后收起菜单，让用户看到表演
      case _EntryKind.toggle:
        final input = entry.input as BooleanInput;
        input.value = !input.value;
        _menu?.markNeedsBuild();
      case _EntryKind.value:
        final input = entry.input as NumberInput;
        input.value = (input.value + 1) % (entry.max + 1);
        _menu?.markNeedsBuild();
    }
  }

  // ── 渲染 ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final controller = _controller;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 宽度按可用宽度百分比缩放，再与视口高度预算取小，避免挤掉下方卡片
        final byWidth = (constraints.maxWidth * widget.widthFactor)
            .clamp(120.0, widget.maxWidth);
        var height = byWidth * widget.heightRatio;
        final budget = widget.availableHeight;
        if (budget != null && budget.isFinite) {
          height = height.clamp(0.0, budget * widget.heightFactor);
        }
        height = height.clamp(160.0, widget.maxHeight);
        final width = height / widget.heightRatio;

        return SizedBox(
          width: width,
          height: height,
          child: controller == null
              // 加载中/失败兜底：浅色圆斑占位
              ? Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.surface.withValues(alpha: 0.55),
                        border: Border.all(color: theme.stroke, width: 2),
                      ),
                    ),
                  ),
                )
              : GestureDetector(
                  // 长按（触屏）/ 右键（桌面）弹出状态列表
                  onLongPressStart: (d) => _openMenu(d.globalPosition),
                  onSecondaryTapDown: (d) => _openMenu(d.globalPosition),
                  child: RiveWidget(
                    controller: controller,
                    fit: Fit.contain,
                  ),
                ),
        );
      },
    );
  }
}
