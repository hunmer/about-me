import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

import 'emoji.dart';
import 'emoji_category.dart';
import 'emoji_controller.dart';

/// 内置分组类型（[EmojiPicker.types] 的合法值）：
/// emoji = Unicode 表情，image = 内置图片表情，svg = 内置 SVG 贴纸
const String kEmojiPickerTypeEmoji = 'emoji';
const String kEmojiPickerTypeImage = 'image';
const String kEmojiPickerTypeSvg = 'svg';

/// 内置资源在 Emoji.value 中的标记前缀（后接 asset 路径），
/// 消费方据此区分 Unicode 表情与内置资源（svg/图片）
const String kBuiltInEmojiPrefix = 'aboutme_emoji:';

/// 内置图片表情资源目录（assets/emojis，PNG/GIF/WebP）
const String kBuiltInEmojiAssetDir = 'assets/emojis';

/// 方块表情资源目录（assets/emoji_faces，透明 WebP）
const String kEmojiFaceAssetDir = 'assets/emoji_faces';

/// 内置 SVG 贴纸资源目录（assets/svg/items）
const String kSvgAssetDir = 'assets/svg/items';

/// 手绘风表情选择器（原 packages/material_emoji_picker 迁为内部组件）
///
/// 搜索框 + 分类 chip 横滚条 + 表情网格；滚动时选中分类自动跟随，
/// 点击 chip 反向滚动到对应分区。自定义分类通过
/// [prependCategories]/[appendCategories] 注入（内置表情包/贴图合集）。
/// [types] 控制开启的内置分组（emoji/image/svg），内置资源分组的
/// 选中值为 `$kBuiltInEmojiPrefix<asset 路径>`。
///
/// 需要 ProviderScope 祖先（EmojiController 为 riverpod AsyncNotifier）。
class EmojiPicker extends ConsumerStatefulWidget {
  const EmojiPicker({
    super.key,
    this.prependCategories = const IList.empty(),
    this.appendCategories = const IList.empty(),
    this.types = const [kEmojiPickerTypeEmoji],
    required this.onSelection,
    this.allowFreeText = false,
  });

  final IList<EmojiCategory> prependCategories;
  final IList<EmojiCategory> appendCategories;

  /// 开启显示的内置分组类型（[kEmojiPickerTypeEmoji] 等），缺省仅 Unicode 表情
  final List<String> types;

  /// 选中回调：(表情值或搜索文本, 是否自由文本)
  final FutureOr<void> Function(String value, bool isFreeText) onSelection;

  /// 允许把搜索文本作为自由文本提交（搜索框尾部出现发送按钮）
  final bool allowFreeText;

  @override
  ConsumerState<EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends ConsumerState<EmojiPicker> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _categoryScrollController = ScrollController();
  final _scrollViewKey = GlobalKey();

  String _search = '';
  int _selectedCategory = 0;

  /// 合并后的分类列表，与分区锚点/chip 的 GlobalKey 同步重建
  IList<EmojiCategory> _combined = const IList.empty();
  List<GlobalKey> _headerKeys = const [];
  List<GlobalKey> _chipKeys = const [];

  /// [widget.types] 开启的内置资源分组（svg/图片），异步加载
  IList<EmojiCategory> _builtinCategories = const IList.empty();

  /// 内置图片表情支持的扩展名
  static const _imageExts = ['.png', '.gif', '.webp'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncSelectedCategoryWithScroll);
    _loadBuiltinCategories();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_syncSelectedCategoryWithScroll);
    _scrollController.dispose();
    _categoryScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 滚动时把选中分类同步为视口顶部分区，并让 chip 条滚动到可见
  Future<void> _syncSelectedCategoryWithScroll() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final viewport = _scrollViewKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox) return;

    final selectedIndex = _headerKeys.lastIndexWhere((headerKey) {
      final renderObject = headerKey.currentContext?.findRenderObject();
      if (renderObject is! RenderBox) return false;

      final top = renderObject
          .localToGlobal(Offset.zero, ancestor: viewport)
          .dy;
      return top <= 20;
    });

    if (selectedIndex != _selectedCategory) {
      setState(() => _selectedCategory = selectedIndex);
      final chipContext = _chipKeys[selectedIndex].currentContext;
      if (chipContext != null && chipContext.mounted) {
        await Scrollable.ensureVisible(
          chipContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0,
        );
      }
    }
  }

  void _selectCategory(int index) {
    setState(() => _selectedCategory = index);
    final headerContext = _headerKeys[index].currentContext;
    if (headerContext != null) {
      Scrollable.ensureVisible(
        headerContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0,
      );
    }
  }

  /// 加载 [widget.types] 开启的内置资源分组（svg 贴纸 / 方块表情 / 内置表情），
  /// 排在 Unicode 分组之前
  Future<void> _loadBuiltinCategories() async {
    final categories = <EmojiCategory>[];
    try {
      if (widget.types.contains(kEmojiPickerTypeSvg)) {
        final assets = await _listAssetDir(kSvgAssetDir, const ['.svg']);
        if (assets.isNotEmpty) {
          categories.add(
            _buildAssetCategory(assets, 'emoji_category_svg'.tr, svg: true),
          );
        }
      }
      if (widget.types.contains(kEmojiPickerTypeImage)) {
        final faces = await _listAssetDir(kEmojiFaceAssetDir, _imageExts);
        if (faces.isNotEmpty) {
          categories.add(_buildAssetCategory(faces, 'emoji_category_faces'.tr));
        }
        final emojis = await _listAssetDir(kBuiltInEmojiAssetDir, _imageExts);
        if (emojis.isNotEmpty) {
          categories.add(
            _buildAssetCategory(emojis, 'emoji_category_builtin'.tr),
          );
        }
      }
    } catch (e) {
      debugPrint('加载内置表情分组失败: $e');
    }
    if (mounted && categories.isNotEmpty) {
      setState(() => _builtinCategories = categories.lock);
    }
  }

  /// 枚举资源目录下指定扩展名的 asset（有序）
  Future<List<String>> _listAssetDir(String dir, List<String> exts) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest
        .listAssets()
        .where((asset) {
          if (!asset.startsWith('$dir/')) return false;
          final lower = asset.toLowerCase();
          return exts.any(lower.endsWith);
        })
        .toList()
      ..sort();
  }

  /// 由 asset 路径列表构建内置资源分组（svg 走 flutter_svg 渲染），
  /// value 带 [kBuiltInEmojiPrefix] 前缀供消费方识别
  EmojiCategory _buildAssetCategory(
    List<String> assets,
    String name, {
    bool svg = false,
  }) {
    Widget thumbOf(String asset) => svg
        ? SvgPicture.asset(asset, fit: BoxFit.contain)
        : Image.asset(
            asset,
            fit: BoxFit.contain,
            errorBuilder:
                (_, _, _) => const Icon(Icons.emoji_emotions, size: 20),
          );

    String nameOf(String asset) =>
        path.basenameWithoutExtension(asset).replaceAll('_', ' ');

    return EmojiCategory(
      icon: thumbOf(assets.first),
      name: name,
      emojis: assets
          .map(
            (asset) => Emoji(
              widget: thumbOf(asset),
              value: '$kBuiltInEmojiPrefix$asset',
              aliases: [path.basenameWithoutExtension(asset)].lock,
              description: nameOf(asset),
              tags: (svg ? ['svg', '贴纸'] : ['表情', 'emoji']).lock,
            ),
          )
          .toIList(),
    );
  }

  /// 分类列表内容变化时同步重建锚点 key（IList 为内容相等性）
  void _syncCombined(IList<EmojiCategory> categories) {
    final combined = widget.prependCategories
        .addAll(_builtinCategories)
        .addAll(categories)
        .addAll(widget.appendCategories);
    if (combined == _combined) return;

    _combined = combined;
    _headerKeys = List.generate(combined.length, (_) => GlobalKey());
    _chipKeys = List.generate(combined.length, (_) => GlobalKey());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints.loose(const Size(500, 700)),
      child: switch (ref.watch(EmojiController.provider)) {
        AsyncError(:final error) => throw error,
        AsyncLoading _ => const Center(child: DSLoadingDots()),
        AsyncData(value: final categories) => _buildContent(
          context,
          // types 未开启 emoji 时隐藏 Unicode 分组
          widget.types.contains(kEmojiPickerTypeEmoji)
              ? categories
              : const IList.empty(),
        ),
      },
    );
  }

  Widget _buildContent(BuildContext context, IList<EmojiCategory> categories) {
    final theme = DSThemeBridge.resolve(context);
    _syncCombined(categories);

    return Column(
      children: [
        Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return DSInput(
              controller: _searchController,
              hint: 'app_searchEmoji'.tr,
              pill: true,
              prefix: DsIcon(DsIconKind.search, size: 20, color: theme.textSub),
              onChanged: (value) => setState(() => _search = value),
              suffix:
                  widget.allowFreeText
                      ? DSIconButton(
                        icon: DsIconKind.send,
                        size: 32,
                        onPressed:
                            _search.isEmpty
                                ? null
                                : () => widget.onSelection(_search, true),
                      )
                      : null,
            );
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: Scrollbar(
            controller: _categoryScrollController,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 12),
              scrollDirection: Axis.horizontal,
              controller: _categoryScrollController,
              children: [
                for (var i = 0; i < _combined.length; i++)
                  Padding(
                    key: _chipKeys[i],
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: DSChip(
                      label: _combined[i].name,
                      leading: SizedBox.square(
                        dimension: 18,
                        child: FittedBox(child: _combined[i].icon),
                      ),
                      selected: _selectedCategory == i,
                      onSelected: (_) => _selectCategory(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            key: _scrollViewKey,
            controller: _scrollController,
            slivers: [
              for (var i = 0; i < _combined.length; i++)
                _buildCategorySlivers(theme, _combined[i], _headerKeys[i]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySlivers(
    AppThemeData theme,
    EmojiCategory category,
    GlobalKey headerKey,
  ) {
    final searchTerm = _search.toLowerCase();
    final emojis =
        searchTerm.isEmpty
            ? category.emojis
            : category.emojis
                .where(
                  (emoji) =>
                      emoji.aliases.join().contains(searchTerm) ||
                      emoji.description.contains(searchTerm) ||
                      emoji.tags.join().contains(searchTerm),
                )
                .toIList();

    if (emojis.isEmpty) {
      return SliverToBoxAdapter(child: SizedBox.shrink(key: headerKey));
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
            child: Text(
              category.name,
              key: headerKey,
              style: DsTypography.heading.copyWith(color: theme.text),
            ),
          ),
        ),
        SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 56,
            mainAxisExtent: 56,
          ),
          itemCount: emojis.length,
          itemBuilder: (context, index) {
            final emoji = emojis[index];
            return Pressable(
              onPressed: () => widget.onSelection(emoji.value, false),
              semanticLabel: emoji.description,
              builder: (context, states) {
                final pressed = states.contains(WidgetState.pressed);
                return Opacity(
                  opacity: pressed ? 0.55 : 1,
                  child: Center(
                    child: SizedBox.square(
                      dimension: 34,
                      child: FittedBox(child: emoji.widget),
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 4)),
      ],
    );
  }
}
