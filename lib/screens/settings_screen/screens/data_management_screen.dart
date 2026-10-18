import 'package:aboutme/widgets/file_management_screen.dart';

/// 兼容设置页及旧调用方，文件管理实现统一位于 widgets 中。
class DataManagementScreen extends FileManagementScreen {
  const DataManagementScreen({super.key, super.rootDirectory, super.title});
}
