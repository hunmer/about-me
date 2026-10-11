// 一次性数据迁移：旧加密存储 → 明文统一数据区。
//
// 用法：
//   dart run tool/migrate_to_plaintext.dart <DATA_DIR> <BASE64_32BYTE_KEY>
//
// 处理内容：
// 1. users/{id}/.storage/**（信封加密，12 字节 IV）→ 解密写入 users/{id}/{同路径}
// 2. users/{id}/{plugin}/*.json（旧版 iv.ciphertext 格式，16 字节 IV）→ 原地转明文
// 3. 删除 users/{id}/.key_verification.json（加密已取消，无意义）
// 4. 迁移完成后删除 .storage 目录
//
// 幂等：已是明文 JSON 的文件自动跳过；迁移前自动备份整个 DATA_DIR。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aboutme_data_sdk/io.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
      '用法: dart run tool/migrate_to_plaintext.dart <DATA_DIR> <BASE64_32BYTE_KEY>',
    );
    exit(2);
  }
  final dataDir = args[0];
  final key = args[1];

  if (!Directory(dataDir).existsSync()) {
    stderr.writeln('数据目录不存在: $dataDir');
    exit(2);
  }
  LegacyEncryption.validateKey(key);

  // 备份
  final backupDir = '$dataDir-backup-${DateTime.now().millisecondsSinceEpoch}';
  await _copyDirectory(Directory(dataDir), Directory(backupDir));
  stdout.writeln('已备份至 $backupDir');

  var migrated = 0;
  var skipped = 0;
  final failed = <String>[];

  final usersDir = Directory(p.join(dataDir, 'users'));
  if (!usersDir.existsSync()) {
    stdout.writeln('无用户数据，结束。');
    return;
  }

  for (final userDir in usersDir.listSync().whereType<Directory>()) {
    final userId = p.basename(userDir.path);
    final storageDir = Directory(p.join(userDir.path, '.storage'));

    // 1) .storage 信封区 → 用户根
    if (storageDir.existsSync()) {
      for (final file in storageDir
          .listSync(recursive: true)
          .whereType<File>()) {
        final relative = p.relative(file.path, from: storageDir.path);
        final target = File(p.join(userDir.path, relative));
        try {
          final plain = LegacyEncryption.decryptEnvelope(
            key,
            Uint8List.fromList(await file.readAsBytes()),
          );
          if (await target.exists()) {
            stdout.writeln('  [跳过] 已存在 $userId/$relative');
            skipped++;
          } else {
            await target.parent.create(recursive: true);
            await target.writeAsBytes(plain, flush: true);
            migrated++;
          }
        } catch (e) {
          failed.add('$userId/.storage/$relative: $e');
        }
      }
    }

    // 2) 插件旧格式加密文件 → 原地明文
    for (final file in userDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))) {
      if (p.basename(file.path).startsWith('.')) continue;
      // .storage 内的已在上面处理
      if (storageDir.existsSync() &&
          p.isWithin(storageDir.path, file.path)) {
        continue;
      }
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! Map<String, dynamic>) {
          skipped++; // 已是明文数组
          continue;
        }
        if (decoded['encrypted_data'] is String) {
          final plain = LegacyEncryption.decryptData(
            key,
            decoded['encrypted_data'] as String,
          );
          await file.writeAsString(
            const JsonEncoder.withIndent('  ').convert(plain),
            flush: true,
          );
          migrated++;
        } else {
          skipped++; // 已是明文
        }
      } catch (e) {
        failed.add('${p.relative(file.path, from: dataDir)}: $e');
      }
    }

    // 3) 密钥验证文件
    final kv = File(p.join(userDir.path, '.key_verification.json'));
    if (await kv.exists()) await kv.delete();

    // 4) 清理 .storage
    if (storageDir.existsSync()) {
      try {
        await storageDir.delete(recursive: true);
      } catch (_) {
        // 存在失败文件时保留目录以便排查
      }
    }
    stdout.writeln('用户 $userId 完成');
  }

  stdout.writeln('');
  stdout.writeln('迁移完成: $migrated 个文件转明文, $skipped 个跳过, ${failed.length} 个失败');
  for (final f in failed) {
    stdout.writeln('  失败: $f');
  }
  if (failed.isNotEmpty) {
    stdout.writeln('失败文件保留在原处，请检查密钥是否正确（备份在 $backupDir）。');
  }
}

Future<void> _copyDirectory(Directory source, Directory target) async {
  await target.create(recursive: true);
  for (final entity in source.listSync()) {
    final targetPath = p.join(target.path, p.basename(entity.path));
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(targetPath));
    } else if (entity is File) {
      await entity.copy(targetPath);
    }
  }
}
