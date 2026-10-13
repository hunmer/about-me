import 'dart:io';

import 'package:flutter/material.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/openai/aliveness/screens/memory_manager_screen.dart';
import 'package:aboutme/plugins/openai/aliveness/services/chat_import_service.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/utils/file_picker_helper.dart';

import 'package:get/get.dart';
/// 分析聊天记录（活人感·记忆初始化 / TA 人格克隆）：
/// 导入 txt/zip 聊天记录分段分析，两种模式：
/// 1. 新建 AI：提取 TA（聊天对象）的人格生成人设创建新 AI（配置克隆自当前 AI），
///    同时把「我」的信息碎片写入新 AI 的记忆
/// 2. 补充记忆：只提取「我」的信息碎片写入当前 AI
/// 参考 KnowMe：从真实对话中认识一个人。
class ChatImportScreen extends StatefulWidget {
  final String agentId;
  final String agentName;

  const ChatImportScreen({
    super.key,
    required this.agentId,
    required this.agentName,
  });

  @override
  State<ChatImportScreen> createState() => _ChatImportScreenState();
}

enum _ImportMode { createAgent, memoryOnly }

class _ChatImportScreenState extends State<ChatImportScreen> {
  _ImportMode _mode = _ImportMode.createAgent;
  final _files = <File>[];
  bool _loadingFiles = false;
  bool _analyzing = false;
  bool _cancelRequested = false;
  ChatImportPhase _phase = ChatImportPhase.extracting;
  int _processed = 0;
  int _total = 0;
  int _added = 0;
  ChatImportResult? _result;

  Future<void> _pickFiles() async {
    if (_analyzing) return;
    setState(() => _loadingFiles = true);
    try {
      final picked = await FilePickerHelper.pickFiles(
        allowedExtensions: [...ChatImportService.textExtensions, 'zip'],
      );
      if (picked.isNotEmpty) {
        setState(() {
          _files
            ..clear()
            ..addAll(picked);
          _result = null;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  Future<void> _start() async {
    if (_files.isEmpty || _analyzing) return;
    final agent =
        await OpenAIPlugin.instance.controller.getAgent(widget.agentId);
    if (agent == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未找到该 AI 的配置')));
      }
      return;
    }

    setState(() {
      _analyzing = true;
      _cancelRequested = false;
      _result = null;
      _phase = ChatImportPhase.extracting;
      _processed = 0;
      _total = 0;
      _added = 0;
    });

    final texts = await ChatImportService.instance.loadFromFiles(_files);
    if (!mounted) return;
    if (texts.isEmpty) {
      setState(() => _analyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有读到可分析的文本（支持 txt/md/log/json/csv，zip 会遍历内部文本文件）')),
      );
      return;
    }

    try {
      final result = await ChatImportService.instance.analyze(
        agent: agent,
        texts: texts,
        createAgent: _mode == _ImportMode.createAgent,
        onProgress: (phase, processed, total, added) {
          if (mounted) {
            setState(() {
              _phase = phase;
              _processed = processed;
              _total = total;
              _added = added;
            });
          }
        },
        shouldCancel: () => _cancelRequested,
      );
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _result = result;
      });
    } catch (e) {
      // ChatImportException：业务失败（人设生成失败/无 TA 观察），可直接展示
      if (!mounted) return;
      setState(() => _analyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ChatImportException ? e.message : '分析失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('openai_analyzeChatHistory'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '把聊天记录导出为文本导入，AI 会分段分析这些真实对话。\n'
            '支持 txt / md / log / json / csv（可多选），zip 会自动遍历内部文本文件。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _buildModeSelector(theme),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _loadingFiles || _analyzing ? null : _pickFiles,
            icon: _loadingFiles
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
            label: Text(_files.isEmpty ? '选择文件' : '重新选择'),
          ),
          if (_files.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final f in _files)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  FilePickerHelper.getFileIcon(f),
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  FilePickerHelper.getFileName(f),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${FilePickerHelper.getFileExtension(f).toUpperCase()} · '
                  '${_formatFileSizeSync(f)}',
                ),
              ),
          ],
          if (_analyzing || _result != null) ...[
            const Divider(height: 24),
            _buildProgress(theme),
          ],
          const SizedBox(height: 16),
          if (_result != null) _buildResultActions(theme),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _analyzing
              ? OutlinedButton.icon(
                  onPressed: _cancelRequested ? null : _requestCancel,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(_cancelRequested ? '正在取消…' : '取消分析'),
                )
              : FilledButton.icon(
                  onPressed: _files.isEmpty ? null : _start,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text('openai_startAnalysis'.tr),
                ),
        ),
      ),
    );
  }

  Widget _buildModeSelector(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          RadioListTile<_ImportMode>(
            value: _ImportMode.createAgent,
            groupValue: _mode,
            onChanged: _analyzing ? null : (v) => setState(() => _mode = v!),
            title: Text('openai_restoreCreateNewAI'.tr),
            subtitle: Text(
              '提取 TA（聊天对象）的说话风格与人格生成新 AI（模型配置复制自「${widget.agentName}」），'
              '同时把「我」的信息记入它的记忆',
            ),
          ),
          RadioListTile<_ImportMode>(
            value: _ImportMode.memoryOnly,
            groupValue: _mode,
            onChanged: _analyzing ? null : (v) => setState(() => _mode = v!),
            title: Text('openai_supplementCurrentAIMemory'.tr),
            subtitle: Text(
              '只提取「我」的信息碎片，写入「${widget.agentName}」的记忆库',
            ),
          ),
        ],
      ),
    );
  }

  void _requestCancel() {
    setState(() => _cancelRequested = true);
  }

  Widget _buildProgress(ThemeData theme) {
    final result = _result;
    if (result != null) {
      final summary = result.cancelled
          ? '已取消'
          : result.failedChunks > 0
              ? '完成（${result.failedChunks} 块失败已跳过）'
              : '完成';
      final target = result.createdAgentName != null
          ? '已创建「${result.createdAgentName}」，并写入 ${result.addedFragments} 条关于你的记忆'
          : '新增 ${result.addedFragments} 条碎片';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$summary：$target', style: theme.textTheme.titleSmall),
          if (result.persona != null) ...[
            const SizedBox(height: 8),
            Text('生成的人设：', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result.persona!,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: _phase == ChatImportPhase.generatingPersona
              ? null
              : (_total == 0 ? null : _processed / _total),
        ),
        const SizedBox(height: 8),
        Text(
          _phase == ChatImportPhase.generatingPersona
              ? '正在汇总观察，生成 TA 的人设…'
              : _total == 0
                  ? '正在读取文件…'
                  : '分析中 $_processed/$_total 块 · 已提取 $_added 条碎片',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildResultActions(ThemeData theme) {
    final result = _result!;
    return Wrap(
      spacing: 8,
      children: [
        if (result.createdAgentId != null)
          FilledButton.tonalIcon(
            onPressed: () => NavigationHelper.push(
              context,
              MemoryManagerScreen(
                agentId: result.createdAgentId!,
                agentName: result.createdAgentName ?? '',
              ),
            ),
            icon: const Icon(Icons.smart_toy_outlined, size: 18),
            label: Text('查看「${result.createdAgentName}」的记忆'),
          )
        else
          FilledButton.tonalIcon(
            onPressed: () => NavigationHelper.push(
              context,
              MemoryManagerScreen(
                agentId: widget.agentId,
                agentName: widget.agentName,
              ),
            ),
            icon: const Icon(Icons.psychology_alt, size: 18),
            label: Text('openai_viewMemory'.tr),
          ),
        if ((result.addedFragments) > 0 && !result.cancelled)
          ActionChip(
            label: Text('openai_continueImportMore'.tr),
            onPressed: _analyzing ? null : _pickFiles,
          ),
      ],
    );
  }
}

String _formatFileSizeSync(File f) {
  final bytes = f.lengthSync();
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
