import 'dart:async';
import 'dart:convert';

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart' show StorageFileInfo;
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:super_cupertino_navigation_bar/utils/navigation_bar_static_components.dart';
import 'package:super_cupertino_navigation_bar/utils/persistent_nav_bar.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/core/data/sdk_media_service.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/utils/network.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/plugins/toolbox/screens/ai_image_screen.dart';
import 'package:aboutme/plugins/toolbox/services/image_search_service.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/utils/platform_utils.dart';
import 'package:aboutme/widgets/emoji_picker/index.dart';
import 'package:aboutme/widgets/photo_editor_screen.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_builders.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/multi_filter_bar.dart';

part 'image_picker_dialog_album.dart';
part 'image_picker_dialog_sources.dart';
part 'image_picker_dialog_processing.dart';
part 'image_picker_dialog_url_sheet.dart';
part 'image_picker_dialog_search_sheet.dart';

/// 图片选择器底部弹窗（smooth_sheets ModalSheet）
///
/// 结构：PersistentNavigationBar 头部（middle 为 相册/表情包 tabs，
/// 右侧为 拍照 / 在线URL 入口）+ 内容区。
/// 相册 tab：MultiFilterBar 多条件过滤（插件/日期/大小）+ 图片网格。
/// 网格聚合展示应用存储内各插件上传的图片（chat、calendar_album 等），
/// 首格为相册入口：移动端使用 wechat_assets_picker，桌面端走系统文件选择。
/// 表情包 tab：EmojiPicker（svg/图片表情 + Unicode 表情内置分组），
/// 内置资源选中后：svg 返回
/// `{'file_path', 'svg'}`（文件路径 + 源码文本），图片返回真实文件路径；
/// Unicode 表情以 `{'url': 'emoji:<表情>', 'bytes': null}` 返回
/// （与在线 URL 入口同构，调用方可用 `emoji:` 前缀区分）。
///
/// 实现按功能拆分（同一 library 的 part 文件，私有成员互通）：
/// - album：相册网格（加载/过滤/磁贴/长按菜单/多选确认栏）
/// - sources：图片来源（移动端相册 / 桌面文件选择 / 拍照）
/// - processing：图片处理管线（保存/压缩缩略图/裁剪对话框）
/// - url_sheet / search_sheet：在线 URL、图片搜索二级弹窗
class ImagePickerDialog extends StatefulWidget {
  final String? initialUrl;

  /// 是否启用图片裁剪功能
  final bool enableCrop;

  /// 裁剪比例，仅在 enableCrop 为 true 时生效
  final double? cropAspectRatio;

  /// 是否允许多图片选择
  final bool multiple;

  /// 是否启用图片压缩（默认关闭）
  final bool enableCompression;

  /// 缩略图保存路径（如果不指定则是保存的文件名+.thumb）
  final String? thumbnailPath;

  /// 压缩质量 0-100（默认 85）
  final int compressionQuality;

  const ImagePickerDialog({
    super.key,
    this.initialUrl,
    this.enableCrop = false,
    this.cropAspectRatio,
    this.multiple = false,
    this.enableCompression = false,
    this.thumbnailPath,
    this.compressionQuality = 85,
  });

  /// 以底部弹窗打开图片选择器
  ///
  /// 返回值与旧版 showDialog 一致：
  /// 单选返回 `{'url', 'thumbUrl', 'bytes'}`，多选返回其列表，取消返回 null。
  static Future<T?> show<T>(
    BuildContext context, {
    String? initialUrl,
    bool enableCrop = false,
    double? cropAspectRatio,
    bool multiple = false,
    bool enableCompression = false,
    String? thumbnailPath,
    int compressionQuality = 85,
  }) {
    return Navigator.of(context).push<T>(
      ModalSheetRoute<T>(
        swipeDismissible: true,
        builder: (context) => ImagePickerDialog(
          initialUrl: initialUrl,
          enableCrop: enableCrop,
          cropAspectRatio: cropAspectRatio,
          multiple: multiple,
          enableCompression: enableCompression,
          thumbnailPath: thumbnailPath,
          compressionQuality: compressionQuality,
        ),
      ),
    );
  }

  @override
  State<ImagePickerDialog> createState() => _ImagePickerDialogState();
}

class _ImagePickerDialogState extends State<ImagePickerDialog> {
  final ImagePicker _picker = ImagePicker();

  /// PersistentNavigationBar 组件 key（GlobalKey 需跨帧稳定，不能每次 build 新建）
  final NavigationBarStaticComponentsKeys _navBarKeys =
      NavigationBarStaticComponentsKeys();

  /// 多条件过滤状态
  final MultiFilterState _filterState = MultiFilterState();

  /// 应用存储内的图片元信息（相对 app_data，如 chat/chat_files/xxx.jpg），
  /// 按修改时间倒序，最多 300 条
  List<StorageFileInfo> _allInfos = [];

  /// 全量图片 key（含 .thumb 缩略图），用于推断 thumbUrl
  Set<String> _imageKeySet = {};

  bool _loading = true;

  /// 当前 tab：0 相册，1 表情包
  int _tab = 0;

  /// 多选模式下已选中的图片 key
  final List<String> _selected = [];

  /// 运行时多选状态：初始取 widget.multiple，
  /// 单选模式下长按图片可切换为多选（对齐微信交互）
  late bool _multiple = widget.multiple;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void dispose() {
    _filterState.dispose();
    super.dispose();
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
          children: [
            _buildHeader(context, theme),
            if (_tab == 0) ...[
              if (_allInfos.isNotEmpty)
                MultiFilterBar(
                  filterItems: _buildFilterItems(),
                  filterState: _filterState,
                  onFilterChanged: (_) => setState(() {}),
                ),
              SizedBox(height: screenHeight * 0.5, child: _buildGrid(theme)),
              if (_multiple) _buildConfirmBar(theme),
            ] else
              SizedBox(height: screenHeight * 0.5, child: _buildEmojiPicker()),
            SafeArea(top: false, child: SizedBox(height: theme.spacing.sm)),
          ],
        ),
      ),
    );
  }

  /// 顶部导航：嵌入式 PersistentNavigationBar（super_cupertino_navigation_bar），
  /// middle 为 相册/表情包 分段 tabs
  Widget _buildHeader(BuildContext context, AppThemeData theme) {
    return PersistentNavigationBar(
      components: NavigationBarStaticComponents(
        keys: _navBarKeys,
        route: null,
        // 单选：无返回钮（下滑或点遮罩关闭）；多选：左侧为取消按钮
        userLeading: _multiple
            ? TextButton(
                onPressed: _cancelMultiple,
                child: Text(
                  'app_cancel'.tr,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              )
            : null,
        automaticallyImplyLeading: false,
        automaticallyImplyTitle: false,
        previousPageTitle: null,
        userMiddle: DSSegmentedControl(
          options: ['image_picker_tab_album'.tr, 'image_picker_tab_emoji'.tr],
          selected: _tab,
          onChanged: (index) => setState(() => _tab = index),
        ),
        userTrailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DSIconButton(
              icon: DsIconKind.search,
              size: 36,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              tooltip: 'image_picker_searchImage'.tr,
              onPressed: () => _showSearchSheet(),
            ),
            const SizedBox(width: 4),
            DSIconButton(
              icon: DsIconKind.camera,
              size: 36,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              tooltip: 'image_picker_takePhoto'.tr,
              onPressed: () => _takePhoto(context),
            ),
            const SizedBox(width: 4),
            DSIconButton(
              icon: DsIconKind.link,
              size: 36,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              tooltip: 'image_picker_onlineUrl'.tr,
              onPressed: () => _showUrlSheet(),
            ),
            const SizedBox(width: 4),
            DSIconButton(
              icon: DsIconKind.sparkle,
              size: 36,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              tooltip: 'toolbox_aiImage_name'.tr,
              onPressed: _openAiImageSheet,
            ),
          ],
        ),
        userLargeTitle: null,
        largeTitleActions: null,
        appbarBottom: null,
        padding: null,
        // 嵌入式小导航（底部弹窗），非大标题模式
        large: false,
      ),
    );
  }

  /// 表情包 tab：EmojiPicker（需 ProviderScope 祖先，这里局部包裹），
  /// 开启全部内置分组（SVG 贴纸 / 方块表情 / 内置表情 / Unicode 表情）
  Widget _buildEmojiPicker() {
    return ProviderScope(
      child: EmojiPicker(
        types: const [
          kEmojiPickerTypeSvg,
          kEmojiPickerTypeImage,
          kEmojiPickerTypeEmoji,
        ],
        onSelection: _selectEmoji,
      ),
    );
  }

  /// 选中表情：内置资源（svg/图片表情）转存到目标目录后返回——
  /// svg 返回 `{'file_path', 'svg'}`（文件路径 + 源码文本），
  /// 图片返回 `{'url', 'thumbUrl', 'bytes'}`；Unicode 表情以 `emoji:` 前缀
  /// 标记返回，与在线 URL 入口同构。多选模式下同样直接返回单条结果
  Future<void> _selectEmoji(String value, bool isFreeText) async {
    if (value.startsWith(kBuiltInEmojiPrefix)) {
      final assetPath = value.substring(kBuiltInEmojiPrefix.length);
      final ext = path.extension(assetPath).toLowerCase();
      try {
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final asset = await SdkMediaService.uploadBytes(bytes, path.basename(assetPath));
        final url = asset.reference;
        if (mounted) {
          Navigator.of(context).pop(
            ext == '.svg'
                ? <String, dynamic>{'file_path': url, 'svg': utf8.decode(bytes)}
                : <String, dynamic>{
                    'url': url,
                    'thumbUrl': null,
                    'bytes': bytes,
                  },
          );
        }
      } catch (e) {
        debugPrint('保存内置表情失败: $e');
        if (mounted) Toast.error('image_picker_selectImageFailed'.tr);
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(<String, dynamic>{
      'url': 'emoji:$value',
      'thumbUrl': null,
      'bytes': null,
    });
  }

  /// AI 图片生成入口：toolbox 的 AiImageScreen 整屏塞进底部抽屉，
  /// 选择模式下生成结果作为选择结果返回（单选单条 / 多选列表，
  /// 与图片搜索弹窗同构）；未选择关闭时刷新网格展示新生成的图
  Future<void> _openAiImageSheet() async {
    final result = await SmoothBottomSheet.showScreen<dynamic>(
      context: context,
      screen: AiImageScreen(pickMode: true, multiple: _multiple),
    );
    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop(result);
    } else {
      _loadImages();
    }
  }

  /// 弹出在线 URL 输入的二级底部弹窗，确认后连同主弹窗一起返回结果
  /// （弹窗实现见 [_UrlInputSheet]）
  Future<void> _showUrlSheet() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      ModalSheetRoute<Map<String, dynamic>>(
        swipeDismissible: true,
        builder: (context) => _UrlInputSheet(initialUrl: widget.initialUrl),
      ),
    );
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  /// 弹出图片搜索的二级底部弹窗（调用 scripts_center 的 image_search 脚本），
  /// 选中后连同主弹窗一起返回结果（与在线 URL 入口同构：{'url', 'bytes': null}）
  /// （弹窗实现见 [_ImageSearchSheet]）
  Future<void> _showSearchSheet() async {
    final result = await Navigator.of(context).push<dynamic>(
      ModalSheetRoute<dynamic>(
        swipeDismissible: true,
        builder: (context) => _ImageSearchSheet(multiple: _multiple),
      ),
    );
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }
}
