import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

class ChannelGroupSelector extends StatelessWidget {
  final String selectedGroup;
  final List<String> availableGroups;
  final Function(String) onGroupSelected;

  const ChannelGroupSelector({
    super.key,
    required this.selectedGroup,
    required this.availableGroups,
    required this.onGroupSelected,
  });

  getGroupName(String group, BuildContext context) {
    switch (group) {
      case "all":
        return 'chat_all'.tr;
      case "ungrouped":
        return 'chat_ungrouped'.tr;
      case "archived":
        return 'chat_archived'.tr;
      default:
        return group;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: DSChipBar(
              labels: [
                for (final group in availableGroups)
                  getGroupName(group, context),
              ],
              selected: availableGroups.indexOf(selectedGroup),
              onChanged: (index) => onGroupSelected(availableGroups[index]),
            ),
          );
        },
      ),
    );
  }
}
