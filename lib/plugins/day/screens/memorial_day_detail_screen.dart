import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/widgets/arc_context_menu.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/swipe_action/swipe_action_wrapper.dart';
import 'package:aboutme/plugins/day/controllers/day_controller.dart';
import 'package:aboutme/plugins/day/models/memorial_day.dart';
import 'package:aboutme/plugins/day/widgets/memorial_background.dart';
import 'package:aboutme/plugins/day/widgets/day_memorial_form/edit_memorial_day_page.dart';

/// 纪念日详情页（Warm Paper Sketch · 复刻参考图 UI）
///
/// 布局：accent 色弧底 header（返回/标题/编辑 + 图标大数字 + 胶囊 badge）
/// + 骑缝圆形加号 + 下方笔记列表（序号方块 + 文本 + 彩色圆底图标）。
/// 加号弹出新增笔记对话框；长按笔记行可删除。
class MemorialDayDetailScreen extends StatefulWidget {
  const MemorialDayDetailScreen({
    super.key,
    required this.memorialDay,
    required this.controller,
  });

  /// 初始纪念日对象（仅取 id，展示时始终从 controller 取最新数据）
  final MemorialDay memorialDay;
  final DayController controller;

  @override
  State<MemorialDayDetailScreen> createState() =>
      _MemorialDayDetailScreenState();
}

class _MemorialDayDetailScreenState extends State<MemorialDayDetailScreen> {
  final _noteController = TextEditingController();
  final _noteFocus = FocusNode();

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  /// 当前纪念日最新数据（编辑/增删笔记后对象会被替换）
  MemorialDay _currentDay(DayController controller) {
    try {
      return controller.memorialDays.firstWhere(
        (d) => d.id == widget.memorialDay.id,
      );
    } catch (_) {
      return widget.memorialDay;
    }
  }

  Future<void> _openEditor(MemorialDay day) async {
    final result = await NavigationHelper.push<DialogResult>(
      context,
      EditMemorialDayPage(memorialDay: day),
    );
    if (result == null || !mounted) return;

    switch (result.action) {
      case DialogAction.save:
        if (result.memorialDay != null) {
          await widget.controller.updateMemorialDay(result.memorialDay!);
        }
        break;
      case DialogAction.delete:
        await widget.controller.deleteMemorialDay(day.id);
        if (mounted) Navigator.of(context).pop();
        break;
      case DialogAction.cancel:
        break;
    }
  }

  void _showEditNoteDialog(int index) {
    final day = _currentDay(widget.controller);
    _noteController.text = day.notes[index];
    showDSDialog(
      context: context,
      builder: (dialogContext) => DSDialog(
        title: 'day_editNote'.tr,
        content: DSInput(
          controller: _noteController,
          hint: 'day_enterNote'.tr,
          maxLines: 3,
          minLines: 1,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitNoteEdit(dialogContext, index),
        ),
        confirmText: 'day_save'.tr,
        cancelText: 'day_cancel'.tr,
        onConfirm: () => _submitNoteEdit(dialogContext, index),
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _submitNoteEdit(BuildContext dialogContext, int index) {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;
    Navigator.of(dialogContext).pop();
    final day = _currentDay(widget.controller);
    final notes = [...day.notes];
    // 编辑只改文本，保留原创建时间
    notes[index] = text;
    widget.controller.updateMemorialDay(day.copyWith(notes: notes));
  }

  void _showAddNoteDialog() {
    _noteController.clear();
    showDSDialog(
      context: context,
      builder: (dialogContext) => DSDialog(
        title: 'day_addNote'.tr,
        content: DSInput(
          controller: _noteController,
          focusNode: _noteFocus,
          hint: 'day_enterNote'.tr,
          maxLines: 3,
          minLines: 1,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitNote(dialogContext),
        ),
        confirmText: 'day_save'.tr,
        cancelText: 'day_cancel'.tr,
        onConfirm: () => _submitNote(dialogContext),
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
    // 对话框弹出后聚焦输入框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _noteFocus.requestFocus();
    });
  }

  void _submitNote(BuildContext dialogContext) {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;
    Navigator.of(dialogContext).pop();
    final day = _currentDay(widget.controller);
    widget.controller.updateMemorialDay(
      day.copyWith(
        notes: [...day.notes, text],
        noteDates: [...day.noteDates, DateTime.now()],
      ),
    );
  }

  void _deleteNote(DayController controller, int index) {
    final day = _currentDay(controller);
    final notes = [...day.notes]..removeAt(index);
    // 旧数据 noteDates 可能短于 notes，越界时保持不动
    final noteDates = [...day.noteDates];
    if (index < noteDates.length) noteDates.removeAt(index);
    controller.updateMemorialDay(
      day.copyWith(notes: notes, noteDates: noteDates),
    );
  }

  /// 长按快捷菜单项（圆盘与底部 sheet 共用）
  List<ArcMenuItem> _noteActions(DayController controller, int index) => [
        ArcMenuItem(
          icon: DsIconKind.trash,
          label: 'day_deleteMemorialDay'.tr,
          destructive: true,
          onTap: () => _deleteNote(controller, index),
        ),
      ];

  void _showNoteMenu(DayController controller, int index) {
    SmoothBottomSheet.showActionList(
      context: context,
      title: 'day_note'.tr,
      actions: _noteActions(controller, index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.controller,
      child: Consumer<DayController>(
        builder: (context, controller, child) {
          final day = _currentDay(controller);
          // 纪念日已被删除（编辑页删除路径兜底）：自动返回
          final exists = controller.memorialDays.any(
            (d) => d.id == widget.memorialDay.id,
          );
          if (!exists) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            });
          }

          return DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return Scaffold(
                  backgroundColor: dsScaffoldBackground(theme),
                  body: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        _buildHeader(context, theme, controller, day),
                        Expanded(
                          child: _buildNotesSection(theme, controller, day),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // ==================== Header（参考图 1 弧底色块） ====================

  /// 内容区弧形拱起的高度：拱顶高出 header 底边的距离
  static const double _arcDepth = 36;

  Widget _buildHeader(
    BuildContext context,
    AppThemeData theme,
    DayController controller,
    MemorialDay day,
  ) {
    final accent = day.backgroundColor;
    final imageUrl = day.backgroundImageUrl;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 背景组：accent 底 + 背景图片（含纸色遮罩保证文字可读）
        Positioned.fill(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: accent),
              if (imageUrl != null)
                MemorialBackgroundImage(imageUrl: imageUrl, dimAlpha: 0.45),
            ],
          ),
        ),
        // 主块墨线框（叠在背景图之上）
        Positioned.fill(
          child: IgnorePointer(child: SketchStrokeOverlay(theme: theme)),
        ),
        // 内容
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 72),
          child: Column(
            children: [
              // 顶行：返回 / 标题 / 编辑
              Row(
                children: [
                  _HeaderCircleButton(
                    theme: theme,
                    icon: DsIconKind.chevronLeft,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      day.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                  ),
                  _HeaderCircleButton(
                    theme: theme,
                    icon: DsIconKind.edit,
                    onTap: () => _openEditor(day),
                  ),
                ],
              ),
              const SizedBox(height: 44),
              // 大数字行：图标 + 天数 + 单位
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  WiredIcon(
                    icon: day.icon ?? Icons.favorite_border,
                    size: 44,
                    color: theme.text,
                    drawConfig: theme.wired.drawConfig,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    _formatCount(
                      day.isExpired ? day.daysPassed : day.daysRemaining,
                    ),
                    style: DsTypography.display.copyWith(
                      fontSize: 64,
                      color: theme.text,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    day.isExpired || day.isToday
                        ? 'day_unitDays'.tr
                        : 'day_unitDaysAfter'.tr,
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              // 胶囊 badges：目标日期 + 循环 + 笔记数
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _buildHeaderBadge(theme, _dotDate(day.effectiveTargetDate)),
                  if (day.recurrenceSummary != null)
                    _buildHeaderBadge(theme, '🔁 ${day.recurrenceSummary}'),
                  _buildHeaderBadge(
                    theme,
                    'day_notesCount'.trParams({
                      'count': day.notes.length.toString(),
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 内容区弧形拱起：应用背景色向上拱的全宽弧线（参考图 1），
        // 盖在 header 底边上（拱顶高出底边 [_arcDepth]，两端到 corner）
        // 颜色与内容区实际背景保持一致：全局背景生效时 Scaffold 透明，
        // 弧线用全局背景底色，避免连接处出现色差
        Positioned(
          left: 0,
          right: 0,
          bottom: -1,
          child: SizedBox(
            height: _arcDepth + 1,
            child: CustomPaint(
              painter: _ArcHeaderPainter(
                dsScaffoldBackground(theme).alpha == 0
                    ? globalBackdropColor(context)
                    : theme.background,
              ),
            ),
          ),
        ),
        // 骑缝加号：中心对齐弧线顶点
        Positioned(
          left: 0,
          right: 0,
          bottom: 9,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _buildAddButton(theme, controller, day),
          ),
        ),
      ],
    );
  }

  /// header 胶囊 badge：纸底贴纸 + 墨字
  Widget _buildHeaderBadge(AppThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surface,
        radius: theme.radii.pill,
        strokeWidth: 1.4,
        seed: 7,
      ),
      child: Text(
        label,
        style: DsTypography.label.copyWith(color: theme.text),
      ),
    );
  }

  /// 骑缝加号：深墨圆 + 纸色加号，弹新增笔记对话框
  Widget _buildAddButton(AppThemeData theme, DayController controller, MemorialDay day) {
    return Pressable(
      onPressed: _showAddNoteDialog,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Transform.scale(
          scale: pressed ? 0.94 : 1.0,
          child: Container(
            width: 56,
            height: 56,
            decoration: dsSketchDecoration(
              theme: theme,
              fillColor: theme.ink,
              circle: true,
              seed: 11,
            ),
            child: Center(
              child: DsIcon(
                DsIconKind.plus,
                size: 26,
                color: theme.surface,
              ),
            ),
          ),
        );
      },
    );
  }

  // ==================== 笔记列表（参考图 2 行样式） ====================

  Widget _buildNotesSection(
    AppThemeData theme,
    DayController controller,
    MemorialDay day,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // 顶部留出与弧线的缓冲，避免内容贴到弧线连接处
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 10),
          child: Text(
            '${'day_notes'.tr} (${day.notes.length})',
            style: DsTypography.heading.copyWith(color: theme.text),
          ),
        ),
        Expanded(
          child:
              day.notes.isEmpty
                  ? Center(
                    child: Text(
                      'day_noNotesYet'.tr,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  )
                  : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      MediaQuery.paddingOf(context).bottom + 24,
                    ),
                    itemCount: day.notes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _buildNoteRow(
                      theme,
                      controller,
                      day,
                      index,
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildNoteRow(
    AppThemeData theme,
    DayController controller,
    MemorialDay day,
    int index,
  ) {
    final accent = day.backgroundColor;
    final seed = index + 1;

    return SwipeActionWrapper(
      key: ValueKey('note_swipe_${day.id}_$index'),
      // 左滑（右侧滑出）：编辑
      trailingActions: [
        SwipeActionOption(
          label: 'day_editNote'.tr,
          icon: Icons.edit,
          backgroundColor: theme.primary,
          textColor: theme.onPrimary,
          onTap: () => _showEditNoteDialog(index),
        ),
      ],
      // 右滑（左侧滑出）：删除（滑到底弹确认）
      leadingActions: [
        SwipeActionOption(
          label: 'day_delete'.tr,
          icon: Icons.delete,
          backgroundColor: theme.danger,
          textColor: theme.onDanger,
          isDestructive: true,
          onTap: () => _deleteNote(controller, index),
        ),
      ],
      deleteConfirmContent: 'day_deleteNoteConfirm'.tr,
      // 长按弹圆盘快捷菜单（删除）
      child: ArcContextMenu.actions(
        actions: _noteActions(controller, index),
        showMore: () => _showNoteMenu(controller, index),
        child: Pressable(
        builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Transform.translate(
          offset: pressed ? const Offset(1, 1) : Offset.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: dsSketchDecoration(
              theme: theme,
              fillColor: theme.surface,
              radius: BorderRadius.circular(14),
              seed: seed + 40,
            ),
            child: Row(
              children: [
                // 序号方块（参考图日期块位置）
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: dsSketchDecoration(
                    theme: theme,
                    fillColor: theme.surfaceAlt,
                    radius: BorderRadius.circular(10),
                    strokeWidth: 1.4,
                    seed: seed + 80,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No.',
                        style: DsTypography.label.copyWith(
                          fontSize: 9,
                          color: theme.textSub,
                        ),
                      ),
                      Text(
                        '${index + 1}',
                        style: DsTypography.heading.copyWith(
                          color: theme.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    day.notes[index],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                ),
                const SizedBox(width: 8),
                // 创建日期（旧数据无时间戳时省略）
                if (index < day.noteDates.length &&
                    day.noteDates[index] != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      _shortDate(day.noteDates[index]!),
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ),
                // 彩色圆底图标（参考图表情位）
                Container(
                  width: 30,
                  height: 30,
                  decoration: dsSketchDecoration(
                    theme: theme,
                    fillColor: accent.withValues(alpha: 0.55),
                    circle: true,
                    strokeWidth: 1.4,
                    seed: seed + 120,
                  ),
                  child: Center(
                    child: DsIcon(
                      DsIconKind.mood,
                      size: 17,
                      color: theme.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
        ),
      ),
    );
  }

  String _dotDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}.${two(d.month)}.${two(d.day)}';
  }

  /// 笔记日期短格式：同年 MM.dd，跨年 yyyy.MM.dd
  String _shortDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    return d.year == now.year
        ? '${two(d.month)}.${two(d.day)}'
        : '${d.year}.${two(d.month)}.${two(d.day)}';
  }

  /// 千分位：1314 → 1,314
  static String _formatCount(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final rem = s.length - i;
      if (rem > 1 && rem % 3 == 1) buf.write(',');
    }
    return n < 0 ? '-$buf' : buf.toString();
  }
}

/// 内容区顶部弧形：应用背景色、向上拱起的贝塞尔弧，铺满全宽
class _ArcHeaderPainter extends CustomPainter {
  _ArcHeaderPainter(this.fillColor);

  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    // 二次贝塞尔控制点取 -(高度)：拱顶正好落在矩形顶边，两端落在底边
    final path = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(
        size.width / 2,
        -size.height,
        size.width,
        size.height,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = fillColor);
  }

  @override
  bool shouldRepaint(covariant _ArcHeaderPainter old) =>
      old.fillColor != fillColor;
}

/// header 顶行圆形按钮：纸色圆底 + 墨色图标
class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.theme,
    required this.icon,
    this.onTap,
  });

  final AppThemeData theme;
  final DsIconKind icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Transform.scale(
          scale: pressed ? 0.92 : 1.0,
          child: Container(
            width: 38,
            height: 38,
            decoration: dsSketchDecoration(
              theme: theme,
              fillColor: theme.surface,
              circle: true,
              strokeWidth: 1.4,
              seed: 5,
            ),
            child: Center(
              child: DsIcon(icon, size: 18, color: theme.text),
            ),
          ),
        );
      },
    );
  }
}
