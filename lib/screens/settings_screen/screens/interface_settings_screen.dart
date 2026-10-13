import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/theme_controller.dart';
import 'package:aboutme/core/services/app_background_controller.dart';
import 'package:aboutme/core/services/ds_ink_style_controller.dart';
import 'package:aboutme/core/services/ds_theme_color_controller.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/settings_screen/screens/theme_background_settings_screen.dart';
import '../controllers/settings_screen_controller.dart';
import '../widgets/settings_group.dart';
import '../widgets/settings_tile.dart';

/// 界面设置：语言、深色模式、主题背景
class InterfaceSettingsScreen extends StatefulWidget {
  const InterfaceSettingsScreen({super.key});

  @override
  State<InterfaceSettingsScreen> createState() =>
      _InterfaceSettingsScreenState();
}

class _InterfaceSettingsScreenState extends State<InterfaceSettingsScreen> {
  late SettingsScreenController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SettingsScreenController();
    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    await _controller.initializeControllers(context);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 完整主题选择：色板 × 墨线档位成套切换，点击即全局生效
  Widget _buildThemePicker() {
    final theme = DSThemeBridge.resolve(context);

    return ListenableBuilder(
      // 主题 = 配色 + 墨线，两个控制器合并监听选中态
      listenable: Listenable.merge([
        DsThemeColorController(),
        DsInkStyleController(),
      ]),
      builder: (context, _) {
        final paletteId = DsThemeColorController().paletteId;
        final inkIndex = DsInkStyle.index;
        return Wrap(
          spacing: theme.spacing.lg,
          runSpacing: theme.spacing.md,
          children:
              DsThemePresets.all.map((preset) {
                final selected =
                    preset.palette.id == paletteId &&
                    preset.inkIndex == inkIndex &&
                    preset.strokeWidth == DsInkStyle.strokeWidth;
                return GestureDetector(
                  onTap: () {
                    DsThemeColorController().setPalette(preset.palette.id);
                    DsInkStyleController()
                        .setStyle(preset.inkIndex, preset.strokeWidth);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 双层圆点：外圈主色、内芯背景色，直观预览主题观感
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: preset.palette.primary,
                          border: Border.all(
                            color: selected
                                ? preset.palette.text
                                : DsColors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: preset.palette.background,
                            ),
                            child: selected
                                ? Icon(
                                    Icons.check,
                                    size: 16,
                                    color: preset.palette.primary,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset.name,
                        style: DsTypography.caption.copyWith(
                          color: selected ? theme.text : theme.textSub,
                          fontWeight: selected ? FontWeight.w600 : null,
                        ),
                      ),
                      // 墨线档位标注：同配色不同墨线的主题以此区分
                      Text(
                        DsInkStyle.labels[preset.inkIndex],
                        style: DsTypography.caption.copyWith(
                          fontSize: 10,
                          color: theme.textSub,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isInitialized()) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text('settings_screen_interfaceSettings'.tr)),
      body: DSThemeBridge(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16.0,
            16.0,
            16.0,
            16.0 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.language,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'settings_screen_languageTitle'.tr,
                  subtitle: 'settings_screen_languageSubtitle'.tr,
                  onTap: () => _controller.toggleLanguage(context),
                ),
                SettingsTile(
                  icon: Icons.brightness_4,
                  iconColor: const Color(0xFF6366F1),
                  title: 'settings_screen_darkModeTitle'.tr,
                  subtitle: 'settings_screen_darkModeSubtitle'.tr,
                  showChevron: false,
                  trailing: DSSwitch(
                    value: ThemeController.isDarkTheme(context),
                    onChanged: (value) => _controller.setTheme(context, value),
                  ),
                ),
                // 主题设置：全局背景图，应用于所有界面
                ListenableBuilder(
                  listenable: AppBackgroundController(),
                  builder: (context, _) {
                    return SettingsTile(
                      icon: Icons.image,
                      iconColor: const Color(0xFF10B981),
                      title: 'screens_themeSettings'.tr,
                      subtitle:
                          AppBackgroundController().hasBackground
                              ? 'screens_backgroundImageSet'.tr
                              : AppBackgroundController().backgroundColor != null
                              ? 'screens_solidBackgroundSet'.tr
                              : 'screens_backgroundImageNotSet'.tr,
                      onTap: () {
                        NavigationHelper.push(
                          context,
                          const ThemeBackgroundSettingsScreen(),
                          routeName: '/settings/theme_background',
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 完整主题：配色 × 墨线成套选择，点击全局即时生效
            SettingsGroup(
              title: '主题',
              children: [_buildThemePicker()],
            ),
          ],
        ),
      ),
    );
  }
}
