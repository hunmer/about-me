import 'dart:io';

import 'package:flutter/material.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/moments/models/agent_asset.dart';
import 'package:aboutme/plugins/openai/moments/services/agent_assets_service.dart';
import 'package:aboutme/plugins/openai/moments/services/image_gen_service.dart';
import 'package:aboutme/plugins/openai/moments/widgets/photo_viewer_screen.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';

/// Agent 资产图管理：占位生成 / 上传命名 / 图生图
class AgentAssetsScreen extends StatefulWidget {
  final String agentId;
  final String agentName;

  const AgentAssetsScreen({
    super.key,
    required this.agentId,
    required this.agentName,
  });

  @override
  State<AgentAssetsScreen> createState() => _AgentAssetsScreenState();
}

class _AgentAssetsScreenState extends State<AgentAssetsScreen> {
  final _assetsService = AgentAssetsService.instance;
  List<AgentAsset> _assets = [];
  final Set<String> _generating = {}; // 正在生成的资产 id

  String get _archiveDir => '${AgentAssetsService.assetsDir}/${widget.agentId}';

  @override
  void initState() {
    super.initState();
    _assetsService.addListener(_onChanged);
    _assetsService.ensureDefaults(widget.agentId).then((assets) {
      if (mounted) setState(() => _assets = assets);
    });
  }

  @override
  void dispose() {
    _assetsService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final cached = _assetsService.cached(widget.agentId);
    if (mounted && cached != null) setState(() => _assets = List.of(cached));
  }

  /// agent 人设描述（生图时附加，保证形象贴合）
  Future<String> _personaSuffix() async {
    try {
      final agent = await AgentController().getAgent(widget.agentId);
      if (agent != null && agent.description.trim().isNotEmpty) {
        return '\n\n角色设定：${agent.name}，${agent.description.trim()}';
      }
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.agentName} 的资产图'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        child: const Icon(Icons.add),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemCount: _assets.length,
        itemBuilder: (context, index) => _buildAssetCard(theme, _assets[index]),
      ),
    );
  }

  Widget _buildAssetCard(ThemeData theme, AgentAsset asset) {
    final isGenerating = _generating.contains(asset.id);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: isGenerating ? null : () => _showAssetSheet(asset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (asset.hasImage)
                  FutureBuilder<String>(
                    future: ImageUtils.getAbsolutePath(asset.path),
                    builder: (context, snapshot) {
                      if (snapshot.hasData &&
                          snapshot.data!.isNotEmpty &&
                          File(snapshot.data!).existsSync()) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(snapshot.data!),
                            fit: BoxFit.cover,
                          ),
                        );
                      }
                      return _placeholderBox(theme);
                    },
                  )
                else
                  _placeholderBox(theme),
                if (isGenerating)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.black38,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            asset.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          Text(
            isGenerating
                ? '生成中…'
                : asset.hasImage
                ? '点击管理'
                : '未生成 · 点击创建',
            maxLines: 1,
            style: TextStyle(fontSize: 10, color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  Widget _placeholderBox(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor,
          width: 1.2,
        ),
        color: theme.disabledColor.withValues(alpha: 0.08),
      ),
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: theme.hintColor.withValues(alpha: 0.6),
      ),
    );
  }

  // ---------- 添加 ----------

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('上传照片'),
                  subtitle: const Text('从相册/本地选择，可命名'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUpload();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: const Text('新建占位'),
                  subtitle: const Text('定义名称与生成提示词，稍后用 AI 生成'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showCreatePlaceholderDialog();
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _pickAndUpload() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => ImagePickerDialog(
            saveDirectory: _archiveDir,
            enableCompression: true,
            compressionQuality: 88,
          ),
    );
    if (result == null || result['url'] == null) return;
    final name = await _promptText(
      title: '命名照片',
      hint: '如：三视图、房间照片',
    );
    if (name == null || name.trim().isEmpty) return;
    await _assetsService.addAsset(
      agentId: widget.agentId,
      name: name.trim(),
      path: result['url'] as String,
    );
  }

  Future<void> _showCreatePlaceholderDialog() async {
    final name = await _promptText(title: '资产名称', hint: '如：三视图、房间照片');
    if (name == null || name.trim().isEmpty) return;
    final prompt = await _promptText(
      title: '生成提示词',
      hint: '描述这张图的样子，生成时会自动附加 TA 的人设',
    );
    if (prompt == null) return;
    await _assetsService.addAsset(
      agentId: widget.agentId,
      name: name.trim(),
      prompt: prompt.trim(),
    );
  }

  // ---------- 资产操作 ----------

  void _showAssetSheet(AgentAsset asset) {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    asset.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (asset.hasImage)
                  ListTile(
                    leading: const Icon(Icons.fullscreen),
                    title: const Text('查看大图'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => PhotoViewerScreen(
                                imageRelativePaths: [asset.path!],
                              ),
                        ),
                      );
                    },
                  ),
                if (!asset.hasImage)
                  ListTile(
                    leading: const Icon(Icons.auto_awesome),
                    title: const Text('生成图片'),
                    subtitle: const Text('按提示词生成，自动附加 TA 的人设'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showGenerateDialog(asset);
                    },
                  )
                else ...[
                  ListTile(
                    leading: const Icon(Icons.transform),
                    title: const Text('以此图生成（图生图）'),
                    subtitle: const Text('以这张图为参考生成新图'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showImg2ImgDialog(asset);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.refresh),
                    title: const Text('重新生成'),
                    subtitle: const Text('覆盖当前图片'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showGenerateDialog(asset, overwrite: true);
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.drive_file_rename_outline),
                  title: Text(asset.hasImage ? '重命名' : '编辑名称与提示词'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditAssetDialog(asset);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('删除', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _assetsService.deleteAsset(
                      agentId: widget.agentId,
                      assetId: asset.id,
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _showGenerateDialog(
    AgentAsset asset, {
    bool overwrite = false,
  }) async {
    final prompt = await _promptText(
      title: overwrite ? '重新生成「${asset.name}」' : '生成「${asset.name}」',
      hint: '生成提示词',
      initial: asset.prompt,
    );
    if (prompt == null || prompt.trim().isEmpty) return;
    await _runGenerate(
      asset: asset,
      prompt: prompt.trim(),
      refPath: null,
      overwrite: overwrite || !asset.hasImage,
    );
  }

  Future<void> _showImg2ImgDialog(AgentAsset asset) async {
    final prompt = await _promptText(
      title: '以「${asset.name}」为参考生成',
      hint: '描述想要的变换，如：换一套秋装、在咖啡店里',
    );
    if (prompt == null || prompt.trim().isEmpty) return;
    await _runGenerate(
      asset: asset,
      prompt: prompt.trim(),
      refPath: asset.path,
      overwrite: false,
    );
  }

  Future<void> _runGenerate({
    required AgentAsset asset,
    required String prompt,
    String? refPath,
    required bool overwrite,
  }) async {
    setState(() => _generating.add(asset.id));
    try {
      final refPaths = <String>[];
      if (refPath != null) {
        final abs = await ImageUtils.getAbsolutePath(refPath);
        if (abs.isNotEmpty && File(abs).existsSync()) refPaths.add(abs);
      }
      final images = await ImageGenService.instance.generate(
        prompt: '$prompt${await _personaSuffix()}',
        refImageAbsolutePaths: refPaths,
        archiveDir: _archiveDir,
      );
      if (images.isEmpty) throw Exception('未返回图片');
      if (!mounted) return;
      if (overwrite) {
        await _assetsService.updateAsset(
          agentId: widget.agentId,
          assetId: asset.id,
          path: images.first,
        );
        ToastService.instance.showToast('已生成「${asset.name}」');
      } else {
        // 图生图结果：存为新资产（命名）
        final name = await _promptText(
          title: '生成成功，为新图命名',
          hint: '如：${asset.name}·新',
        );
        if (name != null && name.trim().isNotEmpty) {
          await _assetsService.addAsset(
            agentId: widget.agentId,
            name: name.trim(),
            path: images.first,
          );
          ToastService.instance.showToast('已保存「${name.trim()}」');
        }
      }
    } catch (e) {
      if (mounted) ToastService.instance.showToast('生成失败: $e');
    } finally {
      if (mounted) setState(() => _generating.remove(asset.id));
    }
  }

  Future<void> _showEditAssetDialog(AgentAsset asset) async {
    final name = await _promptText(
      title: '重命名',
      hint: '资产名称',
      initial: asset.name,
    );
    if (name == null || name.trim().isEmpty) return;
    var prompt = asset.prompt;
    if (!asset.hasImage) {
      final p = await _promptText(
        title: '生成提示词',
        hint: '留空保持不变',
        initial: asset.prompt,
      );
      if (p != null && p.trim().isNotEmpty) prompt = p.trim();
    }
    await _assetsService.updateAsset(
      agentId: widget.agentId,
      assetId: asset.id,
      name: name.trim(),
      prompt: prompt,
    );
  }

  /// 单行文本输入对话框；返回 null 表示取消
  Future<String?> _promptText({
    required String title,
    String? hint,
    String initial = '',
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(hintText: hint),
              autofocus: true,
              maxLines: 3,
              minLines: 1,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: const Text('确定'),
              ),
            ],
          ),
    );
  }
}
