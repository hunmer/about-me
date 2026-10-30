// 一次性批量迁移脚本：DateTime.parse/tryParse → 统一入口 parseIsoDateTime/tryParseIsoDateTime
// 用后即删。排除 *.g.dart 生成文件。
import 'dart:io';

void main() {
  final roots = [
    Directory('lib'),
    Directory('shared_models/lib'),
  ];
  final importLine = "import 'package:shared_models/shared_models.dart';";
  final importRe = RegExp(r"^import\s+'package:shared_models/shared_models\.dart';", multiLine: true);
  final parseRe = RegExp(r'\bDateTime\.parse\(');
  final tryParseRe = RegExp(r'\bDateTime\.tryParse\(');
  var changedFiles = 0, changedSites = 0, addedImports = 0;

  for (final root in roots) {
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      if (entity.path.replaceAll('\\', '/').endsWith('utils/iso_date_time.dart')) continue;
      final original = entity.readAsStringSync();
      var content = original;
      var sites = 0;
      content = content.replaceAllMapped(parseRe, (m) { sites++; return 'parseIsoDateTime('; });
      content = content.replaceAllMapped(tryParseRe, (m) { sites++; return 'tryParseIsoDateTime('; });
      if (sites == 0) continue;

      // 已导入 shared_models 总入口则不重复加 import
      if (!importRe.hasMatch(content)) {
        final imports = RegExp(r'^import\s+[^\n]+;\s*$', multiLine: true);
        final matches = imports.allMatches(content).toList();
        if (matches.isEmpty) {
          content = '$importLine\n$content';
        } else {
          final last = matches.last;
          content = content.replaceRange(last.end, last.end, '\n$importLine');
        }
        addedImports++;
      }
      entity.writeAsStringSync(content);
      changedFiles++;
      changedSites += sites;
      // ignore: avoid_print
      print('  ${entity.path} ($sites)');
    }
  }
  print('DONE files=$changedFiles sites=$changedSites addedImports=$addedImports');
}
