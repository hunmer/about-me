import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/models/memory_library.dart';
import 'package:aboutme/plugins/openai/aliveness/screens/memory_library_detail_screen.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 记忆库管理页：创建、查看和选择 agent 要使用的独立记忆库。
class MemoryManagerScreen extends StatefulWidget {
  final AlivenessConfig? config;
  final ValueChanged<AlivenessConfig>? onConfigChanged;

  const MemoryManagerScreen({super.key, this.config, this.onConfigChanged});

  @override
  State<MemoryManagerScreen> createState() => _MemoryManagerScreenState();
}

class _MemoryManagerScreenState extends State<MemoryManagerScreen> {
  List<MemoryLibrary> _libraries = const [];
  late Set<String> _selectedIds;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedIds = {...?widget.config?.memoryIds};
    _load();
  }

  Future<void> _load() async {
    try {
      final libraries = await AlivenessStore.instance.loadMemoryLibraries();
      if (!mounted) return;
      setState(() {
        _libraries = libraries;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      Toast.error('openai_memoryLibraryLoadFailed'.trParams({'@error': '$error'}));
    }
  }

  void _toggleLibrary(MemoryLibrary library, bool enabled) {
    setState(() {
      if (enabled) {
        _selectedIds.add(library.id);
      } else {
        _selectedIds.remove(library.id);
      }
    });
    final config = widget.config;
    final onChanged = widget.onConfigChanged;
    if (config != null && onChanged != null) {
      onChanged(config.copyWith(memoryIds: _selectedIds.toList()));
    }
  }

  Future<void> _createLibrary() async {
    final result = await _showLibraryEditor();
    if (result == null) return;

    try {
      await AlivenessStore.instance.createMemoryLibrary(
        result.name,
        description: result.description,
        allowedKeyPrefixes: result.allowedKeyPrefixes,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        Toast.error('openai_memoryLibraryCreateFailed'.trParams({'@error': '$error'}));
      }
    }
  }

  Future<void> _editLibrary(MemoryLibrary library) async {
    final result = await _showLibraryEditor(library: library);
    if (result == null) return;

    try {
      await AlivenessStore.instance.updateMemoryLibrary(
        library.id,
        name: result.name,
        description: result.description,
        allowedKeyPrefixes: result.allowedKeyPrefixes,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        Toast.error('openai_memoryLibraryUpdateFailed'.trParams({'@error': '$error'}));
      }
    }
  }

  Future<_MemoryLibraryFormResult?> _showLibraryEditor({
    MemoryLibrary? library,
  }) {
    final formKey = GlobalKey<_LibraryFormFieldsState>();
    return SmoothBottomSheet.showForm<_MemoryLibraryFormResult>(
      context: context,
      title: (library == null
              ? 'openai_memoryLibraryCreate'
              : 'openai_memoryLibraryEdit')
          .tr,
      onSave: () => formKey.currentState?.submit(),
      child: _LibraryFormFields(key: formKey, library: library),
    );
  }

  Future<void> _copyId(String id) async {
    await Clipboard.setData(ClipboardData(text: id));
    if (mounted) Toast.success('openai_memoryLibraryIdCopied'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final canSelect = widget.config != null && widget.onConfigChanged != null;
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return SuperCupertinoNavigationWrapper(
            title: Text('openai_memoryManagerTitle'.tr),
            largeTitle: 'openai_memoryManagerTitle'.tr,
            previousPageTitle: 'openai_pluginSettingsTitle'.tr,
            actions: [
              DSThemeBridge(
                child: Builder(
                  builder: (context) {
                    final theme = DSThemeBridge.resolve(context);
                    return DSIconButton(
                      icon: DsIconKind.plus,
                      size: 36,
                      color: theme.primary,
                      iconColor: theme.onPrimary,
                      onPressed: _createLibrary,
                    );
                  },
                ),
              ),
            ],
            body: Column(
              children: [
                if (canSelect)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
                    child: Row(
                      children: [
                        DsIcon(
                          DsIconKind.info,
                          size: 16,
                          color: theme.textSub,
                        ),
                        SizedBox(width: theme.spacing.sm),
                        Expanded(
                          child: Text(
                            'openai_memoryLibrariesSelectHint'.tr,
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _loading
                      ? Center(child: DSLoadingDots(color: theme.primary))
                      : _libraries.isEmpty
                      ? Center(
                          child: DSEmptyState(
                            icon: DsIconKind.layers,
                            title: 'openai_memoryLibrariesEmptyTitle'.tr,
                            message: 'openai_memoryLibrariesEmptyMessage'.tr,
                            actionLabel: 'openai_memoryLibraryCreate'.tr,
                            onAction: _createLibrary,
                          ),
                        )
                      : HandDrawnListView(
                          padding: EdgeInsets.fromLTRB(
                            theme.spacing.lg,
                            12, // 贴条顶部出血
                            theme.spacing.lg,
                            MediaQuery.paddingOf(context).bottom,
                          ),
                          itemCount: _libraries.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          tiltKeyOf: (index) => _libraries[index].id,
                          itemBuilder: (context, index) =>
                              _buildLibraryCard(context, index, canSelect),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLibraryCard(BuildContext context, int index, bool canSelect) {
    final library = _libraries[index];
    final theme = DSThemeBridge.resolve(context);
    final selected = _selectedIds.contains(library.id);
    return DSCard(
      onTap: () => NavigationHelper.push(
        context,
        MemoryLibraryDetailScreen(
          memoryId: library.id,
          memoryName: library.name,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (canSelect) ...[
                DSCheckbox(
                  value: selected,
                  onChanged: (value) =>
                      _toggleLibrary(library, value ?? false),
                ),
                SizedBox(width: theme.spacing.sm),
              ],
              Expanded(
                child: Text(
                  library.name,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
              ),
              DSIconButton(
                icon: DsIconKind.edit,
                size: 34,
                color: theme.surface,
                iconColor: theme.textSub,
                onPressed: () => _editLibrary(library),
              ),
              DSIconButton(
                icon: DsIconKind.copy,
                size: 34,
                color: theme.surface,
                iconColor: theme.textSub,
                onPressed: () => _copyId(library.id),
              ),
            ],
          ),
          if (library.description.isNotEmpty) ...[
            SizedBox(height: theme.spacing.sm),
            Text(
              library.description,
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
          ],
          SizedBox(height: theme.spacing.sm),
          Text(
            [
              'openai_memoryLibraryId'.trParams({'@id': library.id}),
              'openai_memoryLibraryCreatedAt'.trParams({
                '@date': _formatDate(library.createdAt),
              }),
              if (library.allowedKeyPrefixes.isNotEmpty)
                'openai_memoryLibraryWriteLimit'.trParams({
                  '@prefixes': library.allowedKeyPrefixes.join('、'),
                }),
            ].join('\n'),
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

/// 记忆库表单字段（新建/编辑共用，底部弹层内容由标题栏保存按钮触发提交）
class _LibraryFormFields extends StatefulWidget {
  final MemoryLibrary? library;

  const _LibraryFormFields({super.key, this.library});

  @override
  State<_LibraryFormFields> createState() => _LibraryFormFieldsState();
}

class _LibraryFormFieldsState extends State<_LibraryFormFields> {
  late final _nameController = TextEditingController(
    text: widget.library?.name ?? '',
  );
  late final _descriptionController = TextEditingController(
    text: widget.library?.description ?? '',
  );
  late final _prefixesController = TextEditingController(
    text: widget.library?.allowedKeyPrefixes.join(', ') ?? '',
  );
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _prefixesController.dispose();
    super.dispose();
  }

  /// 校验并弹出结果（供外壳保存按钮调用）
  void submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'openai_memoryLibraryNameRequired'.tr);
      return;
    }
    final prefixes = _prefixesController.text
        .split(RegExp(r'[,，\n]'))
        .map((prefix) => prefix.trim())
        .where((prefix) => prefix.isNotEmpty)
        .toSet()
        .toList();
    Navigator.of(context).pop(
      _MemoryLibraryFormResult(
        name: name,
        description: _descriptionController.text.trim(),
        allowedKeyPrefixes: prefixes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: theme.spacing.md),
          DSInput(
            controller: _nameController,
            label: 'openai_memoryLibraryNameLabel'.tr,
            hint: 'openai_memoryLibraryNameHint'.tr,
            errorText: _nameError,
          ),
          SizedBox(height: theme.spacing.md),
          DSInput(
            controller: _descriptionController,
            label: 'openai_memoryLibraryDescriptionLabel'.tr,
            hint: 'openai_memoryLibraryDescriptionHint'.tr,
          ),
          SizedBox(height: theme.spacing.md),
          DSInput(
            controller: _prefixesController,
            label: 'openai_memoryLibraryPrefixLabel'.tr,
            hint: 'openai_memoryLibraryPrefixHint'.tr,
          ),
          SizedBox(height: theme.spacing.md),
        ],
      ),
    );
  }
}

class _MemoryLibraryFormResult {
  const _MemoryLibraryFormResult({
    required this.name,
    required this.description,
    required this.allowedKeyPrefixes,
  });

  final String name;
  final String description;
  final List<String> allowedKeyPrefixes;
}
