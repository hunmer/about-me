import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'aboutme_nfc_method_channel.dart';
import 'aboutme_nfc.dart';

abstract class AboutmeNfcPlatform extends PlatformInterface {
  /// Constructs a AboutmeNfcPlatform.
  AboutmeNfcPlatform() : super(token: _token);

  static final Object _token = Object();

  static AboutmeNfcPlatform _instance = MethodChannelAboutmeNfc();

  /// The default instance of [AboutmeNfcPlatform] to use.
  ///
  /// Defaults to [MethodChannelAboutmeNfc].
  static AboutmeNfcPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AboutmeNfcPlatform] when
  /// they register themselves.
  static set instance(AboutmeNfcPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> isNfcSupported() {
    throw UnimplementedError('isNfcSupported() has not been implemented.');
  }

  Future<bool> isNfcEnabled() {
    throw UnimplementedError('isNfcEnabled() has not been implemented.');
  }

  Future<NfcReadResult> readNfc() {
    throw UnimplementedError('readNfc() has not been implemented.');
  }

  Future<NfcWriteResult> writeNfc(String data, {String formatType = 'TEXT'}) {
    throw UnimplementedError('writeNfc() has not been implemented.');
  }

  /// 写入多条 NFC 记录
  /// [records] 记录列表，每条记录包含 type 和 data
  /// type 支持: URI, TEXT, MIME, AAR, EXTERNAL
  Future<NfcWriteResult> writeNfcRecords(List<Map<String, String>> records) {
    throw UnimplementedError('writeNfcRecords() has not been implemented.');
  }

  Future<NfcWriteResult> writeNdefUrl(String url) {
    throw UnimplementedError('writeNdefUrl() has not been implemented.');
  }

  Future<NfcWriteResult> writeNdefText(String text) {
    throw UnimplementedError('writeNdefText() has not been implemented.');
  }

  Future<bool> openNfcSettings() {
    throw UnimplementedError('openNfcSettings() has not been implemented.');
  }
}
