import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import '../picker/image_picker_dialog.dart';
import '../adaptive_image.dart';

/// 图片选择器字段组件
///
/// 集成 ImagePickerDialog，提供图片选择和预览功能。
/// 支持图片预览、布局比例设置和默认图片显示。
class ImagePickerField extends StatefulWidget {
  /// 当前图片 URL 或结果 Map
  final dynamic currentImage;

  /// 字段标签
  final String? labelText;

  /// 占位提示
  final String? hintText;

  /// 是否启用
  final bool enabled;

  /// 值变化回调
  final ValueChanged<dynamic> onImageChanged;

  /// 是否启用裁剪
  final bool enableCrop;

  /// 裁剪比例
  final double? cropAspectRatio;

  /// 是否允许多选
  final bool multiple;

  /// 是否启用压缩
  final bool enableCompression;

  /// 布局比例（类似 Flex 中的 flex，用于 Row/Column 布局）
  final int flex;

  /// 预览区域宽度
  final double? previewWidth;

  /// 预览区域高度
  final double? previewHeight;

  /// 默认图片（当未选择图片时显示）
  final Widget? defaultImage;

  /// 默认图片路径（字符串形式，会被转换为 defaultImage）
  final String? defaultImagePath;

  /// 是否显示标签文本
  final bool showLabel;

  /// 是否显示阴影
  final bool showShadow;

  /// 边框半径
  final double borderRadius;

  /// 是否显示选择按钮
  final bool showSelectButton;

  const ImagePickerField({
    super.key,
    required this.onImageChanged,
    this.currentImage,
    this.labelText,
    this.hintText,
    this.enabled = true,
    this.enableCrop = false,
    this.cropAspectRatio,
    this.multiple = false,
    this.enableCompression = false,
    this.flex = 1,
    this.previewWidth,
    this.previewHeight,
    this.defaultImage,
    this.defaultImagePath,
    this.showLabel = true,
    this.showShadow = false,
    this.borderRadius = 12,
    this.showSelectButton = true,
  });

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  /// 内部状态，用于本地更新 UI
  dynamic _selectedImage;

  @override
  void initState() {
    super.initState();
    _selectedImage = widget.currentImage;
  }

  @override
  void didUpdateWidget(ImagePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentImage != oldWidget.currentImage) {
      _selectedImage = widget.currentImage;
    }
  }

  /// 占位状态（未选择图片）时预览区域的最小尺寸
  static const double _minPlaceholderSize = 80;

  /// 占位尺寸兜底：未指定或小于最小值时撑到最小值
  double _floorPlaceholderSize(double? size) =>
      size == null || size < _minPlaceholderSize ? _minPlaceholderSize : size;

  /// 获取图片路径（从当前选择的图片中提取）
  ///
  /// svg 选择结果（ImagePickerDialog 表情包 SVG 贴纸）无 url 字段，
  /// 路径在 file_path；AdaptiveImage 按 .svg 扩展名自动走矢量渲染
  String? get _imagePath {
    if (_selectedImage == null) return null;
    if (_selectedImage is Map) {
      return (_selectedImage['url'] ?? _selectedImage['file_path']) as String?;
    }
    return _selectedImage as String?;
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final imagePath = _imagePath;

    return Flex(
      direction: Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel && widget.labelText != null)
          Padding(
            padding: const EdgeInsets.only(top: 12, right: 12),
            child: Text(
              widget.labelText!,
              style: DsTypography.body.copyWith(
                color: widget.enabled ? theme.text : theme.textSub,
              ),
            ),
          ),
        Expanded(
          flex: widget.flex,
          child: Builder(
            builder: (ctx) {
              // 未选择图片时为占位状态：预览尺寸兜底到最小值，避免占位塌陷
              final bool hasImage = imagePath != null;
              final double? previewWidth =
                  hasImage
                      ? widget.previewWidth
                      : _floorPlaceholderSize(widget.previewWidth);
              final double? previewHeight =
                  hasImage
                      ? widget.previewHeight
                      : _floorPlaceholderSize(widget.previewHeight);

              // 图片预览区域
              Widget preview = GestureDetector(
                onTap: widget.enabled ? () => _showPicker(ctx) : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  child: AdaptiveImage(
                    imagePath: imagePath,
                    width: previewWidth,
                    height: previewHeight,
                    borderRadius: widget.borderRadius,
                    defaultImage:
                        widget.defaultImage ??
                        (widget.defaultImagePath != null
                            ? Image.asset(
                                widget.defaultImagePath!,
                                width: previewWidth,
                                height: previewHeight,
                                fit: BoxFit.cover,
                              )
                            : null),
                  ),
                ),
              );
              if (!hasImage) {
                // 占位状态至少撑到最小尺寸（defaultImage 自带尺寸时不生效）
                preview = ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: _minPlaceholderSize,
                    minHeight: _minPlaceholderSize,
                  ),
                  child: preview,
                );
              }

              return Stack(
                children: [
                  preview,
                  // 上传按钮：叠加在图片右上角
                  if (widget.showSelectButton)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Pressable(
                        onPressed:
                            widget.enabled ? () => _showPicker(ctx) : null,
                        semanticLabel: _getDisplayText(),
                        child: JellyBox(
                          radius: theme.radii.pill,
                          color: theme.primary.mixWhite(0.9),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DsIcon(
                                DsIconKind.image,
                                size: 14,
                                color: theme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getDisplayText(),
                                style: DsTypography.caption.copyWith(
                                  color: theme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// 显示图片选择器对话框
  Future<void> _showPicker(BuildContext context) async {
    final initialUrl =
        _selectedImage is Map
            ? (_selectedImage['url'] ?? _selectedImage['file_path']) as String?
            : _selectedImage as String?;

    final result = await ImagePickerDialog.show<dynamic>(
      context,
      initialUrl: initialUrl,
      enableCrop: widget.enableCrop,
      cropAspectRatio: widget.cropAspectRatio,
      multiple: widget.multiple,
      enableCompression: widget.enableCompression,
    );

    if (result != null) {
      setState(() {
        _selectedImage = result;
      });
      widget.onImageChanged(result);
    }
  }

  /// 获取显示文本
  String _getDisplayText() {
    if (_selectedImage != null) {
      if (widget.multiple && _selectedImage is List) {
        return '已选择 ${_selectedImage.length} 张图片';
      } else {
        return '更换图片';
      }
    }
    return widget.hintText ?? '选择图片';
  }
}

/// 图片选择器字段构建器（用于 FormBuilderWrapper）
///
/// 封装 ImagePickerField，提供与 FormBuilderWrapper 集成的能力。
class ImagePickerFormField extends StatelessWidget {
  /// 当前图片 URL 或结果 Map
  final dynamic currentImage;

  /// 字段标签
  final String? labelText;

  /// 占位提示
  final String? hintText;

  /// 是否启用
  final bool enabled;

  /// 值变化回调
  final ValueChanged<dynamic> onImageChanged;

  /// 是否启用裁剪
  final bool enableCrop;

  /// 裁剪比例
  final double? cropAspectRatio;

  /// 是否允许多选
  final bool multiple;

  /// 是否启用压缩
  final bool enableCompression;

  /// 布局比例
  final int flex;

  /// 预览区域宽度
  final double? previewWidth;

  /// 预览区域高度
  final double? previewHeight;

  /// 默认图片
  final Widget? defaultImage;

  /// 默认图片路径
  final String? defaultImagePath;

  /// 是否显示标签
  final bool showLabel;

  /// 是否显示阴影
  final bool showShadow;

  /// 边框半径
  final double borderRadius;

  /// 是否显示选择按钮
  final bool showSelectButton;

  const ImagePickerFormField({
    super.key,
    required this.onImageChanged,
    this.currentImage,
    this.labelText,
    this.hintText,
    this.enabled = true,
    this.enableCrop = false,
    this.cropAspectRatio,
    this.multiple = false,
    this.enableCompression = false,
    this.flex = 1,
    this.previewWidth,
    this.previewHeight,
    this.defaultImage,
    this.defaultImagePath,
    this.showLabel = true,
    this.showShadow = false,
    this.borderRadius = 12,
    this.showSelectButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return ImagePickerField(
      currentImage: currentImage,
      labelText: labelText,
      hintText: hintText,
      enabled: enabled,
      onImageChanged: onImageChanged,
      enableCrop: enableCrop,
      cropAspectRatio: cropAspectRatio,
      multiple: multiple,
      enableCompression: enableCompression,
      flex: flex,
      previewWidth: previewWidth,
      previewHeight: previewHeight,
      defaultImage: defaultImage,
      defaultImagePath: defaultImagePath,
      showLabel: showLabel,
      showShadow: showShadow,
      borderRadius: borderRadius,
      showSelectButton: showSelectButton,
    );
  }
}
