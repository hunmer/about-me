// ignore_for_file: library_private_types_in_public_api

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/store/models/user_item.dart';
import 'package:aboutme/plugins/store/controllers/store_controller.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/adaptive_image.dart';

class UserItemDetailPage extends StatefulWidget {
  final StoreController controller;
  final List<UserItem> items;
  final int initialIndex;
  final bool autoUse; // 是否自动弹出使用对话框

  const UserItemDetailPage({
    super.key,
    required this.controller,
    required this.items,
    this.initialIndex = 0,
    this.autoUse = false,
  });

  @override
  _UserItemDetailPageState createState() => _UserItemDetailPageState();
}

class _UserItemDetailPageState extends State<UserItemDetailPage> {
  late int _currentIndex;
  late PageController _pageController;
  bool _hasShownAutoUseDialog = false; // 防止重复弹出

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    debugPrint(
      '[UserItemDetailPage] initState: autoUse=${widget.autoUse}, items.length=${widget.items.length}',
    );

    // 自动使用逻辑
    if (widget.autoUse && !_hasShownAutoUseDialog) {
      debugPrint('[UserItemDetailPage] 触发自动使用对话框');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hasShownAutoUseDialog = true;
        _showUseDialog();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 弹出使用对话框（使用已有的使用逻辑）
  void _showUseDialog() {
    final currentItem = widget.items[_currentIndex];
    debugPrint(
      '[UserItemDetailPage] _showUseDialog: itemName=${currentItem.productName}, expireDate=${currentItem.expireDate}',
    );

    // 检查是否过期
    if (currentItem.expireDate.isBefore(DateTime.now())) {
      debugPrint('[UserItemDetailPage] 物品已过期');
      Toast.error('store_itemExpired'.tr);
      return;
    }

    debugPrint('[UserItemDetailPage] 显示使用确认对话框');
    _showUseConfirmDialog();
  }

  /// 使用确认对话框（复用于顶部按钮与自动使用）
  void _showUseConfirmDialog() {
    final currentItem = widget.items[_currentIndex];
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: 'store_useConfirmationTitle'.tr,
                    message: 'store_useConfirmationMessage'.tr.replaceFirst(
                      '%s',
                      currentItem.productName,
                    ),
                    cancelText: 'app_cancel'.tr,
                    confirmText: 'app_ok'.tr,
                    onCancel: () => Navigator.pop(context),
                    onConfirm: () {
                      Navigator.pop(context);
                      _useCurrentItem();
                    },
                  ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('store_itemDetailsTitle'.tr),
        actions: [
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.gift,
                  size: 38,
                  color: theme.primary,
                  onPressed: _showUseConfirmDialog,
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 分页指示器
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < widget.items.length; i++)
                  GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            _currentIndex == i
                                ? theme.primary
                                : theme.textSub.withValues(alpha: 0.3),
                        border: Border.all(
                          color:
                              _currentIndex == i
                                  ? theme.primary
                                  : theme.textSub,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: DsTypography.label.copyWith(
                            color:
                                _currentIndex == i
                                    ? theme.onPrimary
                                    : theme.textSub,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 分页视图
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return _buildItemDetail(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemDetail(UserItem item) {
    final theme = DSThemeBridge.resolve(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 物品图片
          AspectRatio(
            aspectRatio: 16 / 9,
            child: AdaptiveImage(
              imagePath: item.productImage.isEmpty ? null : item.productImage,
              fit: BoxFit.cover,
              borderRadius: 12,
            ),
          ),
          const SizedBox(height: 20),
          // 物品信息
          _buildDetailRow(
            theme: theme,
            icon: DsIconKind.cart,
            label: 'store_productNameLabel'.tr,
            value: item.productName,
          ),
          _buildDetailRow(
            theme: theme,
            icon: DsIconKind.calendar,
            label: 'store_purchaseDateLabel'.tr,
            value: _formatDate(item.purchaseDate),
          ),
          _buildDetailRow(
            theme: theme,
            icon: DsIconKind.calendar,
            label: 'store_expiryDateLabel'.tr,
            value: _formatDate(item.expireDate),
          ),
          _buildDetailRow(
            theme: theme,
            icon: DsIconKind.piggy,
            label: 'store_purchasePriceLabel'.tr,
            value: '${item.purchasePrice}${'store_points'.tr}',
          ),
          _buildDetailRow(
            theme: theme,
            icon: DsIconKind.layers,
            label: 'store_remainingQuantityLabel'.tr,
            value: '${item.remaining}',
          ),
          const SizedBox(height: 20),
          // 物品描述
          if (item.productSnapshot['description'] != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'store_descriptionLabel'.tr,
                  style: DsTypography.heading.copyWith(color: theme.text),
                ),
                const SizedBox(height: 8),
                Text(
                  item.productSnapshot['description'],
                  style: DsTypography.body.copyWith(color: theme.text),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required AppThemeData theme,
    required DsIconKind icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          DsIcon(icon, size: 20, color: theme.primary),
          const SizedBox(width: 12),
          Text(
            'store_labelColon'.trParams({'label': label}),
            style: DsTypography.body.copyWith(
              color: theme.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(value, style: DsTypography.body.copyWith(color: theme.text)),
        ],
      ),
    );
  }

  Future<void> _useCurrentItem() async {
    final item = widget.items[_currentIndex];
    if (await widget.controller.useItem(item)) {
      Navigator.pop(context);
      Toast.success('store_useSuccessMessage'.tr);
    } else {
      Toast.error('store_itemExpiredMessage'.tr);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
