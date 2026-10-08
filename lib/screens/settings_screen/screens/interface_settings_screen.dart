import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/theme_controller.dart';
import 'package:aboutme/core/services/app_background_controller.dart';
import 'package:aboutme/core/services/ds_theme_color_controller.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/settings_screen/screens/theme_background_settings_screen.dart';
import '../controllers/settings_screen_controller.dart';
import '../widgets/settings_group.dart';

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

  /// 主题颜色选择：一排色板圆点，点击即全局切换
  Widget _buildPalettePicker() {
    final theme = DSThemeBridge.resolve(context);

    return ListenableBuilder(
      listenable: DsThemeColorController(),
      builder: (context, _) {
        final controller = DsThemeColorController();
        return Wrap(
          spacing: theme.spacing.lg,
          runSpacing: theme.spacing.md,
          children:
              DsThemePalettes.all.map((palette) {
                final selected = palette.id == controller.paletteId;
                return GestureDetector(
                  onTap: () => controller.setPalette(palette.id),
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
                          color: palette.primary,
                          border: Border.all(
                            color: selected ? palette.text : DsColors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: palette.background,
                            ),
                            child: selected
                                ? Icon(
                                    Icons.check,
                                    size: 16,
                                    color: palette.primary,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        palette.name,
                        style: DsTypography.caption.copyWith(
                          color: selected ? theme.text : theme.textSub,
                          fontWeight: selected ? FontWeight.w600 : null,
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
      appBar: AppBar(title: const Text('界面设置')),
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
                DSListItem(
                  title: 'settings_screen_languageTitle'.tr,
                  subtitle: 'settings_screen_languageSubtitle'.tr,
                  leading: const Icon(Icons.language, size: 22),
                  showChevron: true,
                  onTap: () => _controller.toggleLanguage(context),
                ),
                DSListItem(
                  title: 'settings_screen_darkModeTitle'.tr,
                  subtitle: 'settings_screen_darkModeSubtitle'.tr,
                  leading: const Icon(Icons.brightness_4, size: 22),
                  trailing: DSSwitch(
                    value: ThemeController.isDarkTheme(context),
                    onChanged: (value) => _controller.setTheme(context, value),
                  ),
                ),
                // 主题设置：全局背景图，应用于所有界面
                ListenableBuilder(
                  listenable: AppBackgroundController(),
                  builder: (context, _) {
                    return DSListItem(
                      title: 'screens_themeSettings'.tr,
                      subtitle:
                          AppBackgroundController().hasBackground
                              ? 'screens_backgroundImageSet'.tr
                              : AppBackgroundController().backgroundColor != null
                              ? 'screens_solidBackgroundSet'.tr
                              : 'screens_backgroundImageNotSet'.tr,
                      leading: const Icon(Icons.image, size: 22),
                      showChevron: true,
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
            // 主题颜色：色板圆点直接切换，全局即时生效
            SettingsGroup(
              title: '主题颜色',
              children: [_buildPalettePicker()],
            ),
          ],
        ),
      ),
    );
  }
}
