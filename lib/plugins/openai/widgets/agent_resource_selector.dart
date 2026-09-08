import 'package:agentlib/agent_slots.dart';
import 'package:flutter/material.dart';

/// 弹出资源选择器，返回用户勾选的资源。
Future<List<AgentResourceItem>?> showAgentResourceSelector({
  required BuildContext context,
  required String title,
  required List<AgentResourceItem> resources,
  required List<AgentResourceItem> selected,
}) {
  return showModalBottomSheet<List<AgentResourceItem>>(
    context: context,
    isScrollControlled: true,
    builder:
        (context) => _AgentResourceSelector(
          title: title,
          resources: resources,
          selected: selected,
        ),
  );
}

class _AgentResourceSelector extends StatefulWidget {
  const _AgentResourceSelector({
    required this.title,
    required this.resources,
    required this.selected,
  });

  final String title;
  final List<AgentResourceItem> resources;
  final List<AgentResourceItem> selected;

  @override
  State<_AgentResourceSelector> createState() => _AgentResourceSelectorState();
}

class _AgentResourceSelectorState extends State<_AgentResourceSelector> {
  late final Set<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.selected.map((item) => item.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        widget.resources.where((item) {
          final query = _query.trim().toLowerCase();
          return query.isEmpty ||
              item.displayName.toLowerCase().contains(query) ||
              item.id.toLowerCase().contains(query) ||
              item.tags.any((tag) => tag.toLowerCase().contains(query));
        }).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Column(
          children: [
            ListTile(
              title: Text(widget.title),
              trailing: TextButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    widget.resources
                        .where((item) => _selected.contains(item.id))
                        .toList(),
                  );
                },
                child: const Text('完成'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '搜索资源',
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final item = visible[index];
                  return CheckboxListTile(
                    value: _selected.contains(item.id),
                    title: Text(item.displayName),
                    subtitle:
                        item.tags.isEmpty ? null : Text(item.tags.join(' · ')),
                    onChanged:
                        item.enabled
                            ? (value) => setState(() {
                              if (value == true) {
                                _selected.add(item.id);
                              } else {
                                _selected.remove(item.id);
                              }
                            })
                            : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
