// HTTP 远端存储（明文 + ETag 版本管理）已下沉到纯数据 SDK，
// 此文件保留原 import 路径做转发；设备 ID 全局默认值见 DeviceIdentity。
export 'package:aboutme_data_sdk/aboutme_data_sdk.dart'
    show HttpStorage, HttpStorageDefaults, StorageException, StorageErrorKind;
