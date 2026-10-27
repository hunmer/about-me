import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/store/models/product.dart';
import 'package:aboutme/plugins/store/models/category.dart';
import 'package:aboutme/plugins/store/controllers/store_controller.dart';
import 'package:aboutme/plugins/store/widgets/add_product_page.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/adaptive_image.dart';

/// 商品详情页：集中展示商品信息，兑换入口收敛到本页
/// （商品列表点击不再直接弹兑换确认框，改为跳转本页）
class ProductDetailPage extends StatefulWidget {
  final StoreController controller;
  final Product product;

  const ProductDetailPage({
    super.key,
    required this.controller,
    required this.product,
  });

  /// 商品大图 Hero tag：列表/网格卡片图片与本页大图联动
  /// （跳转需用 NavigationHelper.pushHero）
  static String imageHeroTag(String productId) => 'product-image-$productId';

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  /// 商品大图原始宽高比（异步解码得到）；null = 未知（SVG/解析中/失败）
  double? _imageAspect;

  /// 已解析过比例的图片路径（编辑换图后重新解析）
  String? _aspectResolvedFor;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
    _resolveImageAspect();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  /// 编辑/兑换会替换商品实例，按 id 取最新数据；null 表示商品已删除
  Product? get _current =>
      widget.controller.products.firstWhereOrNull((p) => p.id == widget.product.id);

  void _onControllerUpdate() {
    if (!mounted) return;
    if (_current == null) {
      Navigator.of(context).pop();
    } else {
      _resolveImageAspect();
      setState(() {});
    }
  }

  /// 异步解码图片取原始宽高比，供大图按原比例展示（不裁剪）
  Future<void> _resolveImageAspect() async {
    final url = _current?.image ?? widget.product.image;
    if (url == null || url.isEmpty || AdaptiveImage.isSvgImage(url)) return;
    if (_aspectResolvedFor == url) return;
    _aspectResolvedFor = url;

    final completer = Completer<ImageInfo>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      if (!completer.isCompleted) completer.complete(info);
    });
    ImageStream? stream;
    try {
      stream = ImageUtils.createImageProvider(url).resolve(
        const ImageConfiguration(),
      );
      stream.addListener(listener);
      final info = await completer.future.timeout(const Duration(seconds: 5));
      if (!mounted) return;
      final w = info.image.width;
      final h = info.image.height;
      if (w > 0 && h > 0) {
        setState(() => _imageAspect = w / h);
      }
    } catch (_) {
      // 解析失败保持 null：大图走 contain 完整展示兜底
    } finally {
      stream?.removeListener(listener);
    }
  }

  Future<void> _confirmExchange(Product product) async {
    final confirm = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => DSThemeBridge(
        child: Builder(
          builder: (context) => DSDialog(
            title: 'store_redeemConfirmation'.tr,
            message: 'store_redeemConfirmMessage'.trParams({
              'name': product.name,
              'price': '${product.price}',
            }),
            cancelText: 'app_cancel'.tr,
            confirmText: 'app_confirm'.tr,
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => Navigator.pop(context, true),
          ),
        ),
      ),
    );
    if (confirm != true) return;
    if (await widget.controller.exchangeProduct(product)) {
      Toast.success('store_redeemSuccess'.tr);
    } else {
      Toast.error('store_redeemFailed'.tr);
    }
  }

  void _openEdit(Product product) {
    NavigationHelper.push(
      context,
      AddProductPage(controller: widget.controller, product: product),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final product = _current ?? widget.product;
    final now = DateTime.now();
    final ended = now.isAfter(product.exchangeEnd);
    final notStarted = now.isBefore(product.exchangeStart);
    final soldOut = product.stock <= 0;
    final statusColor =
        ended || soldOut
            ? theme.danger
            : notStarted
            ? theme.warning
            : theme.success;
    final statusLabel = ended
        ? 'store_exchangeEnded'.tr
        : notStarted
        ? 'store_notStarted'.tr
        : soldOut
        ? 'store_outOfStock'.tr
        : 'store_exchanging'.tr;
    final categoryLabel =
        (product.category == null || product.category!.isEmpty)
            ? StoreCategories.uncategorizedLabel
            : StoreCategories.labelOf(product.category!);

    return Scaffold(
      appBar: AppBar(
        title: Text('store_productDetail'.tr),
        actions: [
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.edit,
                  size: 38,
                  color: theme.primary,
                  onPressed: () => _openEdit(product),
                );
              },
            ),
          ),
        ],
      ),
      body: DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 状态胶囊（参考详情页顶部评分胶囊）
                  Center(
                    child: DsSketchPanel(
                      theme: theme,
                      radius: BorderRadius.circular(30),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              statusLabel,
                              style: DsTypography.body.copyWith(
                                color: theme.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 商品大图：飘动展示（参考 moments 贴纸），点击全屏预览
                  _FloatingSticker(child: _buildHeroImage(theme, product)),
                  const SizedBox(height: 16),

                  // 名称 + 价格
                  Text(
                    product.name,
                    textAlign: TextAlign.center,
                    style: DsTypography.heading.copyWith(
                      color: theme.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'store_pricePoints'.trParams({'price': '${product.price}'}),
                    textAlign: TextAlign.center,
                    style: DsTypography.body.copyWith(
                      color: theme.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 基本信息卡
                  DsSketchPanel(
                    theme: theme,
                    radius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            theme,
                            icon: DsIconKind.layers,
                            label: 'store_stockStatus'.tr,
                            value: 'store_stockCount'.trParams({
                              'count': '${product.stock}',
                            }),
                          ),
                          _buildInfoRow(
                            theme,
                            icon: DsIconKind.tag,
                            label: 'store_categoryLabel'.tr,
                            value: categoryLabel,
                          ),
                          _buildInfoRow(
                            theme,
                            icon: DsIconKind.calendar,
                            label: 'store_exchangePeriod'.tr,
                            value:
                                '${_formatDate(product.exchangeStart)}'
                                ' ~ ${_formatDate(product.exchangeEnd)}',
                          ),
                          _buildInfoRow(
                            theme,
                            icon: DsIconKind.clock,
                            label: 'store_useDurationLabel'.tr,
                            value: 'store_useDurationDays'.trParams({
                              'days': '${product.useDuration}',
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 描述卡
                  if (product.description.isNotEmpty)
                    DsSketchPanel(
                      theme: theme,
                      radius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'store_descriptionLabel'.tr,
                              style: DsTypography.heading.copyWith(
                                color: theme.text,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.description,
                              style: DsTypography.body.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // 兑换入口
                  DSButton(
                    label: 'store_redeem'.tr,
                    icon: DsIconKind.gift,
                    expand: true,
                    onPressed: () => _confirmExchange(product),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 商品大图：按原始宽高比完整展示不裁剪；有图时包 Hero 与列表卡图片联动；
  /// 点击全屏预览。比例未知（SVG/解析中/失败）用 contain 兜底完整显示
  Widget _buildHeroImage(AppThemeData theme, Product product) {
    final url = product.image;
    final hasImage = url != null && url.isNotEmpty;
    final aspect = _imageAspect;

    Widget buildImage(BoxFit fit) => AdaptiveImage(
      imagePath: hasImage ? url : null,
      fit: fit,
      errorImage: _imagePlaceholder(theme),
      defaultImage: _imagePlaceholder(theme),
    );

    // 已知比例：按图片原始比例布局（clamp 防极端比例撑爆页面）
    Widget content;
    if (aspect != null) {
      content = AspectRatio(
        aspectRatio: aspect.clamp(0.75, 2.0),
        child: buildImage(BoxFit.cover),
      );
    } else {
      content = SizedBox(
        height: 220,
        width: double.infinity,
        child: buildImage(BoxFit.contain),
      );
    }

    Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
    if (hasImage) {
      image = Hero(tag: ProductDetailPage.imageHeroTag(product.id), child: image);
    }
    return GestureDetector(
      onTap: hasImage ? () => _previewImage(url) : null,
      child: image,
    );
  }

  /// 全屏预览图片（可缩放）；SVG 无 ImageProvider 不预览
  void _previewImage(String path) {
    if (AdaptiveImage.isSvgImage(path)) return;
    showDsImageViewer(context, image: ImageUtils.createImageProvider(path));
  }

  /// 信息行：图标 + 标签 + 右对齐值
  Widget _buildInfoRow(
    AppThemeData theme, {
    required DsIconKind icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          DsIcon(icon, size: 20, color: theme.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: DsTypography.body.copyWith(color: theme.textSub),
          ),
          const Spacer(),
          Text(
            value,
            style: DsTypography.body.copyWith(
              color: theme.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(AppThemeData theme) => Container(
    color: theme.surfaceAlt,
    width: double.infinity,
    height: double.infinity,
    alignment: Alignment.center,
    child: DsIcon(DsIconKind.cart, size: 40, color: theme.textSub),
  );
}

/// 飘动容器：缓慢正弦漂浮 + 轻微摇摆（参数同 moments 的 MomentSticker）。
/// 包在 Hero 外层，不参与飞行转场
class _FloatingSticker extends StatefulWidget {
  final Widget child;

  const _FloatingSticker({required this.child});

  @override
  State<_FloatingSticker> createState() => _FloatingStickerState();
}

class _FloatingStickerState extends State<_FloatingSticker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // 漂浮 ±4px + 摇摆 0.05rad（相位差 π/3），参数同 moments 贴纸
        final dy = -4 * math.sin(t * 2 * math.pi);
        final wobble = 0.05 * math.sin(t * 2 * math.pi + math.pi / 3);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(angle: wobble, child: widget.child),
        );
      },
    );
  }
}
