import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/day/controllers/day_controller.dart';
import 'package:aboutme/plugins/day/models/memorial_day.dart';
import 'package:aboutme/plugins/day/widgets/memorial_background.dart';
import 'package:aboutme/plugins/day/widgets/edit_memorial_day_dialog/edit_memorial_day_page.dart';

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
      day.copyWith(notes: [...day.notes, text]),
    );
  }

  void _deleteNote(DayController controller, int index) {
    final day = _currentDay(controller);
    final notes = [...day.notes]..removeAt(index);
    controller.updateMemorialDay(day.copyWith(notes: notes));
  }

  void _showNoteMenu(DayController controller, int index) {
    showDSBottomSheet(
      context: context,
      title: 'day_note'.tr,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DSSheetAction(
            icon: DsIconKind.trash,
            label: 'day_deleteMemorialDay'.tr,
            destructive: true,
            onTap: () {
              Navigator.pop(sheetContext);
              _deleteNote(controller, index);
            },
          ),
        ],
      ),
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
                  backgroundColor: theme.background,
                  body: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        _buildHeader(context, theme, controller, day),
                        // 骑缝加号：弧最低点凸出 36，按钮中心对齐它
                        Transform.translate(
                          offset: const Offset(0, 8),
                          child: _buildAddButton(theme, controller, day),
                        ),
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

  /// 弧线凸出深度：header 底边中央向下的弧形高度
  static const double _arcDepth = 36;

  Widget _buildHeader(
    BuildContext context,
    AppThemeData theme,
    DayController controller,
    MemorialDay day,
  ) {
    final accent = day.backgroundColor;
    final imageUrl = day.backgroundImageUrl;
    // 大圆直径取 2 倍屏宽：弧线平缓，两端自然延伸到屏幕边缘
    final screenW = MediaQuery.sizeOf(context).width;
    final circleD = screenW * 2;

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
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 52),
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
              const SizedBox(height: 28),
              // 大数字行：图标 + 天数 + 单位
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  WiredIcon(
                    icon: day.icon ?? Icons.favorite_border,
                    size: 38,
                    color: theme.text,
                    drawConfig: theme.wired.drawConfig,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatCount(
                      day.isExpired ? day.daysPassed : day.daysRemaining,
                    ),
                    style: DsTypography.display.copyWith(
                      fontSize: 52,
                      color: theme.text,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    day.isExpired || day.isToday
                        ? 'day_unitDays'.tr
                        : 'day_unitDaysAfter'.tr,
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // 胶囊 badges：目标日期 + 笔记数
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _buildHeaderBadge(theme, _dotDate(day.targetDate)),
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
        // 底部下凸弧线：只露出大圆最下方的 [_arcDepth] 高度带，
        // rough 墨线沿圆周走，弧线两端自然接在 header 底边
        Positioned(
          left: 0,
          right: 0,
          bottom: -_arcDepth,
          child: SizedBox(
            height: _arcDepth,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.bottomCenter,
                maxWidth: circleD,
                maxHeight: circleD,
                child: Container(
                  width: circleD,
                  height: circleD,
                  decoration: dsSketchDecoration(
                    theme: theme,
                    fillColor: accent,
                    circle: true,
                    seed: 2,
                  ),
                ),
              ),
            ),
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
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

    return Pressable(
      onLongPress: () => _showNoteMenu(controller, index),
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
    );
  }

  String _dotDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}.${two(d.month)}.${two(d.day)}';
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
