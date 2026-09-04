import 'dart:convert';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_store_models.dart';
import '../../services/app_store_manager.dart';
import '../../services/download_manager.dart';

/// 应用详情底部抽屉
class AppDetailSheet extends StatefulWidget {
  final MiniApp app;

  const AppDetailSheet({super.key, required this.app});

  @override
  State<AppDetailSheet> createState() => _AppDetailSheetState();
}

class _AppDetailSheetState extends State<AppDetailSheet> {
  List<AppFile>? _files;
  bool _isLoadingFiles = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFileList();
  }

  Future<void> _loadFileList() async {
    setState(() {
      _isLoadingFiles = true;
      _error = null;
    });

    try {
      // 获取对应源的 baseUrl
      final appStoreManager = context.read<AppStoreManager>();
      final source = appStoreManager.sources.firstWhere(
        (s) => s.id == widget.app.sourceId,
        orElse: () => throw Exception('Source not found'),
      );

      // 拼接完整的 URL: {baseUrl}/{filesUrl}
      final fullUrl =
          '${source.baseUrl.replaceAll(RegExp(r'\/+$'), '')}/${widget.app.filesUrl}';

      final response = await http
          .get(Uri.parse(fullUrl))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(
          utf8.decode(response.bodyBytes),
        );
        setState(() {
          _files =
              jsonList
                  .map((json) => AppFile.fromJson(json as Map<String, dynamic>))
                  .toList();
          _isLoadingFiles = false;
        });
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingFiles = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadManager = context.watch<DownloadManager>();

    final totalSize = _files?.fold<int>(0, (sum, file) => sum + file.size) ?? 0;

    // SmoothBottomSheet 内容需自带主题桥
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // 顶部指示器
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.surfaceAlt,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 应用图标和标题
                      Row(
                        children: [
                          _buildAppIcon(widget.app.icon, size: 64),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.app.title,
                                  style: DsTypography.title.copyWith(
                                    color: theme.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Version ${widget.app.version}',
                                  style: DsTypography.caption.copyWith(
                                    color: theme.textSub,
                                  ),
                                ),
                                if (widget.app.author != null) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      DsIcon(
                                        DsIconKind.user,
                                        size: 14,
                                        color: theme.textSub,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.app.author!,
                                        style: DsTypography.caption.copyWith(
                                          color: theme.textSub,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // 描述
                      if (widget.app.desc != null) ...[
                        Text(
                          'Description',
                          style: DsTypography.heading.copyWith(
                            color: theme.text,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.app.desc!,
                          style: DsTypography.body.copyWith(color: theme.text),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 主页按钮
                      if (widget.app.homepage != null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: DSButton(
                            label: 'Visit Homepage',
                            variant: DSButtonVariant.outline,
                            onPressed:
                                () => _openHomepage(widget.app.homepage!),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 标签
                      if (widget.app.tags.isNotEmpty) ...[
                        Text(
                          'Tags',
                          style: DsTypography.heading.copyWith(
                            color: theme.text,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              widget.app.tags
                                  .map((tag) => DSChip(label: tag))
                                  .toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 权限
                      if (widget.app.permissions.isNotEmpty) ...[
                        Text(
                          'Permissions',
                          style: DsTypography.heading.copyWith(
                            color: theme.text,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...widget.app.permissions.map((permission) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                DsIcon(
                                  DsIconKind.check,
                                  size: 16,
                                  color: theme.success,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    permission,
                                    style: DsTypography.body.copyWith(
                                      color: theme.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                      ],

                      // 文件列表
                      Text(
                        'Files',
                        style: DsTypography.heading.copyWith(
                          color: theme.text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingFiles)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: DSLoadingDots(),
                          ),
                        )
                      else if (_error != null)
                        Text(
                          'Error loading files: $_error',
                          style: DsTypography.caption.copyWith(
                            color: theme.danger,
                          ),
                        )
                      else if (_files != null) ...[
                        Text(
                          '${_files!.length} files • ${_formatBytes(totalSize)}',
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.stroke),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _files!.length,
                            itemBuilder: (context, index) {
                              final file = _files![index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        file.path,
                                        style: DsTypography.caption.copyWith(
                                          color: theme.text,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatBytes(file.size),
                                      style: DsTypography.caption.copyWith(
                                        color: theme.textSub,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // 底部按钮
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: theme.stroke)),
                  ),
                  child:
                      widget.app.isInstalled
                          ? Row(
                            children: [
                              Expanded(
                                child: DSButton(
                                  label: 'webview_uninstall'.tr,
                                  variant: DSButtonVariant.outline,
                                  onPressed: () => _confirmUninstall(context),
                                ),
                              ),
                              if (widget.app.hasUpdate) ...[
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DSButton(
                                    label: 'webview_update'.tr,
                                    onPressed:
                                        downloadManager.isInstalling
                                            ? null
                                            : () => _installApp(context),
                                  ),
                                ),
                              ],
                            ],
                          )
                          : SizedBox(
                            width: double.infinity,
                            child: DSButton(
                              label: 'webview_install'.tr,
                              expand: true,
                              onPressed:
                                  downloadManager.isInstalling || _files == null
                                      ? null
                                      : () => _installApp(context),
                            ),
                          ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _installApp(BuildContext context) async {
    final downloadManager = context.read<DownloadManager>();

    // 确认对话框
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder:
                  (dialogContext) => DSDialog(
                    title: 'webview_confirm_install'.tr,
                    message:
                        'This will download ${_files!.length} files (${_formatBytes(_files!.fold<int>(0, (sum, file) => sum + file.size))}).\n\nContinue?',
                    confirmText: 'confirm'.tr,
                    cancelText: 'cancel'.tr,
                    onConfirm: () => Navigator.of(dialogContext).pop(true),
                    onCancel: () => Navigator.of(dialogContext).pop(false),
                  ),
            ),
          ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.pop(context); // 关闭详情页

      try {
        await downloadManager.installApp(widget.app);
        Toast.success('${widget.app.title} installed successfully');
      } catch (e) {
        Toast.error('Installation failed: $e');
      }
    }
  }

  void _confirmUninstall(BuildContext context) async {
    final appStoreManager = context.read<AppStoreManager>();
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder:
                  (dialogContext) => DSDialog(
                    title: 'webview_confirm_uninstall'.tr,
                    message:
                        'Are you sure you want to uninstall ${widget.app.title}?',
                    confirmText: 'webview_uninstall'.tr,
                    cancelText: 'cancel'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                    onConfirm: () => Navigator.of(dialogContext).pop(true),
                    onCancel: () => Navigator.of(dialogContext).pop(false),
                  ),
            ),
          ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.pop(context); // 关闭详情页

      try {
        await appStoreManager.uninstallApp(widget.app.id);
        Toast.success('${widget.app.title} uninstalled');
      } catch (e) {
        Toast.error('Uninstall failed: $e');
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openHomepage(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Toast.error('Cannot open URL: $url');
      }
    } catch (e) {
      Toast.error('Error opening URL: $e');
    }
  }

  /// 构建应用图标（支持网络图片、emoji文本、默认图标）
  Widget _buildAppIcon(String? icon, {double size = 64}) {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        // 判断是否为网络图片 URL
        final bool isNetworkImage =
            icon != null &&
            (icon.startsWith('http://') || icon.startsWith('https://'));

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isNetworkImage ? null : theme.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                isNetworkImage
                    ? Image.network(
                      icon,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: size,
                          height: size,
                          color: theme.surfaceAlt,
                          child: DsIcon(
                            DsIconKind.grid,
                            size: size / 2,
                            color: theme.textSub,
                          ),
                        );
                      },
                    )
                    : icon != null && icon.isNotEmpty
                    ? Center(
                      child: Text(
                        icon,
                        style: TextStyle(fontSize: size * 0.6),
                        textAlign: TextAlign.center,
                      ),
                    )
                    : DsIcon(
                      DsIconKind.grid,
                      size: size / 2,
                      color: theme.textSub,
                    ),
          ),
        );
      },
    );
  }
}
