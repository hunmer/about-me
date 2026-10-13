import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:super_cupertino_navigation_bar/utils/persistent_nav_bar.dart';
import 'package:super_cupertino_navigation_bar/utils/navigation_bar_static_components.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/scripts_center/services/script_execution_logger.dart';
import 'package:aboutme/plugins/scripts_center/services/script_executor.dart';

import 'package:get/get.dart';
/// 脚本执行记录页面
///
/// 展示所有脚本的历史执行记录（手动/事件/互调/自动运行），
/// 支持仅看失败、按脚本过滤、查看详情与清空，运行中脚本可终止。
/// "清空记录"停靠在 PersistentNavigationBar 右上角
class ScriptExecutionLogScreen extends StatefulWidget {
  final ScriptExecutionLogger logger;

  /// 执行器（用于终止运行中的脚本），为空时不显示终止按钮
  final ScriptExecutor? executor;

  /// 可选：仅显示该脚本的记录
  final String? scriptId;

  /// 内嵌模式：作为 tab 内容嵌入主视图时不显示返回按钮
  final bool embedded;

  const ScriptExecutionLogScreen({
    super.key,
    required this.logger,
    this.executor,
    this.scriptId,
    this.embedded = false,
  });

  @override
  State<ScriptExecutionLogScreen> createState() =>
      _ScriptExecutionLogScreenState();
}

class _ScriptExecutionLogScreenState extends State<ScriptExecutionLogScreen> {
  bool _onlyFailed = false;
  String? _filterScriptId;

  /// PersistentNavigationBar 组件 key（GlobalKey 需跨帧稳定，不能每次 build 新建）
  final NavigationBarStaticComponentsKeys _navBarKeys =
      NavigationBarStaticComponentsKeys();

  /// 每秒跳动一次，驱动"运行中"条目的已运行时长刷新
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _filterScriptId = widget.scriptId;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.logger.running.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  List<ScriptExecutionLogEntry> get _filtered {
    return widget.logger.entries.where((e) {
      if (_onlyFailed && e.success) return false;
      if (_filterScriptId != null && e.scriptId != _filterScriptId) {
        return false;
      }
      return true;
    }).toList();
  }

  List<String> get _scriptOptions {
    final ids = <String>{};
    for (final e in widget.logger.entries) {
      ids.add(e.scriptId);
    }
    return ids.toList()..sort();
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('scripts_center_clearExecutionLogs'.tr),
        content: Text('scripts_center_confirmClearLogs'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('app_cancel'.tr),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('scripts_center_clearAll'.tr),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.logger.clear();
      if (mounted) Toast.success('执行记录已清空');
    }
  }

  /// 终止运行中的脚本（带确认）
  Future<void> _confirmTerminate(String scriptName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('scripts_center_terminateScript'.tr),
        content: Text(
          '确定终止「$scriptName」？\n\n'
          '将中断脚本所有挂起的操作，执行记录中会标记为"脚本已被用户终止"。\n'
          '注意：如有多个脚本同时在运行，会一并终止。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('app_cancel'.tr),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('scripts_center_terminate'.tr),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.executor?.terminateRunning();
      if (mounted) Toast.success('已请求终止，等待脚本退出...');
    }
  }

  void _showDetail(ScriptExecutionLogEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.scriptName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('状态', entry.success ? '成功' : '失败'),
              _detailRow('触发方式', entry.trigger),
              _detailRow(
                '耗时',
                '${entry.durationMs}ms'
                    '${entry.durationMs >= 1000 ? '（${(entry.durationMs / 1000).toStringAsFixed(1)}秒）' : ''}',
              ),
              _detailRow('时间', _formatTime(entry.time)),

              // 生成的图片（本地路径，点击全屏查看）
              if (entry.images.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '生成图片（${entry.images.length}）',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final imgPath in entry.images)
                      _buildImageThumb(imgPath),
                  ],
                ),
              ],

              if (entry.error != null) ...[
                const SizedBox(height: 12),
                Text('scripts_center_errorMessage'.tr,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    entry.error!,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ],
              if (entry.resultSummary != null) ...[
                const SizedBox(height: 12),
                Text('scripts_center_returnValue'.tr,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      entry.resultSummary!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('app_close'.tr),
          ),
        ],
      ),
    );
  }

  /// 图片缩略图（点击全屏查看）
  Widget _buildImageThumb(String imgPath) {
    final file = File(imgPath);
    return InkWell(
      onTap: () => _showFullScreenImage(imgPath),
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 100,
            height: 100,
            color: Colors.grey.withValues(alpha: 0.15),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined,
                    size: 28, color: Colors.grey),
                SizedBox(height: 4),
                Text('加载失败', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 全屏查看图片
  void _showFullScreenImage(String imgPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('scripts_center_imagePreview'.tr, style: TextStyle(fontSize: 16)),
          ),
          body: Center(
            child: InteractiveViewer(
              maxScale: 5,
              child: Image.file(
                File(imgPath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text('scripts_center_imageLoadFailed'.tr,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final datePart = time.year == now.year &&
            time.month == now.month &&
            time.day == now.day
        ? '今天'
        : '${time.year}-${two(time.month)}-${two(time.day)}';
    return '$datePart ${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return Scaffold(
            backgroundColor: theme.background,
            body: Column(
              children: [
                // Super Cupertino 风格的固定 header；
                // "清空记录"停靠右上角（内嵌 tab 模式不显示返回按钮）
                PersistentNavigationBar(
                  components: NavigationBarStaticComponents(
                    keys: _navBarKeys,
                    route: null,
                    // NavigationToolbar 对 leading 施加紧高度约束会把按钮
                    // 拉变形，用 Align 转成宽松约束保持正圆
                    userLeading:
                        widget.embedded
                            ? null
                            : Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: DSIconButton(
                                icon: DsIconKind.chevronLeft,
                                size: 36,
                                color: theme.surfaceAlt,
                                iconColor: theme.textSub,
                                tooltip: '返回',
                                onPressed:
                                    () => Navigator.of(context).maybePop(),
                              ),
                            ),
                    automaticallyImplyLeading: false,
                    automaticallyImplyTitle: false,
                    previousPageTitle: null,
                    userMiddle: Text(
                      '执行记录',
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                    userTrailing: DSIconButton(
                      icon: DsIconKind.trash,
                      size: 36,
                      color: theme.surfaceAlt,
                      iconColor: theme.danger,
                      tooltip: '清空记录',
                      onPressed: _confirmClear,
                    ),
                    userLargeTitle: null,
                    largeTitleActions: null,
                    appbarBottom: null,
                    padding: null,
                    large: false,
                  ),
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // 过滤栏
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              FilterChip(
                label: Text('scripts_center_failedOnly'.tr),
                selected: _onlyFailed,
                onSelected: (v) => setState(() => _onlyFailed = v),
              ),
              const SizedBox(width: 8),
              if (_scriptOptions.length > 1) ...[
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _filterScriptId,
                      isExpanded: true,
                      hint: Text('scripts_center_allScripts'.tr),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('全部脚本'),
                        ),
                        ..._scriptOptions.map(
                          (id) => DropdownMenuItem<String?>(
                            value: id,
                            child: Text(
                              id,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _filterScriptId = v),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
          const Divider(height: 1),
          // 记录列表（含运行中区域）
          Expanded(
            child: AnimatedBuilder(
              animation: widget.logger,
              builder: (context, _) {
                if (!widget.logger.loaded) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 底部留出悬浮导航栏高度（内嵌 tab 时经 extendBody 注入）
                return ListView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    // 运行中的脚本（实时状态，可终止）
                    for (final r in widget.logger.running)
                      if (_filterScriptId == null || r.scriptId == _filterScriptId)
                        ListTile(
                          dense: true,
                          leading: const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          title: Text(
                            r.scriptName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${r.trigger} · 已运行 ${_formatElapsed(DateTime.now().difference(r.startTime))}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                          trailing: widget.executor != null
                              ? IconButton(
                                  icon: const Icon(Icons.stop_circle_outlined),
                                  color: Colors.red,
                                  tooltip: '终止执行',
                                  onPressed: () => _confirmTerminate(r.scriptName),
                                )
                              : null,
                        ),
                    if (widget.logger.running.isNotEmpty)
                      const Divider(height: 1),

                    if (widget.logger.entries.isEmpty &&
                        widget.logger.running.isEmpty)
                      SizedBox(
                        height: 400,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history,
                                  size: 56, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                '暂无执行记录',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 历史记录
                    for (final e in _filtered)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          e.success ? Icons.check_circle : Icons.cancel,
                          color: e.success ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          e.scriptName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${_formatTime(e.time)} · ${e.trigger} · ${e.durationMs}ms'
                          '${e.images.isNotEmpty ? ' · ${e.images.length}图' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: e.success
                            ? null
                            : const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: Colors.grey,
                              ),
                        onTap: () => _showDetail(e),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      );
  }

  /// 已运行时长（mm:ss / h:mm:ss）
  String _formatElapsed(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }
}
