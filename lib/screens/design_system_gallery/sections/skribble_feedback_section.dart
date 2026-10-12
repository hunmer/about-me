import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';

import 'gallery_section.dart';

/// skribble 原生组件示例 · 反馈
class SkribbleFeedbackSection extends StatefulWidget {
  const SkribbleFeedbackSection({super.key});

  @override
  State<SkribbleFeedbackSection> createState() =>
      _SkribbleFeedbackSectionState();
}

class _SkribbleFeedbackSectionState extends State<SkribbleFeedbackSection> {
  double _progress = 0.65;
  bool _bannerShown = false;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      index: 'SK-3',
      title: 'skribble 反馈浮层',
      children: [
        const DemoBlock(
          label: 'WiredDialog（内嵌展示）',
          // 内部画布无固有尺寸，需要外部有界约束（弹窗场景同理）
          child: SizedBox(
            width: 280,
            height: 96,
            child: WiredDialog(child: Text('This is a hand-drawn dialog box.')),
          ),
        ),
        const SizedBox(height: 16),
        const DemoBlock(
          label: 'WiredBadge / WiredTooltip',
          child: Wrap(
            spacing: 24,
            alignment: WrapAlignment.center,
            children: [
              WiredBadge(label: '3', child: Icon(Icons.mail_outline, size: 32)),
              WiredTooltip(
                message: '手绘气泡提示',
                child: Icon(Icons.help_outline, size: 32),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'WiredProgress / WiredCircularProgress',
          child: Column(
            children: [
              WiredProgress(value: _progress),
              const SizedBox(height: 8),
              const WiredProgress(), // indeterminate
              const SizedBox(height: 12),
              WiredCircularProgress(value: _progress),
              const SizedBox(width: 12),
              Slider(
                value: _progress,
                onChanged: (v) => setState(() => _progress = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'showWiredSnackBar / BottomSheet / DatePicker / Banner',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              WiredButton(
                onPressed: () => showWiredSnackBar(
                  context,
                  content: const WiredSnackBarContent(
                    child: Text('来自 skribble 的手绘 SnackBar'),
                  ),
                ),
                child: const Text('SnackBar'),
              ),
              WiredButton(
                onPressed: () async {
                  await showWiredBottomSheet(
                    context: context,
                    builder: (_) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('手绘 BottomSheet 内容'),
                    ),
                  );
                },
                child: const Text('BottomSheet'),
              ),
              WiredButton(
                onPressed: () async {
                  final d = await showWiredDatePicker(context: context);
                  if (d != null && mounted) {
                    showWiredSnackBar(
                      context,
                      content: WiredSnackBarContent(
                        child: Text('选中 ${d.toString().substring(0, 10)}'),
                      ),
                    );
                  }
                },
                child: const Text('DatePicker 弹窗'),
              ),
              WiredButton(
                onPressed: () {
                  showWiredMaterialBanner(
                    context,
                    content: const Text('手绘 Material Banner'),
                    // 需要手动移除：ScaffoldMessenger
                  );
                  setState(() => _bannerShown = true);
                },
                child: const Text('MaterialBanner'),
              ),
              if (_bannerShown)
                WiredButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                    setState(() => _bannerShown = false);
                  },
                  child: const Text('关 Banner'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
