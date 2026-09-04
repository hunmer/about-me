/// 快速添加任务小组件（1x1）
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';

/// 1x1 快速添加任务小组件
class QuickAddWidget extends StatelessWidget {
  const QuickAddWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    // Colors.blue / Icons.add_task 为插件注册身份色与标识图标，保留 Material
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToAddTask(context),
        child: SizedBox.expand(
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 图标在中间，标题在下边，图标右上角带加号 badge
                  Stack(
                    alignment: Alignment.topRight,
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.add_task, size: 40, color: Colors.blue),
                      // 图标右上角加号 badge
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.surface, width: 2),
                          ),
                          child: Icon(Icons.add, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'todo_quickAdd'.tr,
                    style: DsTypography.caption.copyWith(
                      color: theme.text,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 跳转到添加任务页面
  void _navigateToAddTask(BuildContext context) {
    NavigationHelper.pushNamed(
      context,
      '/todo',
      arguments: {'action': 'create'},
    );
  }
}
