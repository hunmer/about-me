import 'package:flutter/material.dart';

import '../../models/webview_card.dart';
import '../../webview_plugin.dart';
import '../webview_browser_screen.dart';

/// 判断文本是否为可直接打开的 http/https URL
bool isValidUrl(String text) {
  try {
    final uri = Uri.parse(text);
    return uri.scheme == 'http' || uri.scheme == 'https';
  } catch (_) {
    return false;
  }
}

/// 打开在线 URL（进入浏览器页面）
void openUrl(BuildContext context, String url) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => WebViewBrowserScreen(initialUrl: url),
    ),
  );
}

/// 打开卡片：已有标签页则切换，否则新建标签页并进入浏览器
void openCard(BuildContext context, WebViewCard card) async {
  // 增加打开次数
  WebViewPlugin.instance.cardManager.incrementOpenCount(card.id);

  final tabManager = WebViewPlugin.instance.tabManager;

  // 检查是否已经有该卡片的标签页
  final existingTab = tabManager.findTabByCardId(card.id);

  if (existingTab != null) {
    // 已存在，切换到该标签页
    await tabManager.switchToTab(existingTab.id);

    // 导航到浏览器界面
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const WebViewBrowserScreen()),
    );
  } else {
    // 不存在，创建新标签页并导航
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WebViewBrowserScreen(
          initialUrl: card.url,
          initialTitle: card.title,
          cardId: card.id,
        ),
      ),
    );
  }
}
