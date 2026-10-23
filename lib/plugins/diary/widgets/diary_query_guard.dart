import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import '../models/diary_entry.dart';
import '../utils/diary_utils.dart';

/// 首页和卡片同样消费 SDK watch，查询错误不会渲染成空白业务数据。
class DiarySnapshotBuilder extends StatefulWidget {
  const DiarySnapshotBuilder({super.key, required this.builder});
  final Widget Function(BuildContext, Map<DateTime, DiaryEntry>) builder;

  @override
  State<DiarySnapshotBuilder> createState() => _DiarySnapshotBuilderState();
}

class _DiarySnapshotBuilderState extends State<DiarySnapshotBuilder> {
  Map<DateTime, DiaryEntry>? _entries;
  Object? _error;
  late final StreamSubscription<Map<DateTime, DiaryEntry>> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = DiaryUtils.watchEntries().listen(
      (entries) {
        if (mounted) {
          setState(() {
            _entries = entries;
            _error = null;
          });
        }
      },
      onError: (Object error) {
        if (mounted) setState(() => _error = error);
      },
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DiaryQueryGuard(
    hasSnapshot: _entries != null,
    error: _error,
    onRetry: () => AboutmeDataService.instance.revalidate(),
    child: _entries == null
        ? const SizedBox.shrink()
        : widget.builder(context, _entries!),
  );
}

/// 查询失败不伪装为空日记；已有快照保留并明确标示可能过期。
class DiaryQueryGuard extends StatelessWidget {
  const DiaryQueryGuard({
    super.key,
    required this.hasSnapshot,
    required this.error,
    required this.onRetry,
    required this.child,
  });
  final bool hasSnapshot;
  final Object? error;
  final VoidCallback onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!hasSnapshot) {
      if (error == null) return const Center(child: DSLoadingDots());
      return Center(
        child: DSEmptyState(
          icon: DsIconKind.book,
          title: '日记加载失败',
          message: '$error',
          actionLabel: '重试',
          onAction: onRetry,
        ),
      );
    }
    if (error == null) return child;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '数据可能已过期：$error',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
