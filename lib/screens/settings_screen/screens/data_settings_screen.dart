import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/settings_screen/screens/data_management_screen.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
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

    return SuperCupertinoNavigationWrapper(
      title: Text('data_management_dataManagementTitle'.tr),
      largeTitle: 'data_management_dataManagementTitle'.tr,
      enableLargeTitle: false,
      body: DSThemeBridge(
        child: Builder(
          builder: (context) {
            final ds = DSThemeBridge.resolve(context);
            return ListView(
              padding: EdgeInsets.fromLTRB(
                16.0,
                16.0,
                16.0,
                16.0 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                SettingsGroup(
                  title: 'settings_screen_importExportGroup'.tr,
                  children: [
                    SettingsTile(
                      icon: DsIconKind.upload,
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
                      icon: DsIconKind.storage,
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
                      icon: DsIconKind.download,
                      iconColor: DsAccentColors.emerald,
                      title: 'settings_screen_importDataTitle'.tr,
                      subtitle: 'settings_screen_importDataSubtitle'.tr,
                      onTap: _controller.importData,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsGroup(
                  title: 'settings_screen_backupRestoreGroup'.tr,
                  children: [
                    SettingsTile(
                      icon: DsIconKind.backup,
                      iconColor: DsAccentColors.violet,
                      title: 'settings_screen_fullBackupTitle'.tr,
                      subtitle: 'settings_screen_fullBackupSubtitle'.tr,
                      onTap: _controller.exportAllData,
                    ),
                    SettingsTile(
                      icon: DsIconKind.restore,
                      iconColor: DsAccentColors.amber,
                      title: 'settings_screen_fullRestoreTitle'.tr,
                      subtitle: 'settings_screen_fullRestoreSubtitle'.tr,
                      trailing: DsIcon(
                        DsIconKind.warning,
                        size: 20,
                        color: ds.danger,
                      ),
                      onTap: _controller.importAllData,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsGroup(
                  title: 'settings_screen_storageGroup'.tr,
                  children: [
                    SettingsTile(
                      icon: DsIconKind.cloud,
                      iconColor: DsAccentColors.teal,
                      title: 'settings_screen_storageBackend'.tr,
                      subtitle:
                          globalStorage.isRemote
                              ? 'settings_screen_storageHttpServer'.tr
                              : 'settings_screen_storageLocalFile'.tr,
                      onTap: () async {
                        final changed = await showDSDialog<bool>(
                          context: context,
                          theme: DSThemeBridge.resolve(context),
                          builder:
                              (context) => const StorageBackendSettingsDialog(),
                        );
                        if (changed == true && mounted) {
                          Toast.show(
                            'settings_screen_storageSavedRestart'.tr,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
