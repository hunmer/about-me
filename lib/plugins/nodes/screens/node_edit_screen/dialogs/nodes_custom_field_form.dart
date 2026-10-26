import 'package:get/get.dart' hide Node;
import 'package:flutter/material.dart';
import 'package:aboutme/plugins/nodes/models/node.dart';

class NodesCustomFieldForm extends StatefulWidget {
  final Function(NodeCustomField) onCustomFieldAdded;

  const NodesCustomFieldForm({super.key, required this.onCustomFieldAdded});

  @override
  State<NodesCustomFieldForm> createState() => NodesCustomFieldFormState();
}

class NodesCustomFieldFormState extends State<NodesCustomFieldForm> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('nodes_addCustomField'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'nodes_key'.tr,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _valueController,
            decoration: InputDecoration(
              labelText: 'nodes_value'.tr,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('nodes_cancel'.tr),
        ),
        TextButton(onPressed: _addCustomField, child: Text('nodes_save'.tr)),
      ],
    );
  }

  void _addCustomField() {
    final name = _nameController.text.trim();
    final value = _valueController.text.trim();
    if (name.isNotEmpty) {
      widget.onCustomFieldAdded(NodeCustomField(key: name, value: value));
      Navigator.pop(context);
    }
  }
}
