import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';
import 'package:aboutme_data_sdk/src/services/migrations/notes_nodes_migration.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('notes_nodes_sdk_');
    data = AboutmeData.local(root.path);
  });
  tearDown(() async {
    await data.dispose();
    await root.delete(recursive: true);
  });
  dynamic ok(Map<String, dynamic> r) {
    expect(r['success'], true, reason: '$r');
    return r['data'];
  }

  Future<void> fixture(String path, dynamic value) async {
    final f = File(root.path + '/' + path);
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(value));
  }

  test(
    'notes legacy folders merge; moves preserve extensions; recursive delete removes files',
    () async {
      await fixture('notes/folders.json', [
        {'id': 'client', 'name': 'Client', 'extra': 1},
      ]);
      await fixture('notes/data.json', {
        'folders': [
          {'id': 'mcp', 'name': 'MCP'},
        ],
        'unknown': 'keep',
      });
      ok(
        await data.call('notes', 'createFolder', {
          'id': 'child',
          'name': 'Child',
          'parentId': 'client',
        }),
      );
      ok(
        await data.call('notes', 'create', {
          'id': 'n',
          'folderId': 'child',
          'title': 'A',
          'content': 'hello',
          'type': 'todo',
          'meta': '{}',
          'color': 42,
          'bgStyle': 2,
          'custom': {'x': 1},
        }),
      );
      final moved =
          ok(
                await data.call('notes', 'moveNote', {
                  'id': 'n',
                  'folderId': 'mcp',
                }),
              )
              as Map;
      expect(moved['custom'], {'x': 1});
      expect(moved['meta'], '{}');
      expect(moved['bgStyle'], 2);
      expect(
        (ok(await data.get('notes', 'getSnapshot'))['folders'] as List).length,
        3,
      );
      expect(
        (await data.call('notes', 'updateFolder', {
          'id': 'client',
          'parentId': 'child',
        }))['code'],
        'INVALID_PARAMS',
      );
      ok(
        await data.call('notes', 'moveNote', {'id': 'n', 'folderId': 'child'}),
      );
      ok(await data.call('notes', 'deleteFolder', {'id': 'client'}));
      expect(await File(root.path + '/notes/notes/n.json').exists(), false);
      expect(
        (ok(await data.get('notes', 'getSnapshot'))['notes'] as List),
        isEmpty,
      );
      expect(
        jsonDecode(
          await File(root.path + '/notes/data.json').readAsString(),
        )['unknown'],
        'keep',
      );
      expect(
        await File(root.path + '/notes/migration_v1_backup.json').exists(),
        true,
      );
    },
  );
  test(
    'two SDK instances append notes without losing index; idempotency persists',
    () async {
      final second = AboutmeData.local(root.path);
      try {
        await Future.wait(
          List.generate(20, (i) async {
            ok(
              await (i.isEven ? data : second).call('notes', 'create', {
                'id': 'n$i',
                'title': '$i',
                'clientMutationId': 'note-$i',
              }),
            );
          }),
        );
        expect(
          (ok(await data.get('notes', 'getSnapshot'))['notes'] as List).length,
          20,
        );
        ok(
          await second.call('notes', 'create', {
            'id': 'n1',
            'title': '1',
            'clientMutationId': 'note-1',
          }),
        );
        expect(
          (ok(await second.get('notes', 'getSnapshot'))['notes'] as List)
              .length,
          20,
        );
        final snapshot = await data.get('notes', 'getSnapshot');
        ok(
          await second.call('notes', 'update', {'id': 'n0', 'content': 'new'}),
        );
        expect(
          (await data.call('notes', 'update', {
            'id': 'n0',
            'title': 'stale',
            'expectedVersion': snapshot['version'],
          }))['code'],
          'CONFLICT',
        );
      } finally {
        await second.dispose();
      }
    },
  );
  test(
    'nodes patch preserves latest children, moves keep parent relation and reject cycles',
    () async {
      ok(
        await data.call('nodes', 'createNotebook', {
          'id': 'book',
          'title': 'Notebook',
        }),
      );
      ok(
        await data.call('nodes', 'createNode', {
          'notebookId': 'book',
          'id': 'a',
          'title': 'Parent',
          'unknown': {'keep': 1},
        }),
      );
      ok(
        await data.call('nodes', 'createNode', {
          'notebookId': 'book',
          'id': 'b',
          'title': 'Child',
          'parentId': 'a',
        }),
      );
      final edited =
          ok(
                await data.call('nodes', 'updateNode', {
                  'notebookId': 'book',
                  'id': 'a',
                  'title': 'Edited',
                  'children': [],
                }),
              )
              as Map;
      expect((edited['children'] as List).length, 1);
      expect(edited['unknown'], {'keep': 1});
      expect(
        (await data.call('nodes', 'updateNode', {
          'notebookId': 'book',
          'id': 'a',
          'parentId': 'b',
        }))['code'],
        'INVALID_PARAMS',
      );
      ok(
        await data.call('nodes', 'updateNode', {
          'notebookId': 'book',
          'id': 'b',
          'parentId': '',
        }),
      );
      final roots =
          ok(await data.get('nodes', 'getNotebook', {'id': 'book'}))['nodes']
              as List;
      expect(roots.length, 2);
      expect(roots[1]['parentId'], '');
      expect(roots[0]['children'], isEmpty);
      ok(
        await data.call('nodes', 'updateNotebook', {
          'id': 'book',
          'title': 'Renamed',
          'nodes': [],
        }),
      );
      expect(
        (ok(await data.get('nodes', 'getNotebook', {'id': 'book'}))['nodes']
                as List)
            .length,
        2,
      );
    },
  );
  test(
    'sample seeding is stable and never overwrites edits; corrupt data is preserved',
    () async {
      for (final plugin in ['notes', 'nodes']) {
        ok(await data.call(plugin, 'seedExamples', {'templateVersion': 1}));
        ok(await data.call(plugin, 'seedExamples', {'templateVersion': 1}));
      }
      expect(
        (ok(await data.get('notes', 'getSnapshot'))['notes'] as List).length,
        1,
      );
      expect(
        (ok(await data.get('nodes', 'getSnapshot'))['notebooks'] as List)
            .length,
        1,
      );
      ok(
        await data.call('notes', 'update', {
          'id': 'notes-example-intro-v1',
          'content': 'user edit',
        }),
      );
      ok(await data.call('notes', 'seedExamples'));
      expect(
        ok(
          await data.get('notes', 'getById', {'id': 'notes-example-intro-v1'}),
        )['content'],
        'user edit',
      );
      await fixture('nodes/nodes_notebooks.json', {'notebooks': 'broken'});
      expect(
        (await data.call('nodes', 'seedExamples'))['code'],
        'CORRUPT_DATA',
      );
      expect(
        jsonDecode(
          await File(root.path + '/nodes/nodes_notebooks.json').readAsString(),
        ),
        {'notebooks': 'broken'},
      );
    },
  );
  test(
    'maintenance restores exact original data, preserving a before-restore snapshot',
    () async {
      final original = {
        'notebooks': [
          {'id': 'legacy', 'title': 'Legacy', 'nodes': []},
        ],
        'unknown': {'keep': true},
      };
      await fixture('nodes/nodes_notebooks.json', original);
      await fixture('notes/folders.json', [
        {'id': 'legacy', 'name': 'Legacy', 'unknown': true},
      ]);
      ok(await data.call('nodes', 'seedExamples'));
      ok(await data.call('notes', 'create', {'id': 'new', 'title': 'New'}));
      final backend = LocalPluginBackend(root.path);
      for (final plugin in ['notes', 'nodes']) {
        ok(
          await backend.execute(
            pluginId: plugin,
            action: 'restoreMigrationBackup',
            resource: 'maintenance',
            isQuery: false,
            params: {},
            operation: (tx) async {
              if (plugin == 'notes') {
                await restoreNotesMigrationBackup(tx);
              } else {
                await restoreNodesMigrationBackup(tx);
              }
              return {'success': true};
            },
          ),
        );
      }
      expect(
        jsonDecode(
          await File(root.path + '/nodes/nodes_notebooks.json').readAsString(),
        ),
        original,
      );
      expect(
        jsonDecode(
          await File(root.path + '/notes/folders.json').readAsString(),
        ),
        [
          {'id': 'legacy', 'name': 'Legacy', 'unknown': true},
        ],
      );
      expect(await File(root.path + '/notes/notes/new.json').exists(), false);
      expect(
        await File(root.path + '/notes/before_restore.json').exists(),
        true,
      );
      expect(
        await File(root.path + '/nodes/before_restore.json').exists(),
        true,
      );
    },
  );
}
