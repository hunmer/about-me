import 'package:flutter/material.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/widgets/aboutme_editor/aboutme_editor.dart';
import 'package:aboutme/plugins/diary/utils/diary_utils.dart';
import 'package:get/get.dart';

class DiaryEditorScreen extends StatefulWidget {
  final DateTime date;
  final StorageManager storage;
  final String initialTitle;
  final String initialContent;

  const DiaryEditorScreen({
    super.key,
    required this.date,
    required this.storage,
    this.initialTitle = '',
    required this.initialContent,
  });

  @override
  State<DiaryEditorScreen> createState() => _DiaryEditorScreenState();
}

class _DiaryEditorScreenState extends State<DiaryEditorScreen> {
  String? _selectedMood;

  // 心情表情列表
  final List<String> _moods = [
    '😊',
    '😢',
    '😡',
    '😴',
    '🤔',
    '😎',
    '😍',
    '🤮',
    '😱',
    '🥳',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentEntry();
  }

  Future<void> _loadCurrentEntry() async {
    // 从存储加载最新的日记条目
    final entry = await DiaryUtils.loadDiaryEntry(widget.date);
    if (entry != null && mounted) {
      setState(() {
        _selectedMood = entry.mood;
      });
    }
  }

  void _showMoodSelector() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('diary_selectMood'.tr),
            content: Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _moods.map((mood) {
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedMood = mood);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                mood == _selectedMood
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(mood, style: const TextStyle(fontSize: 24)),
                      ),
                    );
                  }).toList(),
            ),
            actions: [
              if (_selectedMood != null)
                TextButton(
                  onPressed: () {
                    setState(() => _selectedMood = null);
                    Navigator.pop(context);
                  },
                  child: Text('diary_clearSelection'.tr),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('app_close'.tr),
              ),
            ],
          ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('diary_confirmDeleteDiary'.tr),
            content: Text('diary_deleteDiaryMessage'.tr),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('app_cancel'.tr),
              ),
              TextButton(
                onPressed: () async {
                  // 关闭对话框
                  Navigator.pop(context);
                  // 删除日记
                  await DiaryUtils.deleteDiaryEntry(widget.date);
                  // 返回上一级
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text('diary_confirmDeleteDiary'.tr),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AboutmeEditor(
      initialTitle: widget.initialTitle,
      initialContent: widget.initialContent,
      pageTitle: 'diary_name'.tr,
      date: widget.date,
      mood: _selectedMood,
      onMoodTap: _showMoodSelector,
      titleHint: 'diary_titleHint'.tr,
      contentHint: 'diary_contentHint'.tr,
      onSave: (title, content) async {
        // 保存前捕获当前上下文
        final currentContext = context;

        await DiaryUtils.saveDiaryEntry(
          widget.date,
          content,
          title: title,
          mood: _selectedMood,
        );

        if (mounted) {
          Navigator.of(currentContext).pop();
        }
      },
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: _showDeleteConfirmation,
          tooltip: 'diary_deleteDiary'.tr,
        ),
      ],
    );
  }
}
