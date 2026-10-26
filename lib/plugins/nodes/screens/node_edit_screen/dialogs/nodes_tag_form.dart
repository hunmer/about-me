import 'package:get/get.dart' hide Node;
import 'package:flutter/material.dart';

class NodesTagForm extends StatefulWidget {
  final Function(String) onTagAdded;

  const NodesTagForm({super.key, required this.onTagAdded});

  @override
  State<NodesTagForm> createState() => NodesTagFormState();
}

class NodesTagFormState extends State<NodesTagForm> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('nodes_tags'.tr),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: 'nodes_tags'.tr,
          border: const OutlineInputBorder(),
        ),
        autofocus: true,
        onSubmitted: (_) => _addTag(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('nodes_cancel'.tr),
        ),
        TextButton(onPressed: _addTag, child: Text('nodes_save'.tr)),
      ],
    );
  }

  void _addTag() {
    final tag = _controller.text.trim();
    if (tag.isNotEmpty) {
      widget.onTagAdded(tag);
      Navigator.pop(context);
    }
  }
}
