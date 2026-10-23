import 'dart:async';
import 'dart:convert';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/plugins/nodes/models/node.dart';
import 'package:aboutme/plugins/nodes/models/notebook.dart';

import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/services/plugin_widget_sync_helper.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/item_event_args.dart';

class NodesController extends ChangeNotifier {
  final StorageManager _storageManager; // ignore: unused_field
  List<Notebook> _notebooks = [];
  Notebook? _selectedNotebook;

  NodesController(this._storageManager) {
    _watch = AboutmeDataService.instance.data
        .watch('nodes', 'getSnapshot')
        .listen((snapshot) {
          queryStatus = snapshot.status;
          queryError = snapshot.error;
          if (snapshot.result != null) _apply(snapshot.result!);
          notifyListeners();
        });
  }
  StreamSubscription<QuerySnapshot>? _watch;
  QueryStatus queryStatus = QueryStatus.loading;
  Object? queryError;
  int? _version;
  final _rawNodes = <String, Map<String, dynamic>>{};
  final _rawNotebooks = <String, Map<String, dynamic>>{};
  AboutmeData get _data => AboutmeDataService.instance.data;

  void _apply(Map<String, dynamic> response) {
    final selected = _selectedNotebook?.id;
    final values = (response['data'] as Map)['notebooks'] as List;
    _version = response['version'] as int?;
    _rawNodes.clear();
    _rawNotebooks.clear();
    void collect(List xs) {
      for (final n in xs) {
        final json = Map<String, dynamic>.from(n as Map);
        n['_sdkVersion'] = _version;
        _rawNodes[json['id'] as String] = json;
        collect(json['children'] as List);
      }
    }

    for (final nb in values) {
      final raw = Map<String, dynamic>.from(nb as Map);
      nb['_sdkVersion'] = _version;
      _rawNotebooks[raw['id'] as String] = raw;
      collect(raw['nodes'] as List);
    }
    _notebooks = values
        .map((x) => Notebook.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList();
    _selectedNotebook =
        _notebooks.where((n) => n.id == selected).firstOrNull ??
        _notebooks.firstOrNull;
  }

  Map<String, dynamic> _diff(
    Map<String, dynamic> next,
    Map<String, dynamic>? old,
  ) => {
    for (final e in next.entries)
      if (!{'nodes', 'children', 'createdAt'}.contains(e.key) &&
          (old == null || jsonEncode(old[e.key]) != jsonEncode(e.value)))
        e.key: e.value,
  };
  Future<void> _command(
    String action,
    Map<String, dynamic> params, {
    bool edit = false,
    int? editingVersion,
  }) async {
    final response = await _data.call('nodes', action, {
      ...params,
      if (edit && _version != null)
        'expectedVersion': editingVersion ?? _version,
    });
    if (response['success'] != true) throw QueryFailure(response);
    await reloadData();
    await PluginWidgetSyncHelper.instance.syncNodes();
  }

  // ========== 事件通知 ==========

  /// 触发笔记本事件
  void _notifyNotebookEvent(String action, Notebook notebook) {
    final eventArgs = ItemEventArgs(
      eventName: 'nodes_notebook_$action',
      itemId: notebook.id,
      title: notebook.title,
      action: action,
    );
    EventManager.instance.broadcast('nodes_notebook_$action', eventArgs);
  }

  /// 触发节点事件
  void _notifyNodeEvent(String action, Node node, String notebookId) {
    final eventArgs = ItemEventArgs(
      eventName: 'nodes_node_$action',
      itemId: node.id,
      title: node.title,
      action: action,
    );
    EventManager.instance.broadcast('nodes_node_$action', eventArgs);
  }

  List<Notebook> get notebooks => _notebooks;
  Notebook? get selectedNotebook => _selectedNotebook;

  Notebook? getNotebook(String notebookId) {
    return _notebooks.firstWhere(
      (notebook) => notebook.id == notebookId,
      orElse: () => Notebook(id: '', title: '', icon: Icons.book),
    );
  }

  Future<void> clearNodes(String notebookId) async {
    await _command('clearNodes', {'notebookId': notebookId}, edit: true);
  }

  void selectNotebook(Notebook notebook) {
    _selectedNotebook = notebook;
    notifyListeners();
  }

  /// 重新加载数据（供同步后刷新使用）
  Future<void> reloadData() async {
    queryStatus = QueryStatus.loading;
    notifyListeners();
    try {
      _apply(await _data.query('nodes', 'getSnapshot'));
      queryStatus = QueryStatus.data;
      queryError = null;
    } catch (e) {
      queryError = e;
      queryStatus = _notebooks.isEmpty ? QueryStatus.error : QueryStatus.stale;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadSampleData() async {
    await _command('seedExamples', {'templateVersion': 1});
  }

  Future<void> addNotebook(
    String title,
    IconData icon, {
    String? id,
    Color color = Colors.blue,
  }) async {
    final notebookId = id ?? const Uuid().v4();
    await _command('createNotebook', {
      'id': notebookId,
      'title': title,
      'icon': icon.codePoint,
      'color': color.value,
    });
    final created = getNotebook(notebookId);
    if (created != null) _notifyNotebookEvent('added', created);
  }

  Future<void> updateNotebook(Notebook notebook) async {
    await _command(
      'updateNotebook',
      {
        'id': notebook.id,
        ..._diff(notebook.toJson(), _rawNotebooks[notebook.id]),
      },
      edit: true,
      editingVersion: notebook.sdkVersion,
    );
    _notifyNotebookEvent('updated', notebook);
  }

  Future<void> deleteNotebook(String notebookId) async {
    final old = getNotebook(notebookId);
    await _command('deleteNotebook', {'id': notebookId}, edit: true);
    if (old != null && old.id.isNotEmpty) _notifyNotebookEvent('deleted', old);
  }

  Future<void> reorderNotebooks(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= _notebooks.length ||
        newIndex >= _notebooks.length)
      return;
    final ids = _notebooks.map((n) => n.id).toList();
    ids.insert(newIndex, ids.removeAt(oldIndex));
    await _command('reorderNotebooks', {'ids': ids}, edit: true);
  }

  // Node operations
  Future<void> addNode(String notebookId, Node node, {String? parentId}) async {
    await _command('createNode', {
      'notebookId': notebookId,
      ...node.toJson(),
      'parentId': node.parentId.isNotEmpty ? node.parentId : (parentId ?? ''),
    });
    _notifyNodeEvent('added', node, notebookId);
  }

  Future<void> updateNode(String notebookId, Node updatedNode) async {
    final wasDone =
        _rawNodes[updatedNode.id]?['status'] == NodeStatus.done.index;
    await _command(
      'updateNode',
      {
        'notebookId': notebookId,
        'id': updatedNode.id,
        ..._diff(updatedNode.toJson(), _rawNodes[updatedNode.id]),
      },
      edit: true,
      editingVersion: updatedNode.sdkVersion,
    );
    _notifyNodeEvent('updated', updatedNode, notebookId);
    if (!wasDone && updatedNode.status == NodeStatus.done)
      EventManager.instance.broadcast(
        'node_status_done',
        EventArgs('node_status_done'),
      );
  }

  Future<void> deleteNode(String notebookId, String nodeId) async {
    final old = findNodeById(notebookId, nodeId);
    await _command('deleteNode', {
      'notebookId': notebookId,
      'id': nodeId,
    }, edit: true);
    if (old != null) _notifyNodeEvent('deleted', old, notebookId);
  }

  Future<void> toggleNodeExpansion(String notebookId, String nodeId) async {
    final notebookIndex = _notebooks.indexWhere(
      (notebook) => notebook.id == notebookId,
    );
    if (notebookIndex == -1) return;

    _toggleNodeExpansionInList(_notebooks[notebookIndex].nodes, nodeId);

    notifyListeners();
  }

  bool _toggleNodeExpansionInList(List<Node> nodes, String nodeId) {
    for (int i = 0; i < nodes.length; i++) {
      if (nodes[i].id == nodeId) {
        nodes[i].isExpanded = !nodes[i].isExpanded;
        return true;
      }

      if (nodes[i].children.isNotEmpty) {
        if (_toggleNodeExpansionInList(nodes[i].children, nodeId)) {
          return true;
        }
      }
    }
    return false;
  }

  List<String> getNodePath(String notebookId, String nodeId) {
    final notebookIndex = _notebooks.indexWhere(
      (notebook) => notebook.id == notebookId,
    );
    if (notebookIndex == -1) return [];

    List<String> path = [];
    _findNodePath(_notebooks[notebookIndex].nodes, nodeId, path);
    return path.reversed.toList();
  }

  List<String> getNodePathIds(String notebookId, String nodeId) {
    final notebookIndex = _notebooks.indexWhere(
      (notebook) => notebook.id == notebookId,
    );
    if (notebookIndex == -1) return [];

    List<String> pathIds = [];
    _findNodePathIds(_notebooks[notebookIndex].nodes, nodeId, pathIds);
    return pathIds.reversed.toList();
  }

  bool _findNodePathIds(List<Node> nodes, String nodeId, List<String> pathIds) {
    for (final node in nodes) {
      if (node.id == nodeId) {
        pathIds.add(node.id);
        return true;
      }

      if (node.children.isNotEmpty) {
        if (_findNodePathIds(node.children, nodeId, pathIds)) {
          pathIds.add(node.id);
          return true;
        }
      }
    }
    return false;
  }

  bool _findNodePath(List<Node> nodes, String nodeId, List<String> path) {
    for (final node in nodes) {
      if (node.id == nodeId) {
        path.add(node.title);
        return true;
      }

      if (node.children.isNotEmpty) {
        if (_findNodePath(node.children, nodeId, path)) {
          path.add(node.title);
          return true;
        }
      }
    }
    return false;
  }

  // 通过ID查找节点
  Node? findNodeById(String notebookId, String nodeId) {
    final notebookIndex = _notebooks.indexWhere(
      (notebook) => notebook.id == notebookId,
    );
    if (notebookIndex == -1) return null;

    return _findNodeInList(_notebooks[notebookIndex].nodes, nodeId);
  }

  Node? _findNodeInList(List<Node> nodes, String nodeId) {
    for (final node in nodes) {
      if (node.id == nodeId) {
        return node;
      }

      if (node.children.isNotEmpty) {
        final foundNode = _findNodeInList(node.children, nodeId);
        if (foundNode != null) {
          return foundNode;
        }
      }
    }
    return null;
  }

  // 获取节点的所有同级节点（包括自身）
  List<Node> getSiblingNodes(String notebookId, String nodeId) {
    final notebookIndex = _notebooks.indexWhere(
      (notebook) => notebook.id == notebookId,
    );
    if (notebookIndex == -1) return [];

    // 如果是根节点，返回所有根节点
    final targetNode = findNodeById(notebookId, nodeId);
    if (targetNode == null) return [];

    if (targetNode.parentId.isEmpty) {
      return _notebooks[notebookIndex].nodes;
    }

    // 找到父节点
    final parentNode = findNodeById(notebookId, targetNode.parentId);
    if (parentNode == null) return [];

    // 返回父节点的所有子节点
    return parentNode.children;
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }
}
