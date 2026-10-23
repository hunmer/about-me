import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readHostSelectedFile(String selectedPath, int maxBytes) async {
  final file = File(selectedPath);
  if (await file.length() > maxBytes) throw ArgumentError('单个资源上限 16 MiB');
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (bytes.length + chunk.length > maxBytes) throw ArgumentError('单个资源上限 16 MiB');
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}
