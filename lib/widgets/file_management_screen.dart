import 'dart:io';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/utils/file_utils.dart';
import 'package:aboutme/core/utils/zip.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/gallery_viewer.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/text_file_viewer.dart';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

class FileManagementScreen extends StatefulWidget {
  final Directory? rootDirectory;
  final String? title;

  const FileManagementScreen({super.key, this.rootDirectory, this.title});

  @override
  State<FileManagementScreen> createState() => _FileManagementScreenState();
}

class _FileManagementScreenState extends State<FileManagementScreen> {
  Directory? currentDirectory;
  List<FileSystemEntity> files = [];
  Map<String, bool> selectedItems = {};
  Stack<Directory> directoryStack = Stack<Directory>();

  @override
  void initState() {
    super.initState();
    _loadDocumentsDirectory();
  }

  Future<void> _loadDocumentsDirectory() async {
    try {
      final dir =
          widget.rootDirectory ?? await StorageManager.appDataDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      setState(() {
        currentDirectory = dir;
        directoryStack.push(dir);
      });
      await _refreshFiles();
    } catch (e) {
      Toast.error(
        '${'data_management_directoryLoadFailed'.tr}: ${e.toString()}',
      );
      debugPrint('Documents directory load error: ${e.toString()}');
    }
  }

  Future<void> _refreshFiles() async {
    if (currentDirectory == null) return;

    try {
      final items = await currentDirectory!.list().toList();
      setState(() {
        files = items;
        files.sort((a, b) {
          if (a is Directory && b is! Directory) return -1;
          if (a is! Directory && b is Directory) return 1;
          return a.path.compareTo(b.path);
        });
      });
    } catch (e) {
      Toast.error(
        '${'data_management_directoryAccessFailed'.tr}: ${e.toString()}',
      );
      debugPrint('Directory access error: ${e.toString()}');
    }
  }

  void _toggleSelection(String path, bool isDirectory) {
    setState(() {
      if (isDirectory) {
        final dir = Directory(path);
        final children = dir.listSync(recursive: true);
        final allSelected =
            !selectedItems.containsKey(path) || !selectedItems[path]!;

        selectedItems[path] = allSelected;
        for (var child in children) {
          selectedItems[child.path] = allSelected;
        }
      } else {
        selectedItems.update(path, (value) => !value, ifAbsent: () => true);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final selectedPaths = selectedItems.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedPaths.isEmpty) return;

    final confirmed = await showDSDialog<bool>(
      context: context,
      builder: (dialogContext) => DSDialog(
        title: 'data_management_confirmDelete'.tr,
        message: 'data_management_confirmDeleteItems'.trParams({
          'count': selectedPaths.length.toString(),
        }),
        confirmText: 'data_management_delete'.tr,
        cancelText: 'data_management_cancel'.tr,
        confirmVariant: DSButtonVariant.destructive,
      ),
    );

    if (confirmed == true) {
      for (var path in selectedPaths) {
        try {
          // 检查文件/目录是否存在
          final exists =
              await FileSystemEntity.type(path) !=
              FileSystemEntityType.notFound;
          if (!exists) {
            debugPrint('文件不存在，跳过删除: $path');
            continue;
          }
          final entity = FileSystemEntity.isDirectorySync(path)
              ? Directory(path)
              : File(path);
          await entity.delete(recursive: true);
        } catch (e) {
          debugPrint('删除失败 $path: $e');
        }
      }
      setState(() {
        selectedItems.clear();
        _refreshFiles();
      });
      Toast.success('data_management_deleteSuccess'.tr);
    }
  }

  Future<void> _moveSelected() async {
    final selectedPaths = selectedItems.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedPaths.isEmpty) return;

    final appDir =
        widget.rootDirectory ?? await StorageManager.appDataDirectory();
    final targetDir = await showDSDialog<Directory>(
      context: context,
      builder: (dialogContext) => FolderPickerDialog(
        rootDirectory: appDir,
        initialDirectory: currentDirectory ?? appDir,
      ),
    );

    if (targetDir != null) {
      try {
        for (var sourcePath in selectedPaths) {
          final fileName = path.basename(sourcePath);
          final targetPath = path.join(targetDir.path, fileName);
          await File(sourcePath).rename(targetPath);
        }
        setState(() {
          selectedItems.clear();
          _refreshFiles();
        });
        Toast.success('app_moveSuccess'.tr);
      } catch (e) {
        Toast.error('app_moveFailed'.trParams({'error': e.toString()}));
      }
    }
  }

  /// 手绘输入弹窗：新建文件/文件夹与重命名共用（面板 + 输入框 + 按钮）
  Future<String?> _showNameDialog({
    required String title,
    required String hint,
    String? initial,
  }) {
    final nameController = TextEditingController(text: initial ?? '');
    return showDSDialog<String>(
      context: context,
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (dialogContext) {
            final theme = DSThemeBridge.resolve(dialogContext);
            return DsSketchPanel(
              theme: theme,
              radius: theme.radii.xxl,
              padding: EdgeInsets.all(theme.spacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.lg),
                  DSInput(controller: nameController, hint: hint),
                  SizedBox(height: theme.spacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: DSButton(
                          label: 'data_management_cancel'.tr,
                          variant: DSButtonVariant.outline,
                          onPressed: () => Navigator.pop(dialogContext, null),
                        ),
                      ),
                      SizedBox(width: theme.spacing.md),
                      Expanded(
                        child: DSButton(
                          label: 'data_management_create'.tr,
                          onPressed: () =>
                              Navigator.pop(dialogContext, nameController.text),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ).whenComplete(() => nameController.dispose());
  }

  Future<void> _renameItem(String oldPath, bool isDirectory) async {
    final result = await _showNameDialog(
      title: 'data_management_rename'.tr,
      hint: 'data_management_rename'.tr,
      initial: path.basename(oldPath),
    );

    if (result != null && result.isNotEmpty) {
      final newPath = path.join(path.dirname(oldPath), result);
      try {
        if (isDirectory) {
          await Directory(oldPath).rename(newPath);
        } else {
          await File(oldPath).rename(newPath);
        }
        _refreshFiles();
      } catch (e) {
        Toast.error('app_renameFailed'.trParams({'error': e.toString()}));
      }
    }
  }

  void _showContextMenu(String itemPath, bool isDirectory) {
    SmoothBottomSheet.show(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isDirectory)
            SmoothSheetAction(
              icon: DsIconKind.edit,
              label: 'app_edit'.tr,
              onTap: () {
                Navigator.pop(sheetContext);
                // 这里可以添加编辑文件的逻辑
                Toast.show('data_management_editNotImplemented'.tr);
              },
            ),
          SmoothSheetAction(
            icon: DsIconKind.edit,
            label: 'app_rename'.tr,
            onTap: () {
              Navigator.pop(sheetContext);
              _renameItem(itemPath, isDirectory);
            },
          ),
          SizedBox(height: MediaQuery.paddingOf(sheetContext).bottom + 8),
        ],
      ),
    );
  }

  Future<void> _importFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      int successCount = 0;
      int failCount = 0;

      for (var platformFile in result.files) {
        try {
          final file = File(platformFile.path!);
          final targetPath = path.join(
            currentDirectory!.path,
            path.basename(platformFile.name),
          );

          // 覆盖已存在的文件
          if (await File(targetPath).exists()) {
            await File(targetPath).delete();
          }

          await file.copy(targetPath);
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('导入文件失败: ${e.toString()}');
        }
      }

      _refreshFiles();

      Toast.show(
        '${'data_management_importSuccess'.tr}: $successCount, ${'data_management_importFailed'.tr}: $failCount',
      );
    }
  }

  Future<void> _exportSelected() async {
    final selectedPaths = selectedItems.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedPaths.isEmpty) return;

    try {
      // 创建一个临时目录来存储要压缩的文件
      final tempDir = await Directory.systemTemp.createTemp('aboutme_temp_');

      // 复制选中的文件/目录到临时目录
      for (var filePath in selectedPaths) {
        final fileName = path.basename(filePath);
        final targetPath = path.join(tempDir.path, fileName);

        if (FileSystemEntity.isDirectorySync(filePath)) {
          await FileUtils.copyDirectory(
            Directory(filePath),
            Directory(targetPath),
          );
        } else {
          await File(filePath).copy(targetPath);
        }
      }

      // 创建临时 ZIP 文件
      final tempZipPath = '${tempDir.path}/aboutme_export.zip';
      final zipFile = ZipFileEncoder();
      zipFile.create(tempZipPath);

      // 添加所有文件到ZIP
      await for (final entity in tempDir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = path.relative(entity.path, from: tempDir.path);
          await zipFile.addFile(entity, relativePath);
        }
      }

      zipFile.close();
      final savePath = await exportZIP(
        tempZipPath,
        'aboutme_export_${DateTime.now().millisecondsSinceEpoch}.zip',
      );

      if (savePath != null) {
        Toast.success('app_exportSuccessTo'.trParams({'path': savePath}));
      } else {
        Toast.show('app_exportCancelled'.tr);
      }

      // 删除临时目录
      await tempDir.delete(recursive: true);
    } catch (e) {
      Toast.error('${'data_management_exportFailed'.tr}: ${e.toString()}');
      debugPrint('Export error: ${e.toString()}');
      debugPrintStack();
    }
  }

  void _navigateToDirectory(Directory dir) {
    setState(() {
      currentDirectory = dir;
      directoryStack.push(dir);
      _refreshFiles();
    });
  }

  void _navigateUp() {
    if (directoryStack.length > 1) {
      setState(() {
        directoryStack.pop(); // Remove current
        currentDirectory = directoryStack.peek();
        _refreshFiles();
      });
    }
  }

  Future<void> _createNewFile() async {
    final result = await _showNameDialog(
      title: 'data_management_newFile'.tr,
      hint: 'data_management_newFile'.tr,
    );

    if (result != null && result.isNotEmpty) {
      final filePath = path.join(currentDirectory!.path, result);
      await File(filePath).create();
      _refreshFiles();
    }
  }

  Future<void> _createNewFolder() async {
    final result = await _showNameDialog(
      title: 'data_management_newFolder'.tr,
      hint: 'data_management_newFolder'.tr,
    );

    if (result != null && result.isNotEmpty) {
      final dirPath = path.join(currentDirectory!.path, result);
      await Directory(dirPath).create();
      _refreshFiles();
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 可直接阅读的文本类扩展名（含常见代码/配置文件）
  static const _textExtensions = {
    '.txt',
    '.md',
    '.markdown',
    '.json',
    '.xml',
    '.yaml',
    '.yml',
    '.csv',
    '.log',
    '.ini',
    '.conf',
    '.properties',
    '.toml',
    '.sql',
    '.dart',
    '.js',
    '.ts',
    '.jsx',
    '.tsx',
    '.html',
    '.htm',
    '.css',
    '.py',
    '.rb',
    '.go',
    '.rs',
    '.java',
    '.kt',
    '.swift',
    '.c',
    '.h',
    '.cpp',
    '.sh',
  };

  /// 图片扩展名（GalleryViewer 内嵌查看）
  static const _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
  };

  /// 视频扩展名（GalleryViewer 内嵌播放）
  static const _videoExtensions = {
    '.mp4',
    '.mov',
    '.avi',
    '.mkv',
    '.webm',
    '.3gp',
    '.m4v',
  };

  /// 音频扩展名（GalleryViewer 内嵌播放，audioplayers）
  static const _audioExtensions = {
    '.mp3',
    '.m4a',
    '.aac',
    '.wav',
    '.ogg',
    '.flac',
    '.opus',
    '.wma',
  };

  /// 图片 + 视频
  static const _mediaExtensions = {..._imageExtensions, ..._videoExtensions};

  /// 点击文件按类型分发查看：文本 → 查看页；媒体 → 目录相册集
  void _openFile(File file) {
    final ext = path.extension(file.path).toLowerCase();

    if (_textExtensions.contains(ext)) {
      NavigationHelper.push(
        context,
        TextFileViewer(file: file),
        routeName: '/text_file_viewer',
      );
      return;
    }

    if (_mediaExtensions.contains(ext) || _audioExtensions.contains(ext)) {
      _openMediaGallery(file);
    }
    // 其余类型保持原状：点击无操作
  }

  /// 以当前目录内全部图片/视频/音频为相册集打开（列表当前排序顺序），
  /// 横滑连续浏览，初始定位到点击的文件
  void _openMediaGallery(File file) {
    final mediaFiles = files.whereType<File>().where((f) {
      final ext = path.extension(f.path).toLowerCase();
      return _mediaExtensions.contains(ext) || _audioExtensions.contains(ext);
    }).toList();
    final initialIndex = mediaFiles.indexOf(file);
    if (initialIndex < 0) return;

    final photos = [
      for (final f in mediaFiles)
        GalleryPhoto(
          url: f.path,
          caption: path.basename(f.path),
          isVideo: _videoExtensions.contains(
            path.extension(f.path).toLowerCase(),
          ),
          isAudio: _audioExtensions.contains(
            path.extension(f.path).toLowerCase(),
          ),
        ),
    ];

    NavigationHelper.push(
      context,
      GalleryViewer(
        title: path.basename(currentDirectory?.path ?? ''),
        showFileActions: true,
        entranceAnimation: true,
        photos: photos,
        initialIndex: initialIndex,
      ),
      routeName: '/gallery_viewer',
    );
  }

  String get _appBarTitle => directoryStack.length > 1
      ? path.basename(currentDirectory!.path)
      : (widget.title ??
            (currentDirectory != null
                ? path.basename(currentDirectory!.path)
                : 'data_management_dataManagementTitle'.tr));

  @override
  Widget build(BuildContext context) {
    // DS 组件依赖 AppTheme 祖先，通用页面外层自包主题桥（已有树时零开销透传）
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return SuperCupertinoNavigationWrapper(
            title: Text(_appBarTitle),
            enableLargeTitle: false,
            // 目录栈多于一层时返回按钮改为“返回上级目录”
            backButton: directoryStack.length > 1
                ? DSIconButton(
                    icon: DsIconKind.chevronLeft,
                    size: 36,
                    color: theme.surfaceAlt,
                    iconColor: theme.textSub,
                    onPressed: _navigateUp,
                  )
                : null,
            actions: [
              DSIconButton(
                icon: DsIconKind.refresh,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: 'data_management_refresh'.tr,
                onPressed: _refreshFiles,
              ),
              DSIconButton(
                icon: DsIconKind.upload,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: 'data_management_importFiles'.tr,
                onPressed: _importFiles,
              ),
              if (selectedItems.isNotEmpty) ...[
                DSIconButton(
                  icon: DsIconKind.trash,
                  size: 36,
                  color: theme.surfaceAlt,
                  iconColor: theme.danger,
                  tooltip: 'data_management_deleteSelected'.tr,
                  onPressed: _deleteSelected,
                ),
                DSIconButton(
                  icon: DsIconKind.driveFileMove,
                  size: 36,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  tooltip: 'data_management_moveSelected'.tr,
                  onPressed: _moveSelected,
                ),
                DSIconButton(
                  icon: DsIconKind.download,
                  size: 36,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  tooltip: 'data_management_exportSelected'.tr,
                  onPressed: _exportSelected,
                ),
              ],
            ],
            body: Column(
              children: [
                Expanded(
                  child: currentDirectory == null
                      ? Center(
                          child: DSLoadingDots(
                            label: 'data_management_refresh'.tr,
                          ),
                        )
                      : files.isEmpty
                      ? Center(
                          child: DSEmptyState(
                            icon: DsIconKind.folder,
                            title: 'data_management_emptyTitle'.tr,
                            message: 'data_management_emptyMessage'.tr,
                          ),
                        )
                      : HandDrawnListView(
                          itemCount: files.length,
                          // 倾斜角度由文件路径确定性生成，目录内排序后不变
                          tiltKeyOf: (index) => files[index].path,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          itemBuilder: (context, index) =>
                              _buildFileItem(context, files[index]),
                        ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    theme.spacing.lg,
                    theme.spacing.sm,
                    theme.spacing.lg,
                    theme.spacing.sm + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DSButton(
                          icon: DsIconKind.folder,
                          label: 'data_management_newFolder'.tr,
                          onPressed: _createNewFolder,
                        ),
                      ),
                      SizedBox(width: theme.spacing.md),
                      Expanded(
                        child: DSButton(
                          icon: DsIconKind.file,
                          label: 'data_management_newFile'.tr,
                          onPressed: _createNewFile,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 单个文件/目录便签卡片：实底 + 墨线描边，选中态主色淡底 + 主色描边
  Widget _buildFileItem(BuildContext context, FileSystemEntity file) {
    final theme = DSThemeBridge.resolve(context);
    final isDirectory = file is Directory;
    final selected = selectedItems[file.path] ?? false;

    return GestureDetector(
      onTap: () {
        if (isDirectory) {
          _navigateToDirectory(file);
        } else {
          _openFile(file as File);
        }
      },
      onLongPress: () => _showContextMenu(file.path, isDirectory),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.lg,
          vertical: theme.spacing.md,
        ),
        decoration: dsSketchDecoration(
          theme: theme,
          radius: theme.radii.lg,
          fillColor: selected
              ? theme.primary.withValues(alpha: 0.15)
              : theme.surface,
          stroke: selected ? theme.primary : null,
          seed: file.path.hashCode & 0x7fffffff,
        ),
        child: Row(
          children: [
            DsIcon(
              isDirectory ? DsIconKind.folder : DsIconKind.file,
              size: 26,
              color: isDirectory ? theme.warning : theme.textSub,
            ),
            SizedBox(width: theme.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    path.basename(file.path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                  if (!isDirectory) ...[
                    SizedBox(height: 2),
                    Text(
                      _formatFileSize((file as File).lengthSync()),
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            DSCheckbox(
              value: selected,
              onChanged: (_) => _toggleSelection(file.path, isDirectory),
            ),
          ],
        ),
      ),
    );
  }
}

class FolderPickerDialog extends StatefulWidget {
  final Directory rootDirectory;
  final Directory initialDirectory;

  const FolderPickerDialog({
    super.key,
    required this.rootDirectory,
    required this.initialDirectory,
  });

  @override
  State<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<FolderPickerDialog> {
  late Directory currentDirectory;
  List<FileSystemEntity> folders = [];
  bool isLoading = false;
  String? errorMessage;
  final Stack<Directory> directoryStack = Stack<Directory>();

  @override
  void initState() {
    super.initState();
    currentDirectory = widget.initialDirectory;
    directoryStack.push(currentDirectory);
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final items = await currentDirectory.list().toList();
      final dirs = items.whereType<Directory>().toList();
      dirs.sort((a, b) => a.path.compareTo(b.path));

      setState(() {
        folders = [
          Directory('..'), // 特殊项表示跳到上级目录
          ...dirs,
        ];
      });
    } catch (e) {
      setState(() {
        errorMessage =
            '${'data_management_directoryLoadFailed'.tr}: ${e.toString()}';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _navigateTo(Directory dir) async {
    setState(() {
      currentDirectory = dir;
    });
    await _loadFolders();
    directoryStack.push(dir);
  }

  Future<void> _navigateUp() async {
    if (directoryStack.length > 1) {
      directoryStack.pop();
      setState(() {
        currentDirectory = directoryStack.peek();
      });
      await _loadFolders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return DsSketchPanel(
      theme: theme,
      radius: theme.radii.xxl,
      padding: EdgeInsets.all(theme.spacing.lg),
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            path.basename(currentDirectory.path),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: DsTypography.title.copyWith(color: theme.text),
          ),
          SizedBox(height: theme.spacing.md),
          Flexible(
            child: isLoading
                ? Center(child: DSLoadingDots())
                : errorMessage != null
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: theme.spacing.xl),
                    child: Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  )
                : folders.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: theme.spacing.xl),
                    child: Text(
                      'data_management_directoryAccessFailed'.tr,
                      textAlign: TextAlign.center,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: folders.length,
                    itemBuilder: (context, index) =>
                        _buildFolderRow(context, folders[index] as Directory),
                  ),
          ),
          SizedBox(height: theme.spacing.md),
          Row(
            children: [
              Expanded(
                child: DSButton(
                  label: 'app_cancel'.tr,
                  variant: DSButtonVariant.outline,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              SizedBox(width: theme.spacing.md),
              Expanded(
                child: DSButton(
                  label: 'data_management_select'.tr,
                  onPressed: () => Navigator.pop(context, currentDirectory),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFolderRow(BuildContext context, Directory folder) {
    final theme = DSThemeBridge.resolve(context);
    final isUp = folder.path == '..';

    return Pressable(
      onPressed: isUp ? _navigateUp : () => _navigateTo(folder),
      builder: (context, states) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm,
        ),
        color: states.contains(WidgetState.pressed)
            ? theme.surfaceAlt
            : DsColors.transparent,
        child: Row(
          children: [
            DsIcon(
              isUp ? DsIconKind.chevronUp : DsIconKind.folder,
              size: 20,
              color: isUp ? theme.textSub : theme.warning,
            ),
            SizedBox(width: theme.spacing.md),
            Expanded(
              child: Text(
                isUp ? 'data_management_move'.tr : path.basename(folder.path),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsTypography.body.copyWith(color: theme.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Stack<T> {
  final List<T> _items = [];

  void push(T item) => _items.add(item);
  T pop() => _items.removeLast();
  T peek() => _items.last;
  int get length => _items.length;
}
