import 'package:flutter/material.dart';
import 'package:grok_icon_study/grok_icon_study.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/personal_assistant/services/grok_bot_instance_service.dart';

/// 首页角色右上角设置弹层：选择当前活动实例的身形/墨色，
/// 即时应用到各角色并持久化到实例配置（GrokBotInstanceService.updateStyle）；
/// 从 [PersonalAssistantScreen] 按功能拆出，仅做视图装配
void showBotStyleSheet(
  BuildContext context, {
  required GrokBotInstanceService botService,
  required GrokBotInstance bot,
}) {
  final theme = DSThemeBridge.resolve(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: theme.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (sheetContext) {
      final sheetTheme = DSThemeBridge.resolve(sheetContext);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          child: AnimatedBuilder(
            animation: botService,
            builder: (context, _) {
              // updateStyle 会替换实例对象，读列表取最新值
              GrokBotInstance selected = bot;
              for (final item in botService.bots) {
                if (item.id == bot.id) selected = item;
              }
              final selectedShape = selected.shapeId;
              final selectedColor = selected.colorId;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: sheetTheme.textSub.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '角色外观',
                      style: DsTypography.title.copyWith(
                        color: sheetTheme.text,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '外形',
                      style: DsTypography.caption.copyWith(
                        color: sheetTheme.textSub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in GrokGeometry.shapes.entries)
                          _SheetShapeChip(
                            sheetTheme,
                            label: entry.value.label,
                            selected: entry.key == selectedShape,
                            onTap: () => botService.updateStyle(
                              bot.id,
                              shapeId: entry.key,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '颜色',
                      style: DsTypography.caption.copyWith(
                        color: sheetTheme.textSub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final entry in GrokGeometry.palette.entries)
                          _SheetColorDot(
                            sheetTheme,
                            colorValue: entry.value.$1,
                            selected: entry.key == selectedColor,
                            onTap: () => botService.updateStyle(
                              bot.id,
                              colorId: entry.key,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

/// 身形选择胶囊：选中以主题色填充
class _SheetShapeChip extends StatelessWidget {
  const _SheetShapeChip(
    this.theme, {
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppThemeData theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: selected ? theme.primary : theme.surface,
          radius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: DsTypography.caption.copyWith(
            color: selected ? theme.onPrimary : theme.textSub,
          ),
        ),
      ),
    );
  }
}

/// 墨色选择圆点：选中以主题色加粗描边
class _SheetColorDot extends StatelessWidget {
  const _SheetColorDot(
    this.theme, {
    required this.colorValue,
    required this.selected,
    required this.onTap,
  });

  final AppThemeData theme;
  final int colorValue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Color(colorValue),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? theme.primary : theme.textSub,
            width: selected ? 3 : 1.5,
          ),
        ),
      ),
    );
  }
}
