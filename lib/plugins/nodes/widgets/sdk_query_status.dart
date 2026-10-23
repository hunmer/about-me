import 'package:flutter/material.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';

class NodesQueryStatus extends StatelessWidget {
  const NodesQueryStatus({
    super.key,
    required this.status,
    required this.error,
    required this.retry,
    required this.child,
  });
  final QueryStatus status;
  final Object? error;
  final Future<void> Function() retry;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (status == QueryStatus.loading) const LinearProgressIndicator(),
      if (status == QueryStatus.error || status == QueryStatus.stale)
        Material(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    (status == QueryStatus.stale ? '显示旧快照，更新失败：' : '加载失败：') +
                        error.toString(),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    retry().catchError((Object _) {});
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      Expanded(child: child),
    ],
  );
}
