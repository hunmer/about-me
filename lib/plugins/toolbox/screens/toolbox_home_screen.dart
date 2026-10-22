import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/toolbox/screens/ai_image_screen.dart';
import 'package:aboutme/plugins/toolbox/screens/image_search_screen.dart';
import 'package:aboutme/widgets/photo_editor_home_screen.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 工具箱内的小工具条目
class ToolboxTool {
  final String id;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;

  const ToolboxTool({
    required this.id,
    required this.icon,
    required this.color,
    required this.builder,
  });
}

/// 工具箱主界面：小工具列表
class ToolboxHomeScreen extends StatelessWidget {
  const ToolboxHomeScreen({super.key});

  /// 小工具注册表（新增小工具在此追加）
  static final List<ToolboxTool> tools = [
    ToolboxTool(
      id: 'image_search',
      icon: Icons.image_search,
      color: const Color(0xFF6C9BD2),
      builder: (context) => const ImageSearchScreen(),
    ),
    ToolboxTool(
      id: 'ai_image',
      icon: Icons.auto_awesome,
      color: const Color(0xFFB98CD6),
      builder: (context) => const AiImageScreen(),
    ),
    ToolboxTool(
      id: 'photo_editor',
      icon: Icons.edit,
      color: const Color(0xFF6CBFA5),
      builder: (context) => const PhotoEditorHomeScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return SuperCupertinoNavigationWrapper(
      title: Text('toolbox_name'.tr),
      largeTitle: 'toolbox_name'.tr,
      enableLargeTitle: true,
      body: SafeArea(
        top: false,
        child: ListView.separated(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.lg,
            vertical: theme.spacing.sm,
          ),
          itemCount: tools.length,
          separatorBuilder: (_, _) => SizedBox(height: theme.spacing.sm),
          itemBuilder: (context, index) {
            final tool = tools[index];
            return DSCard(
              onTap: () =>
                  NavigationHelper.push(context, tool.builder(context)),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tool.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(tool.icon, color: tool.color),
                  ),
                  SizedBox(width: theme.spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'toolbox_${tool.id}_name'.tr,
                          style: DsTypography.title.copyWith(color: theme.text),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'toolbox_${tool.id}_desc'.tr,
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: theme.textSub),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
