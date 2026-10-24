import 'package:aboutme/plugins/notes/models/folder.dart';
import 'package:aboutme/plugins/notes/models/folder_tree_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> folderJson(String id) => {
    'id': id,
    'name': id,
    'createdAt': '2026-10-24T06:17:46.825Z',
    'updatedAt': '2026-10-24T06:17:46.825Z',
  };

  test('MCP 未指定父级和旧数据 null 父级均显示在根目录及文件夹树', () {
    final root = Folder.fromJson(folderJson('root'));
    final omitted = Folder.fromJson(folderJson('mcp-created'));
    final explicitNull = Folder.fromJson({
      ...folderJson('legacy'),
      'parentId': null,
    });
    final nested = Folder.fromJson({
      ...folderJson('nested'),
      'parentId': omitted.id,
    });
    expect(root.parentId, isNull);
    expect(omitted.parentId, 'root');
    expect(explicitNull.parentId, 'root');
    expect(nested.parentId, omitted.id);

    final folders = [root, omitted, explicitNull, nested];
    expect(
      folders.where((f) => f.parentId == 'root').map((f) => f.id),
      unorderedEquals(['mcp-created', 'legacy']),
    );
    final tree = FolderTreeNode.buildTree(root, {
      for (final folder in folders) folder.id: folder,
    });
    expect(tree.children.keys, unorderedEquals(['mcp-created', 'legacy']));
    expect(tree.children['mcp-created']!.children.keys, ['nested']);
  });
}
