import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/plugins/contact/contact_plugin.dart';

/// 联系人插件首页卡片视图 - 显示联系人统计信息
class ContactPluginCard extends StatelessWidget {
  const ContactPluginCard({super.key, required this.plugin});

  final ContactPlugin plugin;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getCardStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        final theme = Theme.of(context);

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部图标和标题
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: plugin.color.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(plugin.icon, size: 24, color: plugin.color),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'contact_name'.tr,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 统计信息
              Column(
                children: [
                  // 联系人统计
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // 总联系人
                      Column(
                        children: [
                          Text(
                            'contact_totalContacts'.tr,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            '${stats['totalContacts']}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),

                      // 最近联系人
                      Column(
                        children: [
                          Text(
                            'contact_recentContacts'.tr,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            '${stats['recentContacts']}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getCardStats() async {
    // 使用 UseCase 获取统计数据
    final totalContactsResult = await plugin.useCase.getTotalContactCount({});
    final recentContactsResult = await plugin.useCase.getRecentlyContactedCount(
      {},
    );

    return {
      'totalContacts': totalContactsResult.dataOrNull ?? 0,
      'recentContacts': recentContactsResult.dataOrNull ?? 0,
    };
  }
}
