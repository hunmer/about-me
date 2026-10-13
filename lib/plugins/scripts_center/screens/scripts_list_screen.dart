import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:provider/provider.dart';
import 'package:aboutme/plugins/scripts_center/services/script_manager.dart';
import 'package:aboutme/plugins/scripts_center/services/script_executor.dart';
import 'package:aboutme/plugins/scripts_center/models/script_info.dart';
import 'package:aboutme/plugins/scripts_center/models/script_profile.dart';
import 'package:aboutme/plugins/scripts_center/screens/script_execution_log_screen.dart';
import 'package:aboutme/plugins/scripts_center/widgets/script_card.dart';
import 'package:aboutme/plugins/scripts_center/widgets/script_run_dialog.dart';
import 'package:aboutme/utils/file_picker_helper.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'script_edit_screen.dart';
import '../scripts_center_plugin.dart';

/// 脚本列表界面
///
/// 展示所有脚本，支持启用/禁用切换、搜索、刷新、文件夹切换
class ScriptsListScreen extends StatefulWidget {
  final ScriptManager scriptManager;
  final ScriptExecutor? scriptExecutor;
  final String? searchQuery;

  const ScriptsListScreen({
    super.key,
    required this.scriptManager,
    this.scriptExecutor,
    this.searchQuery,
  });

  @override
  State<ScriptsListScreen> createState() => _ScriptsListScreenState();
}

class _ScriptsListScreenState extends State<ScriptsListScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.searchQuery ?? '';
  }

  @override
  void didUpdateWidget(covariant ScriptsListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery) {
      setState(() {
        _searchQuery = widget.searchQuery ?? '';
      });
    }
  }

  /// 获取筛选后的脚本列表
  List<ScriptInfo> _getFilteredScripts() {
    var scripts = widget.scriptManager.scripts;

    // 按搜索关键词筛选
    if (_searchQuery.isNotEmpty) {
      scripts = widget.scriptManager.searchScripts(_searchQuery);
    }

    return scripts;
  }

  /// 刷新脚本列表
  Future<void> _refreshScripts() async {
    await widget.scriptManager.loadScripts();
  }

  /// 切换脚本启用状态
  Future<void> _toggleScript(ScriptInfo script) async {
    try {
      await widget.scriptManager.toggleScript(script.id, !script.enabled);

      if (mounted) {
        Toast.success(
          script.enabled
              ? '已启用脚本: ${script.name}'
              : '已禁用脚本: ${script.name}',
        );
      }
    } catch (e) {
      if (mounted) {
        Toast.error('操作失败: $e');
      }
    }
  }

  /// 导出脚本（选择目标目录，写出 script.js + metadata.json 含全部配置文件）
  Future<void> _exportScript(ScriptInfo script) async {
    try {
      final targetDir = await FilePickerHelper.pickDirectory();
      if (targetDir == null) return;

      Toast.loading('正在导出: ${script.name}...');
      final exportedPath = await widget.scriptManager.exportScript(
        script,
        targetDir,
      );
      if (mounted) {
        Toast.dismiss();
        Toast.success('导出成功: $exportedPath');
      }
    } catch (e) {
      if (mounted) {
        Toast.dismiss();
        Toast.error('导出失败: $e');
      }
    }
  }

  /// 选择本次执行使用的配置文件（取消返回 null）
  Future<String?> _selectProfileForRun(ScriptProfiles profiles) {
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('scripts_center_selectConfigFile'.tr),
        children: [
          for (final p in profiles.profiles)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(p.id),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 20, color: Colors.deepPurple),
                  const SizedBox(width: 12),
                  Expanded(child: Text(p.name)),
                  if (p.id == profiles.defaultProfileId)
                    Icon(Icons.star, size: 16, color: Colors.orange[700]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 显示创建/编辑脚本屏幕
  Future<void> _showScriptDialog({ScriptInfo? script}) async {
    final result = await NavigationHelper.push<Map<String, dynamic>>(
      context,
      ScriptEditScreen(
        script: script,
        scriptManager: widget.scriptManager,
      ),
    );

    if (result == null || !mounted) return;

    try {
      // 使用统一的保存方法
      await widget.scriptManager.saveScriptFromEditResult(
        result,
        existingScript: script,
      );

      // 重新设置触发器
      await ScriptsCenterPlugin.instance.reloadScripts();

      if (mounted) {
        Toast.success(
          script == null ? '脚本创建成功！' : '脚本更新成功！',
        );
      }
    } catch (e) {
      if (mounted) {
        Toast.error('操作失败: $e');
      }
    }
  }

  /// 运行脚本
  Future<void> _runScript(ScriptInfo script) async {
    if (widget.scriptExecutor == null) {
      Toast.error('脚本执行器未初始化');
      return;
    }

    // 读取配置文件列表（有配置表单才有意义）
    ScriptProfiles? profilesData;
    if (script.configFormFields.isNotEmpty) {
      profilesData = await widget.scriptManager.getScriptProfiles(script.id);
    }

    // 如果是 module 类型且有输入参数,显示表单收集用户输入
    Map<String, dynamic>? inputValues;
    String? profileId;
    if (script.isModule && script.hasInputs) {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => ScriptRunDialog(
          script: script,
          profiles: profilesData?.profiles ?? const [],
          defaultProfileId: profilesData?.defaultProfileId,
        ),
      );

      // 用户取消了
      if (result == null) {
        return;
      }
      profileId = result['profileId'] as String?;
      inputValues = (result['values'] as Map<String, dynamic>?) ?? {};
    } else if (profilesData != null && profilesData.profiles.length > 1) {
      // 无输入参数但有多个配置文件：选择本次执行使用的配置文件
      profileId = await _selectProfileForRun(profilesData);
      if (profileId == null) {
        return;
      }
    }

    // 显示加载提示
    if (mounted) {
      Toast.loading('正在运行脚本: ${script.name}...');
    }

    try {
      // 执行脚本,传入用户输入的参数与可选的配置文件id
      final result = await widget.scriptExecutor!.execute(
        script.id,
        args: {
          ...?inputValues,
          if (profileId != null) 'profileId': profileId,
        },
      );

      if (mounted) {
        // 清除加载提示
        Toast.dismiss();

        // 显示结果
        if (result.success) {
          Toast.success(
            '脚本执行成功\n'
            '脚本: ${script.name}\n'
            '耗时: ${result.duration.inMilliseconds}ms'
            '${result.result != null ? '\n结果: ${result.result}' : ''}',
            duration: const Duration(seconds: 5),
          );
        } else {
          Toast.error(
            '脚本执行失败\n'
            '脚本: ${script.name}\n'
            '耗时: ${result.duration.inMilliseconds}ms'
            '${result.error != null ? '\n错误: ${result.error}' : ''}',
            duration: const Duration(seconds: 5),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Toast.dismiss();
        Toast.error('执行异常: $e');
      }
    }
  }

  /// 删除脚本
  Future<void> _deleteScript(ScriptInfo script) async {
    // 确认删除
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('scripts_center_delete_confirm'.tr),
        content: Text('${'scripts_center_delete_script_confirm'.tr}: ${script.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('app_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('app_delete'.tr),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.scriptManager.deleteScript(script.id);
      if (mounted) {
        Toast.success('scripts_center_delete_success'.tr);
      }
    } catch (e) {
      if (mounted) {
        Toast.error('${'scripts_center_operation_failed'.tr}: $e');
      }
    }
  }

  /// 显示底部操作菜单（手绘 sheet）
  void _showActionSheet(ScriptInfo script) {
    showDSBottomSheet(
      context: context,
      title: script.name,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DSSheetAction(
            icon: script.enabled ? DsIconKind.block : DsIconKind.check,
            label: script.enabled
                ? 'scripts_center_disableScript'.tr
                : 'scripts_center_enableScript'.tr,
            destructive: script.enabled,
            onTap: () {
              Navigator.pop(context);
              _toggleScript(script);
            },
          ),
          DSSheetAction(
            icon: DsIconKind.edit,
            label: 'app_edit'.tr,
            onTap: () {
              Navigator.pop(context);
              _showScriptDialog(script: script);
            },
          ),
          DSSheetAction(
            icon: DsIconKind.clock,
            label: 'scripts_center_executionLogs'.tr,
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScriptExecutionLogScreen(
                    logger: widget.scriptExecutor!.executionLogger,
                    executor: widget.scriptExecutor,
                    scriptId: script.id,
                  ),
                ),
              );
            },
          ),
          DSSheetAction(
            icon: DsIconKind.share,
            label: 'scripts_center_exportScript'.tr,
            onTap: () {
              Navigator.pop(context);
              _exportScript(script);
            },
          ),
          if (!script.isBuiltIn)
            DSSheetAction(
              icon: DsIconKind.trash,
              label: 'app_delete'.tr,
              destructive: true,
              onTap: () {
                Navigator.pop(context);
                _deleteScript(script);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.scriptManager,
      child: Consumer<ScriptManager>(
        builder: (context, manager, child) {
          if (manager.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final scripts = _getFilteredScripts();

          if (scripts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.code_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty
                        ? '未找到匹配的脚本'
                        : '暂无脚本\n点击右下角按钮创建新脚本',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // 两列卡片网格（宽屏下按最大列宽自适应多列）；
          // 底部留出悬浮导航栏高度（extendBody 注入的 padding.bottom）
          return RefreshIndicator(
            onRefresh: _refreshScripts,
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
              itemCount: scripts.length,
              itemBuilder: (context, index) {
                final script = scripts[index];
                return ScriptCard(
                  script: script,
                  onTap: () => _showScriptDialog(script: script),
                  onLongPress: () => _showActionSheet(script),
                  onRun: () => _runScript(script),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
