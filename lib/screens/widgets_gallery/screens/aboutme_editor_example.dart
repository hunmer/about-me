import 'package:flutter/material.dart';
import 'package:aboutme/widgets/aboutme_editor/aboutme_editor.dart';

/// Aboutme 编辑器示例
class AboutmeEditorExample extends StatefulWidget {
  const AboutmeEditorExample({super.key});

  @override
  State<AboutmeEditorExample> createState() => _AboutmeEditorExampleState();
}

class _AboutmeEditorExampleState extends State<AboutmeEditorExample> {
  String? _selectedMood;
  final List<String> _moods = [
    '😊',
    '😍',
    '🥰',
    '😎',
    '🤔',
    '😴',
    '😭',
    '😡',
    '🥳',
    '🧘',
  ];

  // 示例内容：JSON Delta 格式（使用原始字符串避免转义问题）
  final String _sampleContent = r'''{
  "ops": [
    {"insert": "欢迎使用 Aboutme 编辑器！", "attributes": {"header": 1}},
    {"insert": "\n"},
    {"insert": "这是一个功能强大的富文本编辑器，支持：\n"},
    {"insert": "\n"},
    {"insert": "• 粗体、斜体、下划线", "attributes": {"bold": true}},
    {"insert": "\n"},
    {"insert": "• 有序和无序列表", "attributes": {"list": "bullet"}},
    {"insert": "\n"},
    {"insert": "• 图片插入", "attributes": {"italic": true}},
    {"insert": "\n\n"},
    {"insert": "点击上方的工具栏按钮尝试不同的格式！", "attributes": {"color": "#D8BFD8"}}
  ]
}''';

  @override
  Widget build(BuildContext context) {
    return AboutmeEditor(
      pageTitle: '编辑器',
      initialTitle: '新笔记',
      initialContent: _sampleContent,
      date: DateTime.now(),
      mood: _selectedMood,
      titleHint: '输入标题...',
      contentHint: '开始记录你的想法...',
      onMoodTap: _showMoodPicker,
      onSave: (title, content) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存成功！标题：$title'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onClose: () => Navigator.of(context).pop(),
      actions: [
        IconButton(
          icon: const Icon(Icons.history),
          tooltip: '历史记录',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('历史记录功能'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ],
    );
  }

  void _showMoodPicker() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('选择心情'),
            content: SizedBox(
              width: 200,
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 1,
                ),
                itemCount: _moods.length,
                itemBuilder: (context, index) {
                  final mood = _moods[index];
                  return InkWell(
                    onTap: () {
                      setState(() => _selectedMood = mood);
                      Navigator.of(context).pop();
                    },
                    child: Center(
                      child: Text(mood, style: const TextStyle(fontSize: 32)),
                    ),
                  );
                },
              ),
        ),
      ),
    );
  }
}
