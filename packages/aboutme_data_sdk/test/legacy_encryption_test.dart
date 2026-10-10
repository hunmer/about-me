import 'dart:convert';
import 'dart:io';

import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  const key = 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=';

  test('解密 nodejs EncryptionService 加密的数据（固定 IV 向量）', () {
    // 由 nodejs crypto aes-256-gcm 生成：
    // iv=16字节, 格式 base64(iv).base64(ciphertext+authTag)
    const encrypted =
        'aGVsbG8gaXYgMTZieHRl.NeEF3POH0oGcmG3Q8B6KspP58icInmmwF36IrC2LagcblH/oD16/GA==';
    const plaintext = '{"b":2,"a":[1,"x",null]}';

    expect(LegacyEncryption.decryptString(key, encrypted), plaintext);
    expect(LegacyEncryption.decryptData(key, encrypted), {
      'b': 2,
      'a': [1, 'x', null],
    });
  });

  test('加密往返；错误密钥解密失败', () {
    final encrypted = LegacyEncryption.encryptString(key, 'secret-plain');
    expect(encrypted.contains('.'), isTrue);
    expect(LegacyEncryption.decryptString(key, encrypted), 'secret-plain');

    expect(
      () => LegacyEncryption.decryptString(
        'AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcMGRI=',
        encrypted,
      ),
      throwsA(anything),
    );
  });

  test('规范化 MD5 与 nodejs 一致', () {
    // nodejs: normalizeJson(递归排序key) + md5(JSON.stringify(...))
    const data = {
      'z': 1,
      'a': {'d': 3, 'b': 2},
      'arr': [
        {'y': 1, 'x': 2},
      ],
    };
    expect(
      LegacyEncryption.computeDynamicMd5(data),
      '8a975800f970a8bdb8c53b6dc8035a96',
    );
  });

  test('密钥长度校验', () {
    expect(() => LegacyEncryption.validateKey('AQIDBA=='), throwsA(anything));
    expect(LegacyEncryption.validateKey(key).length, 32);
  });

  test('PluginDataStore 写读删 + 密钥验证文件', () async {
    final dir = await Directory.systemTemp.createTemp('plugin_store_test');
    addTearDown(() => dir.delete(recursive: true));
    final store = PluginDataStore(dir.path);
    const todoData = {
      'tasks': [
        {'id': 't1', 'title': 'hello'},
      ],
    };

    await store.writePluginData('u1', 'todo', 'data.json', todoData, key);
    expect(await store.readPluginData('u1', 'todo', 'data.json', key),
        todoData);

    // 落盘为旧版加密文件格式（服务端不落明文）
    final raw = File('${dir.path}/users/u1/todo/data.json');
    expect(await raw.exists(), isTrue);
    final rawJson = jsonDecode(await raw.readAsString()) as Map<String, dynamic>;
    expect(rawJson.containsKey('encrypted_data'), isTrue);
    expect(rawJson.containsKey('md5'), isTrue);
    expect((rawJson['encrypted_data'] as String).contains('hello'), isFalse);

    expect(await store.listPluginFiles('u1', 'todo'), ['data.json']);
    expect(await store.deletePluginFile('u1', 'todo', 'data.json'), isTrue);
    expect(await store.readPluginData('u1', 'todo', 'data.json', key), isNull);

    // 密钥验证文件：首次通过 → 创建 → 正确密钥通过 → 错误密钥拒绝
    expect(await store.hasKeyVerificationFile('u1'), isFalse);
    expect(await store.verifyEncryptionKey('u1', key), (true, null));
    await store.createKeyVerificationFile('u1', key);
    expect(await store.verifyEncryptionKey('u1', key), (true, null));
    final wrong = await store.verifyEncryptionKey(
      'u1',
      'AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcMGRI=',
    );
    expect(wrong.$1, isFalse);
  });
}
