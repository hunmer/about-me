import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aboutme_data_sdk/io.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

/// 迁移工具测试：旧加密数据（.storage 信封 + 插件 legacy 格式）→ 明文统一区。
///
/// 脚本本体是 tool/migrate_to_plaintext.dart（main 入口不易单测），
/// 此处按相同逻辑内联验证 SDK 解密能力与迁移语义。
void main() {
  const key = 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=';

  // 构造 .storage 信封格式（12 字节 IV AES-GCM）
  Uint8List buildEnvelope(String plaintext) {
    final iv = Uint8List.fromList(List.generate(12, (_) => 7));
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(LegacyEncryption.validateKey(key)),
          16 * 8,
          iv,
          Uint8List(0),
        ),
      );
    final encrypted = cipher.process(
      Uint8List.fromList(utf8.encode(plaintext)),
    );
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': 1,
          'iv': base64Encode(iv),
          'ciphertext': base64Encode(encrypted),
        }),
      ),
    );
  }

  test('信封解密（12 字节 IV）往返', () {
    final envelope = buildEnvelope('{"tasks":[{"id":"x"}]}');
    final plain = utf8.decode(
      LegacyEncryption.decryptEnvelope(key, envelope),
    );
    expect(plain, '{"tasks":[{"id":"x"}]}');
  });

  test('legacy 解密与 PluginDataStore 造数往返（迁移前置能力）', () async {
    final dir = await Directory.systemTemp.createTemp('migrate_test');
    addTearDown(() => dir.delete(recursive: true));
    final store = PluginDataStore(dir.path);

    await store.writePluginData('u1', 'todo', 'tasks.json', {
      'tasks': [
        {'id': 't1', 'title': '旧数据'},
      ],
    }, key);

    // 读取 legacy 文件并按迁移逻辑解密转明文
    final file = File('${dir.path}/users/u1/todo/tasks.json');
    final decoded = jsonDecode(await file.readAsString()) as Map;
    final plain = LegacyEncryption.decryptData(
      key,
      decoded['encrypted_data'] as String,
    );
    await file.writeAsString(jsonEncode(plain));

    // 明文可被统一数据区直接读取
    expect(jsonDecode(await file.readAsString()), {
      'tasks': [
        {'id': 't1', 'title': '旧数据'},
      ],
    });
  });
}
