import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';

import '../../models/webview_card.dart';
import '../../services/card_manager.dart';
import 'webview_card_item.dart';

/// 排序类型枚举
enum SortType { openTime, addTime }

/// 已安装卡片列表：按搜索/类型过滤、排序后分「固定 / 全部」两组网格展示
class WebViewCardList extends StatelessWidget {
  const WebViewCardList({
    super.key,
    required this.searchQuery,
    required this.searchFilters,
    required this.filterType,
    required this.sortType,
    required this.onCardTap,
    required this.onCardLongPress,
  });

  final String searchQuery;

  /// 搜索范围开关（url / title）
  final Map<String, bool> searchFilters;
  final CardType? filterType;
  final SortType sortType;
  final ValueChanged<WebViewCard> onCardTap;
  final ValueChanged<WebViewCard> onCardLongPress;

  @override
  Widget build(BuildContext context) {
    return Consumer<CardManager>(
      builder: (context, cardManager, child) {
        final theme = DSThemeBridge.resolve(context);
        var cards = _applySearchFilter(cardManager.cards);

        // 应用类型过滤
        if (filterType != null) {
          cards = cards.where((c) => c.type == filterType).toList();
        }

        // 应用排序
        cards = _sortCards(cards);

        if (cards.isEmpty) {
          return Center(
            child: DSEmptyState(emoji: '🌐', title: 'webview_no_cards'.tr),
          );
        }

        // 分组显示：固定的卡片在前
        final pinnedCards = cards.where((c) => c.isPinned).toList();
        final unpinnedCards = cards.where((c) => !c.isPinned).toList();

        return ListView(
          // 宿主页 extendBody：底部留出弧形导航高度（Scaffold 注入的
          // MediaQuery.padding.bottom）+ 视觉缓冲
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ).copyWith(bottom: MediaQuery.paddingOf(context).bottom + 16),
          children: [
            if (pinnedCards.isNotEmpty) ...[
              _buildSectionHeader('webview_pinned'.tr, theme),
              _buildGrid(context, pinnedCards),
              const SizedBox(height: 16),
            ],
            if (unpinnedCards.isNotEmpty) ...[
              if (pinnedCards.isNotEmpty)
                _buildSectionHeader('webview_all_cards'.tr, theme),
              _buildGrid(context, unpinnedCards),
            ],
          ],
        );
      },
    );
  }

  /// 按搜索词与搜索范围过滤
  List<WebViewCard> _applySearchFilter(List<WebViewCard> cards) {
    if (searchQuery.isEmpty) return cards;
    final queryLower = searchQuery.toLowerCase();
    return cards.where((c) {
      bool matches = false;

      // 根据搜索过滤器决定搜索范围
      if (searchFilters['url'] == true) {
        matches = matches || c.url.toLowerCase().contains(queryLower);
      }
      if (searchFilters['title'] == true) {
        matches =
            matches ||
            c.title.toLowerCase().contains(queryLower) ||
            (c.description?.toLowerCase().contains(queryLower) ?? false);
      }

      return matches;
    }).toList();
  }

  /// 对卡片进行排序
  List<WebViewCard> _sortCards(List<WebViewCard> cards) {
    final sortedCards = List<WebViewCard>.from(cards);
    if (sortType == SortType.openTime) {
      // 按最近打开时间排序（打开次数多的在前）
      sortedCards.sort((a, b) => b.openCount.compareTo(a.openCount));
    } else {
      // 按最近添加时间排序（id 为基于时间的 UUID，字符串比较作近似）
      sortedCards.sort((a, b) => b.id.compareTo(a.id));
    }
    return sortedCards;
  }

  Widget _buildSectionHeader(String label, AppThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: DsTypography.heading.copyWith(color: theme.textSub),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<WebViewCard> cards) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // 顶部 16：容纳便签贴条出血，避免首行贴条被视口裁剪
      padding: const EdgeInsets.only(top: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getCrossAxisCount(context),
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        // ≥16：避免贴条出血被上一行遮挡
        mainAxisSpacing: 16,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        return HandDrawnStickyItem(
          tiltKey: cards[index].id,
          child: WebViewCardItem(
            card: cards[index],
            onTap: () => onCardTap(cards[index]),
            onLongPress: () => onCardLongPress(cards[index]),
          ),
        );
      },
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 5;
    if (width > 900) return 4;
    if (width > 600) return 3;
    return 2;
  }
}
