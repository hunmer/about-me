import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// NFC 记录类型
enum NfcRecordType {
  uri('URI', Icons.link),
  text('TEXT', Icons.text_fields),
  mime('MIME', Icons.data_object),
  aar('AAR', Icons.android),
  external_('EXTERNAL', Icons.extension);

  final String value;
  final IconData icon;
  const NfcRecordType(this.value, this.icon);
}

extension NfcRecordTypeL10n on NfcRecordType {
  /// 本地化类型标签
  String get localizedLabel => switch (this) {
    NfcRecordType.uri => 'nfc_typeUri'.tr,
    NfcRecordType.text => 'nfc_typeText'.tr,
    NfcRecordType.mime => 'nfc_typeMime'.tr,
    NfcRecordType.aar => 'nfc_typeAar'.tr,
    NfcRecordType.external_ => 'nfc_typeExternal'.tr,
  };
}
