import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cute_notepad_card.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cute_notepad_variants.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 可爱手账便签卡片示例
///
/// 同一个组件入口 [CuteNotepadCardWidget]，通过 16 种风格预设切换外观；
/// 示例内容移植自网页版 fillDemoContent。
class CuteNotepadCardExample extends StatefulWidget {
  const CuteNotepadCardExample({super.key});

  @override
  State<CuteNotepadCardExample> createState() => _CuteNotepadCardExampleState();
}

class _CuteNotepadCardExampleState extends State<CuteNotepadCardExample> {
  /// 可编辑演示开关
  bool _editable = false;

  /// 各风格的示例内容（static final，避免热重载不生效）
  static final Map<String, (String?, String?, List<CuteNotepadTodoItem>?)>
      _demos = {
        'pinkGridBunny': (
          null,
          '今日份开心小确幸：\n1. 早起冲了一杯热燕麦拿铁 ☕\n2. 傍晚散步看到了粉紫色的晚霞 ✨',
          [
            CuteNotepadTodoItem(checked: true, text: '把拍到的晚霞照片洗印出来贴进手账本'),
            CuteNotepadTodoItem(text: '睡前点香薰蜡烛听半小时轻音乐'),
          ],
        ),
        'yellowTodoFlower': (
          null,
          null,
          [
            CuteNotepadTodoItem(checked: true, text: '晨间拉伸 15 分钟 + 喝一杯温柠檬水唤醒身体'),
            CuteNotepadTodoItem(checked: true, text: '整理本周项目设计稿并导出 SVG 组件库'),
            CuteNotepadTodoItem(text: '去街角花店买一束黄色雏菊和粉色郁金香装点书桌'),
            CuteNotepadTodoItem(text: '阅读手账插画排版灵感书第 3-5 章'),
            CuteNotepadTodoItem(text: '准备周末野餐便当食材（草莓、三明治、气泡水）'),
            CuteNotepadTodoItem(text: '23:00 前放下手机进入深度睡眠 🌙'),
          ],
        ),
        'purpleCloud': (
          null,
          '每天进步一点点，不需要和别人比较，按自己的节奏慢慢发芽开花 🌱\n即使今天走得很慢，也是在向前走呀！',
          null,
        ),
        'greenHeartFrog': (
          null,
          null,
          [
            CuteNotepadTodoItem(checked: true, text: '喝满 8 杯温水（目前已达成 2000ml）'),
            CuteNotepadTodoItem(checked: true, text: '吃新鲜蓝莓、奇异果和牛油果沙拉 🥑'),
            CuteNotepadTodoItem(text: '整理本月记账表单与储蓄计划'),
            CuteNotepadTodoItem(text: '练习尤克里里新曲子《小手拉大手》20分钟'),
            CuteNotepadTodoItem(text: '给阳台的小绿植浇水、松土、晒太阳'),
            CuteNotepadTodoItem(text: '晚饭后和家人一起散步聊聊天'),
          ],
        ),
        'blueWaveNotes': (
          null,
          '周末草莓奶油蛋糕烘焙配方：\n- 低筋面粉 120g + 鸡蛋 4颗\n- 动物性淡奶油 300ml\n- 新鲜红颜草莓一盒 🍓',
          null,
        ),
        'pinkTulipLined': (
          null,
          null,
          [
            CuteNotepadTodoItem(text: '本月治愈系电影观影清单 🎬：'),
            CuteNotepadTodoItem(text: '1. 《小森林·夏秋篇》（手作美食超治愈）'),
            CuteNotepadTodoItem(text: '2. 《海街日记》（镰仓的夏天与梅子酒）'),
            CuteNotepadTodoItem(text: '3. 《魔女宅急便》（永远保持热忱与勇气）'),
            CuteNotepadTodoItem(text: '4. 《侧耳倾听》（追寻梦想的温暖故事）'),
            CuteNotepadTodoItem(text: '准备好焦糖爆米花和蜜桃乌龙汽水，周六晚八点准时开启！'),
            CuteNotepadTodoItem(text: '看完记得在手账本写下喜欢的台词~'),
          ],
        ),
        'yellowPlaidSun': (
          null,
          '保持热爱，奔赴山海 ☀️\n记得给今天一个大大的微笑！',
          null,
        ),
        'purpleGridCat': (
          null,
          '你已经做得非常棒啦！\n完成阶段目标后奖励自己一顿热腾腾的寿喜烧 🐱🍲',
          null,
        ),
        'greenTornStar': (
          null,
          null,
          [
            CuteNotepadTodoItem(checked: true, text: '背诵 30 个核心手账英语词汇'),
            CuteNotepadTodoItem(checked: true, text: '完成 SVG 动态高度与多行待办引擎升级'),
            CuteNotepadTodoItem(text: '测试左下角与右下角贴纸自动跟随'),
            CuteNotepadTodoItem(text: '傍晚慢跑 3 公里吹吹晚风'),
            CuteNotepadTodoItem(text: '睡前泡脚 & 敷补水面膜'),
          ],
        ),
        'purpleFrameFlower': (
          null,
          '“生活明朗，万物可爱。\n人间值得，未来可期。” 💜',
          null,
        ),
        'bluePenguin': (
          null,
          '距离目标达成还有最后 20%，稳住心态，继续加油鸭 🐧💪',
          null,
        ),
        'pinkWaveCherry': (
          null,
          null,
          [
            CuteNotepadTodoItem(text: '甜品探店打卡笔记 🍒：'),
            CuteNotepadTodoItem(text: '📍 樱桃奶油舒芙蕾松饼（云朵般绵密口感）'),
            CuteNotepadTodoItem(text: '📍 海盐芝士开心果巴斯克蛋糕'),
            CuteNotepadTodoItem(text: '下次想约好朋友一起去二刷！'),
          ],
        ),
        'purplePlaidCloud': (
          null,
          '朋友生日礼物灵感清单 🎁\n- 木质白茶香薰蜡烛\n- 手工毛线钩织小兔子挂件',
          null,
        ),
        'yellowPolkaBear': (
          null,
          null,
          [
            CuteNotepadTodoItem(checked: true, text: '收拾双肩包、雨伞与大容量充电宝'),
            CuteNotepadTodoItem(checked: true, text: '确认往返高铁车票与民宿入住时间'),
            CuteNotepadTodoItem(text: '带上复古拍立得相机和两盒彩色相纸 📷'),
            CuteNotepadTodoItem(text: '准备防晒霜、墨镜与编织草帽'),
            CuteNotepadTodoItem(text: '出发去江南古镇度过悠闲周末！'),
          ],
        ),
        'peachGoodThings': (
          null,
          '春天已经在路上啦，所有的好运与惊喜都在悄悄向你靠近 🌷',
          null,
        ),
        'blueBinderHoles': (
          null,
          '功能备忘：\n1. 超出高度无滚动条自动延展\n2. 待办支持多行折行\n3. 底部贴纸形象自动贴底',
          null,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('可爱手账便签卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('16 种风格预设（示例内容）'),
              const SizedBox(height: 8),
              _buildDemoGrid(),
              const SizedBox(height: 24),
              _buildSectionTitle('可编辑模式（贴纸拖拽/旋转/缩放 · 导出 PNG）'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('开启 editable 可选项'),
                subtitle: const Text(
                  '开启后卡片右上角出现编辑按钮；编辑模式下点选贴纸后可拖动、'
                  '双指或 Shift+滚轮旋转缩放（底部有工具条），右上角按钮切换为导出 PNG',
                ),
                value: _editable,
                onChanged: (v) => setState(() => _editable = v),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  CuteNotepadCardWidget(
                    variant: resolveCuteNotepadVariant('pinkGridBunny'),
                    text: _demos['pinkGridBunny']!.$2,
                    items: _demos['pinkGridBunny']!.$3,
                    editable: _editable,
                  ),
                  CuteNotepadCardWidget(
                    variant: resolveCuteNotepadVariant('yellowPolkaBear'),
                    items: _demos['yellowPolkaBear']!.$3,
                    editable: _editable,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('初始空白状态（同一组件入口，不传内容）'),
              const SizedBox(height: 8),
              _buildBlankGrid(),
              const SizedBox(height: 24),
              _buildSectionTitle('不同尺寸（LargeSize / SmallSize）'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  CuteNotepadCardWidget(
                    variant: resolveCuteNotepadVariant('pinkGridBunny'),
                    text: _demos['pinkGridBunny']!.$2,
                    items: _demos['pinkGridBunny']!.$3,
                    size: const LargeSize(),
                  ),
                  CuteNotepadCardWidget(
                    variant: resolveCuteNotepadVariant('yellowPlaidSun'),
                    text: _demos['yellowPlaidSun']!.$2,
                    size: const SmallSize(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 16 张示例内容便签（两列自适应换行）
  Widget _buildDemoGrid() {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        for (final variant in cuteNotepadPresets)
          CuteNotepadCardWidget(
            variant: variant,
            title: _demos[variant.id]?.$1,
            text: _demos[variant.id]?.$2,
            items: _demos[variant.id]?.$3,
          ),
      ],
    );
  }

  /// 初始空白状态（预设默认空行/占位）
  Widget _buildBlankGrid() {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        for (final variant in cuteNotepadPresets)
          CuteNotepadCardWidget(variant: variant),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
      ),
    );
  }
}
