import 'dart:io';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';

/// 通用聊天屏幕壳
///
/// 从 chat 插件的 ChatScreen 中提取的可复用布局：
/// - 背景图层（可选，支持背景图 + 半透明遮罩）
/// - SuperCupertinoNavigationWrapper 导航壳（标题/搜索/过滤/actions）
/// - body 内容插槽（消息列表 + 输入区由使用方自行组装）
///
/// chat 插件与 agent_chat 插件共用此壳，保证两处聊天页外观一致。
class ChatScreenScaffold extends StatelessWidget {
  /// 导航栏标题（可点击/富文本由使用方自行包装手势）
  final Widget title;

  /// 大标题
  final String largeTitle;

  /// 主体内容（消息列表 + 输入区）
  final Widget body;

  /// 导航栏操作按钮
  final List<Widget>? actions;

  // ========== 搜索/过滤配置 ==========

  final bool enableSearchBar;
  final String searchPlaceholder;
  final ValueChanged<String>? onSearchChanged;

  final bool enableMultiFilter;
  final List<FilterItem>? multiFilterItems;
  final double? multiFilterBarHeight;
  final ValueChanged<Map<String, dynamic>>? onMultiFilterChanged;

  // ========== 背景配置 ==========

  /// 背景图片绝对路径（null 表示纯色背景）
  final String? backgroundPath;

  /// 背景图片是否正在加载
  final bool isLoadingBackground;

  const ChatScreenScaffold({
    super.key,
    required this.title,
    required this.largeTitle,
    required this.body,
    this.actions,
    this.enableSearchBar = false,
    this.searchPlaceholder = '',
    this.onSearchChanged,
    this.enableMultiFilter = false,
    this.multiFilterItems,
    this.multiFilterBarHeight,
    this.onMultiFilterChanged,
    this.backgroundPath,
    this.isLoadingBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 有背景图时透明，让 Stack 底层图片透出；
      // 设置全局自定义背景（背景图/纯色/网格）时同样透明以透出全局背景
      backgroundColor: backgroundPath != null
          ? const Color(0x00000000)
          : dsTransparentWhenGlobalBackground(
              DSThemeBridge.resolve(context).surface,
            ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 默认白色背景 - 当没有背景图片时显示
          // （全局背景生效时透明，透出根部全局背景层）
          if (backgroundPath == null && !isLoadingBackground)
            Container(
              color: dsTransparentWhenGlobalBackground(
                DSThemeBridge.resolve(context).surface,
              ),
              width: double.infinity,
              height: double.infinity,
            ),
          // 背景层 - 确保这是Stack中的底层元素
          if (backgroundPath != null && !isLoadingBackground)
            Builder(
              builder: (context) {
                final file = File(backgroundPath!);
                if (!file.existsSync()) {
                  return const SizedBox.shrink();
                }
                // 使用Container包装图片，确保它占满整个屏幕
                return Container(
                  color: const Color(0x00000000), // 确保容器背景透明
                  child: Image.file(
                    file,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    // 添加key以强制重建
                    key: ValueKey(backgroundPath),
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Error loading background image: $error');
                      return Container(
                        color: DSThemeBridge.resolve(
                          context,
                        ).danger.withAlpha(77),
                      ); // 错误时显示红色背景以便调试
                    },
                  ),
                );
              },
            ),
          // 半透明遮罩层
          if (backgroundPath != null && !isLoadingBackground)
            Container(color: Colors.black.withAlpha(128)),
          // 加载指示器
          if (isLoadingBackground)
            Center(
              child: DSLoadingDots(
                color: DSThemeBridge.resolve(context).textSub,
              ),
            ),
          SuperCupertinoNavigationWrapper(
            title: title,
            largeTitle: largeTitle,
            body: body,
            enableLargeTitle: false,
            enableSearchBar: enableSearchBar,
            searchPlaceholder: searchPlaceholder,
            onSearchChanged: onSearchChanged,
            enableMultiFilter: enableMultiFilter,
            multiFilterItems: multiFilterItems,
            multiFilterBarHeight: multiFilterBarHeight ?? 50,
            onMultiFilterChanged: onMultiFilterChanged,
            backgroundColor: backgroundPath != null ? Colors.transparent : null,
            actions: actions,
          ),
        ],
      ),
    );
  }
}
