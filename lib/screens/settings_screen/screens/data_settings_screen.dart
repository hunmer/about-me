import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/screens/settings_screen/screens/data_management_screen.dart';
import '../controllers/settings_screen_controller.dart';
import '../widgets/settings_group.dart';
import '../widgets/storage_backend_settings_dialog.dart';

/// 数据管理：导入导出、全量备份恢复、存储后端
class DataSettingsScreen extends StatefulWidget {
  const DataSettingsScreen({super.key});

  @override
  State<DataSettingsScreen> createState() => _DataSettingsScreenState();
}

class _DataSettingsScreenState extends State<DataSettingsScreen> {
  late SettingsScreenController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SettingsScreenController();
    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    await _controller.initializeControllers(context);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isInitialized()) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('数据管理')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16.0,
          16.0,
          16.0,
          16.0 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          SettingsGroup(
            title: '导入导出',
            children: [
              ListTile(
                leading: const Icon(Icons.upload),
                title: Text('settings_screen_exportDataTitle'.tr),
                subtitle: Text('settings_screen_exportDataSubtitle'.tr),
                onTap: () {
                  if (mounted) {
                    _controller.exportData(context);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.storage),
                title: Text('settings_screen_dataManagementTitle'.tr),
                subtitle: Text('settings_screen_dataManagementSubtitle'.tr),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  NavigationHelper.push(
                    context,
                    DataManagementScreen(),
                    routeName: '/settings/data_management',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: Text('settings_screen_importDataTitle'.tr),
                subtitle: Text('settings_screen_importDataSubtitle'.tr),
                onTap: _controller.importData,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsGroup(
            title: '备份与恢复',
            children: [
              ListTile(
                leading: const Icon(Icons.backup),
                title: Text('settings_screen_fullBackupTitle'.tr),
                subtitle: Text('settings_screen_fullBackupSubtitle'.tr),
                onTap: _controller.exportAllData,
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: Text('settings_screen_fullRestoreTitle'.tr),
                subtitle: Text('settings_screen_fullRestoreSubtitle'.tr),
                onTap: _controller.importAllData,
                trailing: const Icon(Icons.warning, color: Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsGroup(
            title: '存储',
            children: [
              ListTile(
                leading: const Icon(Icons.cloud),
                title: const Text('数据存储后端'),
                subtitle: Text(globalStorage.isRemote ? 'HTTP 服务器' : '本地文件'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final changed = await showDialog<bool>(
                    context: context,
                    builder: (context) => const StorageBackendSettingsDialog(),
                  );
                  if (changed == true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('设置已保存，请重新启动应用')),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
