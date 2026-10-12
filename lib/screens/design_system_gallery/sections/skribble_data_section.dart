import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';

import 'gallery_section.dart';

/// skribble 原生组件示例 · 数据展示与杂项
class SkribbleDataSection extends StatefulWidget {
  const SkribbleDataSection({super.key});

  @override
  State<SkribbleDataSection> createState() => _SkribbleDataSectionState();
}

class _SkribbleDataSectionState extends State<SkribbleDataSection> {
  int _tab = 0;
  int _step = 0;
  final _items = ['事项 A', '事项 B', '事项 C'];

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      index: 'SK-4',
      title: 'skribble 列表数据',
      children: [
        DemoBlock(
          label: 'WiredTabBar',
          child: WiredTabBar(
            tabs: const ['首页', '发现', '我的'],
            selectedIndex: _tab,
            onTap: (i) => setState(() => _tab = i),
          ),
        ),
        const SizedBox(height: 16),
        const DemoBlock(
          label: 'WiredListTile',
          child: Column(
            children: [
              WiredListTile(
                leading: Icon(Icons.star),
                title: Text('Starred item'),
                subtitle: Text('With a hand-drawn border'),
              ),
              WiredListTile(
                leading: Icon(Icons.settings),
                title: Text('Settings'),
                trailing: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'WiredExpansionTile / ExpansionPanelList',
          child: Column(
            children: [
              const WiredExpansionTile(
                title: Text('展开手风琴'),
                subtitle: Text('内部状态自管，无外部控制参数'),
                children: [
                  Padding(padding: EdgeInsets.all(12), child: Text('展开后的内容区域')),
                ],
              ),
              WiredExpansionPanelList(
                children: [
                  WiredExpansionPanel(
                    headerBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('面板 1（点击头部展开）'),
                    ),
                    body: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('面板内容'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'WiredStepper（当前步 $_step）',
          child: WiredStepper(
            steps: [
              WiredStep(
                title: const Text('账号'),
                subtitle: const Text('填写基本信息'),
                content: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('第一步内容'),
                ),
              ),
              WiredStep(
                title: const Text('偏好'),
                content: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('第二步内容'),
                ),
              ),
            ],
            currentStep: _step,
            onStepTapped: (i) => setState(() => _step = i),
          ),
        ),
        const SizedBox(height: 16),
        const DemoBlock(
          label: 'WiredDataTable',
          child: WiredDataTable(
            columns: [
              WiredDataColumn(label: Text('名称')),
              WiredDataColumn(label: Text('状态')),
            ],
            rows: [
              WiredDataRow(cells: [Text('布丁'), Text('已上架')]),
              WiredDataRow(cells: [Text('软糖'), Text('缺货')]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const DemoBlock(
          label: 'WiredAvatar / WiredDivider / WiredSkeleton',
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WiredAvatar(backgroundColor: Color(0xFF885CF6), radius: 18),
                  SizedBox(width: 16),
                  WiredAvatar(radius: 18, child: Text('A')),
                ],
              ),
              SizedBox(height: 12),
              WiredDivider(),
              SizedBox(height: 12),
              WiredSkeleton(width: 220, height: 16),
              SizedBox(height: 8),
              WiredSkeleton(width: 160, height: 16),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'WiredLoader 全部节奏（orbit/dots/bars/ripple/flower/scribble）',
          child: Wrap(
            spacing: 18,
            runSpacing: 18,
            alignment: WrapAlignment.center,
            children: [
              for (final style in WiredLoaderStyle.values)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    WiredLoader(style: style, size: 44),
                    const SizedBox(height: 6),
                    Text(style.name, style: const TextStyle(fontSize: 10)),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'WiredDoodle 涂鸦 / WiredLogo',
          child: Wrap(
            spacing: 18,
            runSpacing: 18,
            alignment: WrapAlignment.center,
            children: [
              for (final kind in WiredDoodleKind.values)
                WiredDoodle(kind: kind, size: 40),
              WiredLogo(size: 44),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'WiredCarouselView',
          child: WiredCarouselView(
            itemExtent: 140,
            height: 90,
            children: [
              for (final c in const [
                Color(0xFF885CF6),
                Color(0xFFF5A8D4),
                Color(0xFF6EE7B7),
              ])
                Container(
                  color: c,
                  alignment: Alignment.center,
                  child: const Text('滑动'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'WiredDismissible（左滑删除）/ ReorderableListView',
          child: Column(
            children: [
              for (final (i, name) in _items.indexed)
                WiredDismissible(
                  dismissKey: ValueKey('dismiss-$i-$name'),
                  onDismissed: (_) => setState(() => _items.remove(name)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('👈 左滑删除：$name'),
                  ),
                ),
              if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('（已全部删除）'),
                ),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: WiredReorderableListView(
                  onReorder: (_, __) {},
                  children: const [
                    Padding(
                      key: ValueKey('r1'),
                      padding: EdgeInsets.all(8),
                      child: Text('长按拖拽排序 1'),
                    ),
                    Padding(
                      key: ValueKey('r2'),
                      padding: EdgeInsets.all(8),
                      child: Text('长按拖拽排序 2'),
                    ),
                    Padding(
                      key: ValueKey('r3'),
                      padding: EdgeInsets.all(8),
                      child: Text('长按拖拽排序 3'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const DemoBlock(
          label: 'WiredSelectableText',
          child: WiredSelectableText('这段文字可以长按选中复制（手绘边框）'),
        ),
      ],
    );
  }
}
