import 'dart:typed_data';

import 'host_file_input_stub.dart'
    if (dart.library.io) 'host_file_input_io.dart' as platform;

/// 宿主选择器/录音器产生的外部输入，仅在宿主本机读取，不向服务器传路径。
Future<Uint8List> readHostSelectedFile(String selectedPath, int maxBytes) =>
    platform.readHostSelectedFile(selectedPath, maxBytes);
