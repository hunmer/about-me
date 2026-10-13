import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/screens/settings_screen/screens/data_management_screen.dart';
import '../controllers/settings_screen_controller.dart';
import '../widgets/settings_group.dart';
import '../widgets/settings_tile.dart';
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
      appBar: AppBar(title: Text('data_management_dataManagementTitle'.tr)),
      body: DSThemeBridge(
        child: ListView(
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
                SettingsTile(
                  icon: Icons.upload,
                  iconColor: DsAccentColors.orange,
                  title: 'settings_screen_exportDataTitle'.tr,
                  subtitle: 'settings_screen_exportDataSubtitle'.tr,
                  onTap: () {
                    if (mounted) {
                      _controller.exportData(context);
                    }
                  },
                ),
                SettingsTile(
                  icon: Icons.storage,
                  iconColor: DsAccentColors.blue,
                  title: 'settings_screen_dataManagementTitle'.tr,
                  subtitle: 'settings_screen_dataManagementSubtitle'.tr,
                  onTap: () {
                    NavigationHelper.push(
                      context,
                      DataManagementScreen(),
                      routeName: '/settings/data_management',
                    );
                  },
                ),
                SettingsTile(
                  icon: Icons.download,
                  iconColor: DsAccentColors.emerald,
                  title: 'settings_screen_importDataTitle'.tr,
                  subtitle: 'settings_screen_importDataSubtitle'.tr,
                  onTap: _controller.importData,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsGroup(
              title: '备份与恢复',
              children: [
                SettingsTile(
                  icon: Icons.backup,
                  iconColor: DsAccentColors.violet,
                  title: 'settings_screen_fullBackupTitle'.tr,
                  subtitle: 'settings_screen_fullBackupSubtitle'.tr,
                  onTap: _controller.exportAllData,
                ),
                SettingsTile(
                  icon: Icons.restore,
                  iconColor: DsAccentColors.amber,
                  title: 'settings_screen_fullRestoreTitle'.tr,
                  subtitle: 'settings_screen_fullRestoreSubtitle'.tr,
                  trailing: const Icon(Icons.warning, color: Colors.orange),
                  onTap: _controller.importAllData,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsGroup(
              title: '存储',
              children: [
                SettingsTile(
                  icon: Icons.cloud,
                  iconColor: DsAccentColors.teal,
                  title: '数据存储后端',
                  subtitle: globalStorage.isRemote ? 'HTTP 服务器' : '本地文件',
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
      ),
    );
  }
}
