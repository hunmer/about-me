import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/utils/network.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/toolbox/controllers/image_search_controller.dart';
import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/plugins/toolbox/services/image_search_service.dart';
import 'package:aboutme/plugins/toolbox/widgets/toolbox_config_sheet.dart';
import 'package:aboutme/widgets/gallery_viewer.dart';
import 'package:aboutme/core/data/sdk_media_service.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 图片搜索小工具独立界面
///
/// 关键词搜图（Unsplash/Pixabay/Google/Bing/Yahoo/Yandex）
/// + 以图搜图（Google Lens）；缩略图走系统代理下载。
class ImageSearchScreen extends StatefulWidget {
  const ImageSearchScreen({super.key});

  @override
  State<ImageSearchScreen> createState() => _ImageSearchScreenState();
}

class _ImageSearchScreenState extends State<ImageSearchScreen> {
  final _controller = ImageSearchController();
  final _queryNode = FocusNode();
  final _urlNode = FocusNode();
  final _inputController = TextEditingController();
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.loadHistory();
    // 搜索完成后预热缩略图
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.preloadThumbs();
    });
  }

  void _onChanged() {
    setState(() {});
    if (_controller.images.isNotEmpty) {
      _controller.preloadThumbs();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputController.dispose();
    _queryNode.dispose();
    _urlNode.dispose();
    super.dispose();
  }

  void _openSettings() {
    final service = ImageSearchService.instance;
    ToolboxConfigSheet.show(
      context,
      title: 'toolbox_imageSearch_settings'.tr,
      fields: service.configFields,
      config: service.config,
      onSave: service.saveConfig,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final c = _controller;

    return SuperCupertinoNavigationWrapper(
      title: Text('toolbox_imageSearch_name'.tr),
      largeTitle: 'toolbox_imageSearch_name'.tr,
      actions: [
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.gear,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: 'toolbox_settings'.tr,
                onPressed: _openSettings,
              );
            },
          ),
        ),
      ],
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // 模式切换 + 输入行
            Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
              child: Column(
                children: [
                  SizedBox(height: theme.spacing.sm),
                  Row(
                    children: [
                      DSChip(
                        label: 'toolbox_searchByKeyword'.tr,
                        selected: c.mode == 'keyword',
                        onSelected: (_) => setState(() {
                          c.setMode('keyword');
                          _inputController.clear();
                        }),
                      ),
                      const SizedBox(width: 8),
                      DSChip(
                        label: 'toolbox_searchByImage'.tr,
                        selected: c.mode == 'lens',
                        onSelected: (_) => setState(() {
                          c.setMode('lens');
                          _inputController.clear();
                        }),
                      ),
                    ],
                  ),
                  SizedBox(height: theme.spacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: DSInput(
                          controller: _inputController,
                          focusNode: c.mode == 'keyword'
                              ? _queryNode
                              : _urlNode,
                          hint: c.mode == 'keyword'
                              ? 'toolbox_searchHint'.tr
                              : 'toolbox_imageUrlHint'.tr,
                          keyboardType: c.mode == 'keyword'
                              ? TextInputType.text
                              : TextInputType.url,
                          textInputAction: TextInputAction.search,
                          onChanged: (v) => setState(() {
                            if (c.mode == 'keyword') {
                              c.query = v;
                            } else {
                              c.imageUrl = v;
                            }
                          }),
                          onSubmitted: (_) => c.search(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DSButton(
                        label: 'toolbox_search'.tr,
                        size: DSButtonSize.sm,
                        loading: c.searching,
                        onPressed: c.searching ? null : c.search,
                      ),
                    ],
                  ),
                  SizedBox(height: theme.spacing.sm),
                ],
              ),
            ),
            // 图源横滑（关键词模式）
            if (c.mode == 'keyword')
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
                  children: [
                    for (final p in ImageSearchService.providers)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: DSChip(
                          label: p,
                          selected: c.provider == p,
                          onSelected: (_) => c.setProvider(p),
                        ),
                      ),
                  ],
                ),
              ),
            // 筛选展开/收起
            if (c.mode == 'keyword')
              Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _showFilters = !_showFilters),
                      icon: Icon(
                        _showFilters ? Icons.expand_less : Icons.tune,
                        size: 18,
                        color: theme.textSub,
                      ),
                      label: Text(
                        'toolbox_filters'.tr,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_showFilters && c.mode == 'keyword') _buildFilters(theme),
            Divider(height: 1, color: theme.stroke),
            // 结果区
            Expanded(child: _buildResults(theme)),
          ],
        ),
      ),
    );
  }

  /// 高级筛选：数量 / 类型(pixabay) / 方向 / 排序
  Widget _buildFilters(AppThemeData theme) {
    final c = _controller;
    final isPixabay = c.provider == 'pixabay';
    final isMagnific = c.provider == 'magnific';
    final supportsOrientation = c.provider == 'unsplash' || isPixabay;
    final supportsSort = c.provider == 'unsplash' || isPixabay;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _filterRow(theme, 'toolbox_perPage', [
            for (final n in const [10, 20, 30])
              DSChip(
                label: '$n',
                selected: c.perPage == n,
                onSelected: (_) => c.setPerPage(n),
              ),
          ]),
          // magnific 仅支持 photo/vector 两种类型
          if (isPixabay || isMagnific)
            _filterRow(theme, 'toolbox_imageType', [
              for (final t in (isMagnific
                  ? const ['photo', 'vector']
                  : const ['photo', 'illustration', 'vector', 'all']))
                DSChip(
                  label: 'toolbox_imageType_$t'.tr,
                  selected: c.imageType == t,
                  onSelected: (_) => c.setImageType(t),
                ),
            ]),
          if (supportsOrientation)
            _filterRow(theme, 'toolbox_orientation', [
              for (final o in const [
                'any',
                'landscape',
                'portrait',
                'squarish',
                'horizontal',
                'vertical',
              ])
                if (c.provider != 'pixabay' || o != 'squarish')
                  DSChip(
                    label: o,
                    selected: c.orientation == o,
                    onSelected: (_) => c.setOrientation(o),
                  ),
            ]),
          if (supportsSort)
            _filterRow(theme, 'toolbox_sort', [
              for (final s in const ['relevant', 'popular', 'latest'])
                DSChip(
                  label: 'toolbox_sort_$s'.tr,
                  selected: c.sort == s,
                  onSelected: (_) => c.setSort(s),
                ),
            ]),
          SizedBox(height: theme.spacing.sm),
        ],
      ),
    );
  }

  Widget _filterRow(AppThemeData theme, String label, List<Widget> chips) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                label.tr,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ),
            for (final chip in chips) ...[chip, const SizedBox(width: 6)],
          ],
        ),
      ),
    );
  }

  /// 最近搜索列表（未搜索时的初始状态）：点击回填重搜，长按删除单条
  Widget _buildHistoryList(AppThemeData theme) {
    final c = _controller;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'toolbox_recentSearches'.tr,
                style: DsTypography.title.copyWith(color: theme.text),
              ),
              TextButton(
                onPressed: () async {
                  await c.clearHistory();
                  if (context.mounted) setState(() {});
                },
                child: Text(
                  'toolbox_clearHistory'.tr,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ),
            ],
          ),
        ),
        // 图源过滤 chips（历史中出现过的图源）
        if (c.historyProviders.length > 1)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: DSChip(
                    label: 'toolbox_filterAll'.tr,
                    selected: c.historyFilter == null,
                    onSelected: (_) => c.setHistoryFilter(null),
                  ),
                ),
                for (final p in c.historyProviders)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: DSChip(
                      label: p == 'google_lens' ? 'Google Lens' : p,
                      selected: c.historyFilter == p,
                      onSelected: (_) => c.setHistoryFilter(p),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: c.filteredHistory.isEmpty
              ? Center(
                  child: Text(
                    'toolbox_noResults'.tr,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                )
              : ListView.builder(
                  itemCount: c.filteredHistory.length,
                  itemBuilder: (context, index) {
                    final entry = c.filteredHistory[index];
                    final isLens = entry['mode'] == 'lens';
                    final text = isLens
                        ? (entry['imageUrl'] as String? ?? '')
                        : (entry['query'] as String? ?? '');
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isLens ? Icons.image_search : Icons.history,
                        size: 20,
                        color: theme.textSub,
                      ),
                      title: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsTypography.body.copyWith(color: theme.text),
                      ),
                      trailing: Text(
                        isLens
                            ? 'Google Lens'
                            : (entry['provider'] as String? ?? ''),
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                      onTap: () async {
                        await c.searchFromHistory(entry);
                        // 回填输入框显示
                        _inputController.text = text;
                        if (context.mounted) setState(() {});
                      },
                      onLongPress: () async {
                        await c.removeHistory(entry);
                        if (context.mounted) setState(() {});
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildResults(AppThemeData theme) {
    final c = _controller;

    if (c.searching) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (c.error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.xl),
          child: Text(
            c.error!,
            style: DsTypography.body.copyWith(color: theme.danger),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!c.searched) {
      if (c.history.isEmpty) {
        return DSEmptyState(emoji: '🔍', title: 'toolbox_searchEmpty'.tr);
      }
      return _buildHistoryList(theme);
    }
    if (c.images.isEmpty) {
      return DSEmptyState(emoji: '🖼️', title: 'toolbox_noResults'.tr);
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.lg,
            vertical: theme.spacing.xs,
          ),
          child: Text(
            c.lastMessage,
            style: DsTypography.caption.copyWith(color: theme.textSub),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.md),
            itemCount: c.images.length,
            itemBuilder: (context, index) => _buildImageItem(theme, index),
          ),
        ),
        if (c.canPaging)
          Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DSButton(
                  label: 'toolbox_prevPage'.tr,
                  variant: DSButtonVariant.outline,
                  size: DSButtonSize.sm,
                  onPressed: c.page > 1 ? c.prevPage : null,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: theme.spacing.md),
                  child: Text(
                    '${c.page}',
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                ),
                DSButton(
                  label: 'toolbox_nextPage'.tr,
                  variant: DSButtonVariant.outline,
                  size: DSButtonSize.sm,
                  onPressed: c.images.length >= c.perPage ? c.nextPage : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 点击搜索结果：GalleryViewer 全屏查看本批图片（Hero 飞行转场）
  void _openImageViewer(int index) {
    final images = _controller.images;
    NavigationHelper.push(
      context,
      GalleryViewer(
        title: 'toolbox_image_search_name'.tr,
        photos: [
          for (final img in images)
            GalleryPhoto(url: img.url, caption: img.credit),
        ],
        initialIndex: index,
        // 搜索引擎图源原图直链多被墙，查看器内走系统代理下载
        networkViaProxy: true,
      ),
    );
  }

  /// 长按搜索结果：保存图片 / 复制图片 URL / 复制落地页 URL
  void _onLongPressImage(SearchedImage img) {
    SmoothBottomSheet.show(
      context: context,
      builder: (context) => _ImageActionsSheet(
        imageUrl: img.url,
        // pixabay 的 large 为 1280px 原图，保存优先用大图
        downloadUrl: img.large.isNotEmpty ? img.large : img.url,
        pageUrl: img.pageUrl,
      ),
    );
  }

  /// 以图搜图/搜索引擎结果：缩略图横排；图库结果：大图竖排。
  /// 两种布局的图片区均可点击进查看器（Hero tag 与查看器同 url）。
  Widget _buildImageItem(AppThemeData theme, int index) {
    final img = _controller.images[index];
    final compact =
        img.source == 'google_lens' ||
        ImageSearchService.isSerpProvider(img.source);
    final thumbUrl = img.thumb.isNotEmpty ? img.thumb : img.url;

    final image = _proxyImage(
      thumbUrl,
      width: compact ? 72.0 : null,
      height: compact ? 72.0 : 200.0,
      bigFit: !compact,
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _openImageViewer(index),
              onLongPress: () => _onLongPressImage(img),
              child: Hero(
                tag: img.url,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: image,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    img.description.isEmpty
                        ? '(无标题)'
                        : _clip(img.description, 80),
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                  if (img.credit.isNotEmpty)
                    Text(
                      img.credit,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  if (img.pageUrl.isNotEmpty)
                    Text(
                      _clip(img.pageUrl, 70),
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openImageViewer(index),
            onLongPress: () => _onLongPressImage(img),
            child: Hero(
              tag: img.url,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _proxyImage(img.url, bigFit: true),
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (img.credit.isNotEmpty)
            Text(
              img.credit,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          if (img.description.isNotEmpty)
            Text(
              _clip(img.description, 60),
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
        ],
      ),
    );
  }

  /// 走系统代理的缩略图（Image.network 不走代理，被墙图源显示不出来）
  Widget _proxyImage(
    String url, {
    double? width,
    double? height,
    bool bigFit = false,
  }) {
    _controller.loadThumb(url);
    final bytes = _controller.thumbBytes[url];
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: bigFit ? BoxFit.fitWidth : BoxFit.cover,
      );
    }
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  static String _clip(String text, int max) =>
      text.length > max ? text.substring(0, max) : text;
}

/// 搜索结果长按操作单：保存图片（走系统代理下载）/ 复制图片 URL / 复制落地页
class _ImageActionsSheet extends StatelessWidget {
  final String imageUrl;

  /// 保存用的直链（pixabay 优先 1280px 原图）
  final String downloadUrl;
  final String pageUrl;

  const _ImageActionsSheet({
    required this.imageUrl,
    required this.downloadUrl,
    required this.pageUrl,
  });

  Future<void> _saveImage(BuildContext context) async {
    Navigator.of(context).pop();
    if (downloadUrl.isEmpty) {
      Toast.warning('toolbox_saveFailed'.tr);
      return;
    }
    Toast.info('toolbox_saving'.tr);
    try {
      final client = await createClientWithSystemProxy();
      try {
        final resp = await client
            .get(Uri.parse(downloadUrl))
            .timeout(const Duration(seconds: 60));
        if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
          throw Exception('HTTP ${resp.statusCode}');
        }
        // 保存为 SDK 资源（文件名取 URL 尾段，无扩展名时按时间戳命名）
        var name = downloadUrl.split('/').last.split('?').first;
        if (!name.contains('.')) {
          name = 'image_search_${DateTime.now().millisecondsSinceEpoch}.jpg';
        }
        final asset = await SdkMediaService.uploadBytes(resp.bodyBytes, name);
        Toast.success('${'toolbox_savedTo'.tr} ${asset.reference}');
      } finally {
        client.close();
      }
    } catch (e) {
      Toast.error('${'toolbox_saveFailed'.tr}: $e');
    }
  }

  Future<void> _copy(BuildContext context, String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) Navigator.of(context).pop();
    Toast.success(label);
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: theme.spacing.md),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text('toolbox_saveImage'.tr),
            onTap: () => _saveImage(context),
          ),
          if (imageUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.link),
              title: Text('toolbox_copyImageUrl'.tr),
              subtitle: Text(
                imageUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _copy(context, imageUrl, 'toolbox_copied'.tr),
            ),
          if (pageUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text('toolbox_copyPageUrl'.tr),
              subtitle: Text(
                pageUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _copy(context, pageUrl, 'toolbox_copied'.tr),
            ),
          SizedBox(height: theme.spacing.sm),
        ],
      ),
    );
  }
}
