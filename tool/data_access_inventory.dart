// Standalone tool using the SDK package config to avoid Flutter native hooks.
// dart --packages=packages/aboutme_data_sdk/.dart_tool/package_config.json tool/data_access_inventory.dart [--write]
// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';

const _baseline = 'docs/data_access_inventory.json';
const _roots = [
  'lib',
  'packages/aboutme_server/lib',
  'packages/aboutme_server/admin-vue',
  'android',
  'ios',
  'macos',
  'windows',
  'linux',
  'web',
];
const _fileMethods = {
  'readPath',
  'writePath',
  'readPathText',
  'deletePath',
  'existsPath',
  'listPathKeys',
  'clearPathPrefix',
  'readFile',
  'writeFile',
  'deleteFile',
  'read',
  'write',
  'readBytes',
  'writeBytes',
  'saveData',
  'loadData',
  'removeData',
  'saveJson',
  'loadJson',
  'hasData',
  'getKeysWithPrefix',
  'clearWithPrefix',
  'readString',
  'writeString',
  'readAsString',
  'writeAsString',
  'readAsBytes',
  'writeAsBytes',
  'openWrite',
  'readAsStringSync',
  'writeAsStringSync',
  'readAsBytesSync',
  'writeAsBytesSync',
  'createDirectory',
  'getApplicationDataDirectory',
  'materializeToTemporaryFile',
};

Future<void> main(List<String> args) async {
  final accesses = <Map<String, dynamic>>[];
  final entries = <String, List<Map<String, dynamic>>>{};
  for (final root in _roots) {
    if (!Directory(root).existsSync()) continue;
    final files = Directory(root)
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where(
          (file) => !file.path.replaceAll('\\', '/').contains('/node_modules/'),
        );
    for (final file in files) {
      final path = file.path.replaceAll('\\', '/');
      if (path.endsWith('.dart')) {
        final parsed = parseString(
          content: file.readAsStringSync(),
          path: path,
          throwIfDiagnostics: false,
        );
        parsed.unit.accept(
          _AccessVisitor(path, parsed.lineInfo.getLocation, accesses),
        );
        if (path.startsWith('lib/plugins/') && path.split('/').length > 3) {
          final plugin = path.split('/')[2];
          final tags = [
            'ui',
            'repository',
            'usecase',
            'js',
            'tool',
            'widget',
            'background',
            'sample',
            'import',
            'export',
            'controller',
            'service',
            'model',
            'utils',
          ].where((tag) => path.toLowerCase().contains(tag)).toList();
          (entries[plugin] ??= []).add({
            'path': path,
            'roles': tags.isEmpty ? ['other'] : tags,
          });
        }
      } else if (RegExp(
        r'\.(vue|ts|js|kt|java|swift|m|mm|cpp|h)$',
      ).hasMatch(path)) {
        final lines = file.readAsLinesSync();
        for (var index = 0; index < lines.length; index++) {
          if (RegExp(
            r'/storage/files|SharedPreferences|UserDefaults|FileManager|FileInputStream|FileOutputStream',
          ).hasMatch(lines[index])) {
            accesses.add({
              'path': path,
              'line': index + 1,
              'kind': 'platform-or-admin',
              'code': lines[index].trim(),
              'classification': 'needs-review',
            });
          }
        }
      }
    }
  }
  accesses.sort(
    (a, b) =>
        '${a['path']}:${a['line']}'.compareTo('${b['path']}:${b['line']}'),
  );
  final actions = [
    for (final config in pluginRouteConfigs)
      {
        'pluginId': config.pluginId,
        'actions': [
          for (final route in config.routes)
            {
              'actionId': '${config.pluginId}.${route.handler}',
              'method': route.method.toUpperCase(),
              'path': route.path,
              'resource': route.resourceName,
              'capabilityVersion': 1,
            },
        ],
      },
  ];
  final inventory = {
    'schemaVersion': 1,
    'entries': entries,
    'actions': actions,
    'accesses': accesses,
  };
  if (args.contains('--write')) {
    File(_baseline).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(inventory)}\n',
    );
    stdout.writeln(
      'Inventory: ${entries.length} plugin directories, ${accesses.length} access candidates.',
    );
    return;
  }
  if (!File(_baseline).existsSync()) throw StateError('Missing $_baseline');
  final baseline = jsonDecode(File(_baseline).readAsStringSync()) as Map;
  Map<String, int> counts(List<dynamic> records) {
    final result = <String, int>{};
    for (final record in records) {
      final key = jsonEncode([record['path'], record['kind'], record['code']]);
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }

  final allowed = counts(baseline['accesses'] as List);
  final current = counts(accesses);
  final violations = current.entries.where(
    (entry) => entry.value > (allowed[entry.key] ?? 0),
  );
  if (violations.isNotEmpty) {
    stderr.writeln(
      'New file access candidates require review:\n${violations.map((e) => e.key).join('\n')}',
    );
    exitCode = 1;
  } else {
    stdout.writeln(
      'Architecture baseline passed: ${accesses.length} remaining candidates.',
    );
  }
}

class _AccessVisitor extends RecursiveAstVisitor<void> {
  _AccessVisitor(this.path, this.location, this.output);
  final String path;
  final dynamic Function(int) location;
  final List<Map<String, dynamic>> output;
  void add(AstNode node, String kind) => output.add({
    'path': path,
    'line': location(node.offset).lineNumber,
    'kind': kind,
    'code': node.toSource(),
    'classification': path.startsWith('lib/core/storage/')
        ? 'platform-adapter-pending-move'
        : 'needs-review',
  });
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_fileMethods.contains(node.methodName.name)) {
      add(node, 'file-method-candidate');
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (RegExp(
      r'(^|\.)(File|Directory|RandomAccessFile)(\.|$)',
    ).hasMatch(node.constructorName.toSource())) {
      add(node, 'direct-io-candidate');
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    if (RegExp(
      r'mobile_storage|web_storage|http_storage|aboutme_data_sdk/src/',
    ).hasMatch(node.uri.stringValue ?? '')) {
      add(node, 'persistence-import');
    }
    super.visitImportDirective(node);
  }
}
