import 'package:aboutme/plugins/achievement/models/achievement_definition.dart';
import 'package:aboutme/plugins/achievement/widgets/achievement_unlock_dialog.dart';
import 'package:flutter/material.dart';

/// 通用组件展示主界面
class WidgetsGalleryScreen extends StatelessWidget {
  const WidgetsGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通用组件示例'),
      ),
      body: ListView(
        children: [
          // 设计系统（手绘风组件库）
          _buildListItem(
            context,
            icon: Icons.auto_awesome,
            title: '手绘风设计系统',
            subtitle: 'DesignSystemGallery（零依赖组件库）',
            route: '/design_system',
          ),
          // Picker 类组件
          _buildSectionHeader(context, 'Picker 选择器类'),
          _buildListItem(
            context,
            icon: Icons.palette,
            title: '颜色选择器',
            subtitle: 'ColorPickerSection',
            route: '/widgets_gallery/color_picker',
          ),
          _buildListItem(
            context,
            icon: Icons.face,
            title: '头像选择器',
            subtitle: 'AvatarPicker',
            route: '/widgets_gallery/avatar_picker',
          ),
          _buildListItem(
            context,
            icon: Icons.circle,
            title: '圆形图标选择器',
            subtitle: 'CircleIconPicker',
            route: '/widgets_gallery/circle_icon_picker',
          ),
          _buildListItem(
            context,
            icon: Icons.calendar_today,
            title: '日历条日期选择器',
            subtitle: 'CalendarStripDatePicker',
            route: '/widgets_gallery/calendar_strip_picker',
          ),
          _buildListItem(
            context,
            icon: Icons.image,
            title: '图片选择器',
            subtitle: 'ImagePickerDialog',
            route: '/widgets_gallery/image_picker',
          ),
          _buildListItem(
            context,
            icon: Icons.location_on,
            title: '位置选择器',
            subtitle: 'LocationPicker',
            route: '/widgets_gallery/location_picker',
          ),

          const Divider(),

          // 选择器类组件
          _buildSectionHeader(context, '选择器类'),
          _buildListItem(
            context,
            icon: Icons.table_chart,
            title: '数据选择器',
            subtitle: 'DataSelectorSheet',
            route: '/widgets_gallery/data_selector',
          ),
          _buildListItem(
            context,
            icon: Icons.face_retouching_natural,
            title: '人格选择轮播',
            subtitle: 'PersonalityCarousel（发光小人轮播，支持自定义展示组件）',
            route: '/widgets_gallery/personality_carousel',
          ),

          const Divider(),

          // 日历类组件
          _buildSectionHeader(context, '日历类'),

          const Divider(),

          // 文件预览类
          _buildSectionHeader(context, '文件预览类'),
          _buildListItem(
            context,
            icon: Icons.preview,
            title: '文件预览',
            subtitle: 'GalleryViewer.showFilePreview',
            route: '/widgets_gallery/file_preview',
          ),

          const Divider(),

          // 标签管理类
          _buildSectionHeader(context, '标签管理类'),
          _buildListItem(
            context,
            icon: Icons.label,
            title: '标签管理器',
            subtitle: 'TagManagerDialog',
            route: '/widgets_gallery/tag_manager',
          ),

          const Divider(),

          // 对话框类
          _buildSectionHeader(context, '对话框类'),
          _buildListItem(
            context,
            icon: Icons.portrait,
            title: '人设介绍对话框',
            subtitle: 'PersonaIntroDialog',
            route: '/widgets_gallery/persona_intro_dialog',
          ),
          const Divider(),

          // 弹窗类
          _buildSectionHeader(context, '弹窗类'),
          _buildListItem(
            context,
            icon: Icons.vertical_align_bottom,
            title: '平滑底部弹窗',
            subtitle: 'SmoothBottomSheet',
            route: '/widgets_gallery/smooth_bottom_sheet',
          ),
          // 成就解锁弹窗（直接触发，含 Confetti 撒花动画）
          ListTile(
            leading: const Icon(Icons.emoji_events),
            title: const Text('成就解锁弹窗'),
            subtitle: const Text('AchievementUnlockDialog + Lottie Confetti'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => AchievementUnlockDialog.enqueue(
              AchievementLevelUpEventArgs(
                achievementId: 'A01',
                name: '千言万语',
                condition: '累计发送频道消息 100条',
                iconAsset: 'assets/achievements/A01.webp',
                level: 3,
                unlockedAt: DateTime.now(),
                points: 30,
              ),
            ),
          ),

          const Divider(),

          // 桌面小组件
          _buildSectionHeader(context, '桌面小组件'),
          _buildListItem(
            context,
            icon: Icons.widgets,
            title: '桌面小组件',
            subtitle: 'HomeWidgets - 各种桌面小组件示例',
            route: '/widgets_gallery/home_widgets',
          ),
          const Divider(),

          // 其他组件
          _buildSectionHeader(context, '其他组件'),
          _buildListItem(
            context,
            icon: Icons.navigation,
            title: 'Super Cupertino 导航包装',
            subtitle: 'SuperCupertinoNavigationWrapper',
            route: '/widgets_gallery/super_cupertino_navigation',
          ),
          _buildListItem(
            context,
            icon: Icons.photo_camera,
            title: 'Swatch 3D 相机相框',
            subtitle: 'SwatchCameraFrame（相机比例样式：原始 / 9:16 / 16:9）',
            route: '/widgets_gallery/swatch_camera_frame',
          ),
          _buildListItem(
            context,
            icon: Icons.receipt_long,
            title: '热敏打印账单',
            subtitle: 'RunReceiptPrinter（热敏打印机吐纸动画，支持拖拽查看）',
            route: '/widgets_gallery/run_receipt_printer',
          ),
          _buildListItem(
            context,
            icon: Icons.map,
            title: 'Moments 纽约地图',
            subtitle: 'MomentsNycMapDemo（flutter_map + 手账照片详情）',
            route: '/widgets_gallery/moments_nyc_map',
          ),
          _buildListItem(
            context,
            icon: Icons.casino,
            title: '时计幸运转盘',
            subtitle: 'LuckyWheel（极简轻奢表盘 + 棘轮音效 + 金粉粒子）',
            route: '/widgets_gallery/lucky_wheel',
          ),
          _buildListItem(
            context,
            icon: Icons.graphic_eq,
            title: 'Siri 流光语音助手',
            subtitle: 'SiriVoiceAssistantCard（流光丝带 + 地平线透镜弧光）',
            route: '/widgets_gallery/siri_voice_assistant_orb',
          ),
          _buildListItem(
            context,
            icon: Icons.music_note,
            title: '音频与识曲 UI 复刻',
            subtitle: 'AudioUiReplicaDemoPage（Shazam 灵动岛胶囊 + 深色语音卡片）',
            route: '/widgets_gallery/audio_ui_replica',
          ),
          _buildListItem(
            context,
            icon: Icons.threed_rotation,
            title: '图片伪3D翻转卡片',
            subtitle: 'Pseudo3DFlipCard（Z轴切片堆叠厚度 + 透视跟随 + 流光高光）',
            route: '/widgets_gallery/pseudo_3d_flip_card',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildListItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => Navigator.pushNamed(context, route),
    );
  }
}
