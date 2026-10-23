part of 'image_picker_dialog.dart';

/// 图片搜索的二级底部弹窗
///
/// 调用工具箱插件的图片搜索小工具按关键词搜网络图片（图源可选），
/// 选中单张 pop `{'url', 'bytes': null}`（与在线 URL 入口同构）；
/// multiple 时多选，确认后 pop 同结构列表。
/// 缩略图直连各引擎 CDN（无代理），加载失败时显示占位图标。
class _ImageSearchSheet extends StatefulWidget {
  final bool multiple;

  const _ImageSearchSheet({this.multiple = false});

  @override
  State<_ImageSearchSheet> createState() => _ImageSearchSheetState();
}

class _ImageSearchSheetState extends State<_ImageSearchSheet> {

  late final TextEditingController _controller;
  final List<String> _providers = ImageSearchService.providers;
  String _provider = 'unsplash';
  bool _searching = false;
  bool _searched = false;
  String? _error;
  List<SearchedImage> _images = [];

  /// 多选模式下已选中的图片下标
  final List<int> _selected = [];

  /// 缩略图字节缓存（key=缩略图 URL），走系统代理下载，
  /// google/bing 等被墙图源的缓存缩略图才能显示（Image.network 不走代理）
  final Map<String, Uint8List> _thumbBytes = {};
  final Set<String> _thumbLoading = {};
  http.Client? _thumbClient;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _thumbClient?.close();
    super.dispose();
  }

  /// 下载缩略图字节（带系统代理，成功后 setState 刷新对应格子）
  Future<void> _loadThumb(String url) async {
    if (url.isEmpty ||
        _thumbBytes.containsKey(url) ||
        _thumbLoading.contains(url)) {
      return;
    }
    _thumbLoading.add(url);
    try {
      _thumbClient ??= await createClientWithSystemProxy();
      final resp = await _thumbClient!
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        _thumbBytes[url] = resp.bodyBytes;
        if (mounted) setState(() {});
      }
    } catch (_) {
      /* 下载失败保持占位图标 */
    } finally {
      _thumbLoading.remove(url);
    }
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _searching) return;

    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final result = await ImageSearchService.instance.search(
        query: query,
        provider: _provider,
        perPage: 30,
      );
      if (!mounted) return;
      if (!result.success) {
        setState(() {
          _images = [];
          _selected.clear();
          _searched = true;
          _error = result.error ?? 'image_picker_searchFailed'.tr;
        });
        return;
      }
      // 服务返回：{success, message, data: {images: [SearchedImage...]}}
      setState(() {
        _images = List<SearchedImage>.from(result.data?['images'] ?? []);
        _selected.clear();
        _searched = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _images = [];
          _selected.clear();
          _searched = true;
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _onTapImage(int index) {
    final url = _images[index].url;
    if (url.isEmpty) return;
    if (!widget.multiple) {
      Navigator.of(context).pop(<String, dynamic>{'url': url, 'bytes': null});
      return;
    }
    setState(() {
      _selected.contains(index)
          ? _selected.remove(index)
          : _selected.add(index);
    });
  }

  void _confirmMultiple() {
    final results = <Map<String, dynamic>>[
      for (final i in _selected)
        if (_images[i].url.isNotEmpty) {'url': _images[i].url, 'bytes': null},
    ];
    if (results.isNotEmpty) Navigator.of(context).pop(results);
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Sheet(
      // 网格滚到顶后再向下拖才会收起弹窗
      scrollConfiguration: const SheetScrollConfiguration(),
      decoration: MaterialSheetDecoration(
        size: SheetSize.fit,
        color: theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: theme.spacing.lg),
            Text(
              'image_picker_searchImage'.tr,
              textAlign: TextAlign.center,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
            SizedBox(height: theme.spacing.md),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: DSInput(
                      controller: _controller,
                      hint: 'image_picker_searchHint'.tr,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DSButton(
                    label: 'image_picker_search'.tr,
                    size: DSButtonSize.sm,
                    onPressed: _searching ? null : _search,
                  ),
                ],
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            // 图源横滑选择
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
                children: [
                  for (final p in _providers)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: DSChip(
                        label: p,
                        selected: _provider == p,
                        onSelected: (_) => setState(() => _provider = p),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            SizedBox(height: screenHeight * 0.5, child: _buildBody(theme)),
            if (widget.multiple) _buildConfirmBar(theme),
            SafeArea(top: false, child: SizedBox(height: theme.spacing.sm)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppThemeData theme) {
    if (_searching) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
          child: Text(
            '${'image_picker_searchFailed'.tr}\n$_error',
            textAlign: TextAlign.center,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ),
      );
    }
    if (_images.isEmpty) {
      return Center(
        child: Text(
          _searched
              ? 'image_picker_searchEmpty'.tr
              : 'image_picker_searchHint'.tr,
          style: DsTypography.caption.copyWith(color: theme.textSub),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 110,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) => _buildResultTile(theme, index),
    );
  }

  /// 缩略图格子内容：已下载则 Image.memory，否则触发代理下载并显示占位
  Widget _buildThumb(AppThemeData theme, String url) {
    final bytes = _thumbBytes[url];
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _thumbPlaceholder(theme),
      );
    }
    // 幂等：已在缓存/请求中的 URL 直接跳过，下载成功后 setState 刷新
    _loadThumb(url);
    return _thumbPlaceholder(theme);
  }

  Widget _thumbPlaceholder(AppThemeData theme) {
    return Container(
      color: theme.stroke,
      child: Center(
        child: DsIcon(DsIconKind.image, size: 22, color: theme.textSub),
      ),
    );
  }

  Widget _buildResultTile(AppThemeData theme, int index) {
    final img = _images[index];
    final thumb = img.thumb.isNotEmpty ? img.thumb : img.url;
    final isSelected = _selected.contains(index);
    final selectedIndex = _selected.indexOf(index) + 1;

    return GestureDetector(
      onTap: () => _onTapImage(index),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: theme.radii.md,
          border: isSelected
              ? Border.all(color: theme.primary, width: 2)
              : null,
        ),
        child: ClipRRect(
          borderRadius: theme.radii.md,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildThumb(theme, thumb),
              if (widget.multiple)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? theme.primary
                          : Colors.black.withValues(alpha: 0.25),
                      border: isSelected
                          ? null
                          : Border.all(color: Colors.white70),
                    ),
                    child: Center(
                      // 未选中时角标为空圈，不显示序号（避免 indexOf(-1)+1 显示 0）
                      child: isSelected
                          ? Text(
                              '$selectedIndex',
                              style: DsTypography.caption.copyWith(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 多选确认栏：左侧已选缩略图横滑条（右上 × 移除、长按拖拽排序）
  /// + 右侧确认按钮
  Widget _buildConfirmBar(AppThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 60,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                itemCount: _selected.length,
                onReorder: _onReorderSelected,
                itemBuilder: (context, index) {
                  final imgIndex = _selected[index];
                  final img = _images[imgIndex];
                  final thumbUrl = img.thumb.isNotEmpty ? img.thumb : img.url;
                  return Padding(
                    key: ValueKey(imgIndex),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: theme.radii.sm,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: _buildThumb(theme, thumbUrl),
                          ),
                        ),
                        // 左下序号
                        Positioned(
                          left: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: DsTypography.caption.copyWith(
                                color: Colors.white,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ),
                        // 右上取消图标（点 × 移除该图）
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selected.remove(index)),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.text,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: DsIcon(
                                  DsIconKind.close,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          DSButton(
            label: 'app_confirm'.tr,
            size: DSButtonSize.sm,
            onPressed: _selected.isEmpty ? null : _confirmMultiple,
          ),
        ],
      ),
    );
  }

  /// 拖拽排序回调：调整已选顺序（元素为结果下标）
  void _onReorderSelected(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _selected.removeAt(oldIndex);
      _selected.insert(newIndex, item);
    });
  }
}
