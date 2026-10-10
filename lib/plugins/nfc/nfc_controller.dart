import 'package:aboutme_nfc/aboutme_nfc.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:get/get.dart';

/// NFC 控制器 - 处理所有 NFC 相关的业务逻辑
class NfcController {
  final AboutmeNfc _nfc = AboutmeNfc();

  bool _isNfcSupported = false;
  bool _isNfcEnabled = false;

  bool get isNfcSupported => _isNfcSupported;
  bool get isNfcEnabled => _isNfcEnabled;

  /// 检查 NFC 状态
  Future<void> checkNfcStatus() async {
    try {
      _isNfcSupported = await _nfc.isNfcSupported();
      _isNfcEnabled = await _nfc.isNfcEnabled();
    } catch (e) {
      print('Error checking NFC status: $e');
    }
  }

  /// 读取 NFC 数据
  Future<NfcReadResult> readNfc() async {
    if (!_isNfcEnabled) {
      return NfcReadResult(
        success: false,
        error: 'nfc_nfcDisabled'.tr,
      );
    }

    try {
      final result = await _nfc.readNfc();
      return NfcReadResult(
        success: result.success,
        data: result.data,
        error: result.error,
      );
    } catch (e) {
      return NfcReadResult(
        success: false,
        error: 'nfc_readError'.trParams({'error': e.toString()}),
      );
    }
  }

  /// 写入多条 NFC 记录
  Future<NfcWriteResult> writeNfcRecords(List<Map<String, String>> records) async {
    if (!_isNfcEnabled) {
      return NfcWriteResult(
        success: false,
        error: 'nfc_nfcDisabled'.tr,
      );
    }

    try {
      final result = await _nfc.writeNfcRecords(records);
      return NfcWriteResult(
        success: result.success,
        error: result.error,
      );
    } catch (e) {
      return NfcWriteResult(
        success: false,
        error: 'nfc_writeError'.trParams({'error': e.toString()}),
      );
    }
  }

  /// 显示错误提示
  void showError(String message) {
    Toast.error(message);
  }

  /// 显示成功提示
  void showSuccess(String message) {
    Toast.success(message);
  }

  /// 打开 NFC 设置
  Future<void> openNfcSettings() async {
    try {
      final success = await _nfc.openNfcSettings();
      if (!success) {
        showError('nfc_openSettingsFailed'.tr);
      }
    } catch (e) {
      print('Error opening NFC settings: $e');
      showError('nfc_openSettingsError'.trParams({'error': e.toString()}));
    }
  }
}

/// NFC 读取结果
class NfcReadResult {
  final bool success;
  final String? data;
  final String? error;

  NfcReadResult({
    required this.success,
    this.data,
    this.error,
  });
}

/// NFC 写入结果
class NfcWriteResult {
  final bool success;
  final String? error;

  NfcWriteResult({
    required this.success,
    this.error,
  });
}
