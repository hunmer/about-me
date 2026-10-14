// ignore_for_file: library_private_types_in_public_api

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/store/controllers/store_controller.dart';
import 'package:aboutme/plugins/store/models/product.dart';
import 'package:aboutme/plugins/store/widgets/product_card.dart';

class ArchivedProductsPage extends StatefulWidget {
  final StoreController controller;

  const ArchivedProductsPage({super.key, required this.controller});

  @override
  _ArchivedProductsPageState createState() => _ArchivedProductsPageState();
}

class _ArchivedProductsPageState extends State<ArchivedProductsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Scaffold(
      appBar: AppBar(title: Text('store_archivedProductsTitle'.tr)),
      body:
          widget.controller.archivedProducts.isEmpty
              ? Center(
                child: Text(
                  'store_noArchivedProducts'.tr,
                  style: DsTypography.body.copyWith(color: theme.textSub),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: widget.controller.archivedProducts.length,
                itemBuilder: (context, index) {
                  final product = widget.controller.archivedProducts[index];
                  // 挂载即播墨线描画入场（design.md §10）
                  return WiredDraw(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildArchivedProductCard(product),
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildArchivedProductCard(Product product) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          return Stack(
            children: [
              DSCard(
                padding: EdgeInsets.zero,
                child: ProductCard(
                  product: product,
                  onExchange: () => _showRestoreConfirmation(product),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DsIcon(
                        DsIconKind.download,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'store_archivedLabel'.tr,
                        style: DsTypography.caption.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: DSFab(
                  size: 44,
                  icon: DsIconKind.refresh,
                  onPressed: () => _showRestoreConfirmation(product),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showRestoreConfirmation(Product product) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: 'store_confirmRestoreTitle'.tr,
                    message: 'store_confirmRestoreMessage'.tr,
                    cancelText: 'app_cancel'.tr,
                    confirmText: 'store_restore'.tr,
                    onCancel: () => Navigator.of(context).pop(false),
                    onConfirm: () => Navigator.of(context).pop(true),
                  ),
            ),
          ),
    );

    if (confirmed == true) {
      await widget.controller.restoreProduct(product);
      if (mounted) setState(() {});
    }
  }
}
