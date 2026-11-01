// 脚本编辑：代码编辑 Tab（代码加载/编辑器/本地脚本文件选择与提示）。
part of 'script_edit_screen.dart';

/// 代码编辑拆分：扩展 [_ScriptEditScreenState]，与类内方法等价。
extension _ScriptEditCode on _ScriptEditScreenState {
  /// 加载脚本代码
  Future<void> _loadScriptCode() async {
    if (widget.script == null) return;

    try {
      final code = await widget.scriptManager.getScriptCode(widget.script!.id);
      if (code != null && mounted) {
        _codeController.text = code;
      }
    } catch (e) {
      // 加载失败，保持空代码
      debugPrint('Failed to load script code: $e');
    }
  }

  /// 选择本地脚本文件
  Future<void> _pickLocalScriptFile() async {
    final files = await FilePickerHelper.pickFiles(multiple: false);
    if (files.isNotEmpty) {
      final file = files.first;
      setState(() {
        _localScriptPath = file.path;
      });

      // 自动加载文件内容
      try {
        final content = await file.readAsString();
        _codeController.text = content;
        toastService.showToast('已加载文件内容');
      } catch (e) {
        toastService.showToast('加载文件失败: $e');
      }
    }
  }

  /// 清除本地文件路径
  void _clearLocalScriptPath() {
    setState(() {
      _localScriptPath = null;
    });
  }

  /// 构建代码编辑器标签页
  Widget _buildCodeEditorTab() {
    final theme = DSThemeBridge.resolve(context);
    return Column(
      children: [
        // 工具栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: theme.surfaceAlt,
          child: Row(
            children: [
              DsIcon(DsIconKind.code, size: 20, color: theme.primary),
              const SizedBox(width: 8),
              Text(
                'JavaScript 代码',
                style: DsTypography.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  // TODO: 添加代码格式化功能
                  toastService.showToast('代码格式化功能即将推出');
                },
                icon: const Icon(Icons.format_align_left, size: 18),
                label: Text('scripts_center_format'.tr),
              ),
            ],
          ),
        ),
        // 代码编辑器
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _codeController,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              decoration: const InputDecoration(
                hintText:
                    '// 在此输入 JavaScript 代码\n'
                    '// 例如：\n'
                    '// function execute(context, args) {\n'
                    '//   console.log("Hello from script!");\n'
                    '//   return { success: true };\n'
                    '// }',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(16),
              ),
              textAlignVertical: TextAlignVertical.top,
            ),
          ),
        ),
        // 本地文件路径选择
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: theme.backgroundAlt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DsIcon(DsIconKind.pin, size: 18, color: theme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '本地文件链接',
                    style: DsTypography.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.text,
                    ),
                  ),
                  const Spacer(),
                  if (_localScriptPath != null)
                    TextButton.icon(
                      onPressed: _clearLocalScriptPath,
                      icon: const Icon(Icons.clear, size: 16),
                      label: Text('scripts_center_clear'.tr),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.danger,
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _pickLocalScriptFile,
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: Text('scripts_center_selectFile'.tr),
                  ),
                ],
              ),
              if (_localScriptPath != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: theme.stroke),
                  ),
                  child: Row(
                    children: [
                      DsIcon(
                        DsIconKind.copy,
                        size: 16,
                        color: theme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _localScriptPath!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '初始化时将从此文件同步最新代码',
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ],
            ],
          ),
        ),
        // 提示信息
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: theme.surfaceAlt,
          child: Row(
            children: [
              DsIcon(DsIconKind.info, size: 16, color: theme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '脚本将在满足触发条件时执行。可以访问 context 对象获取应用上下文。',
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
