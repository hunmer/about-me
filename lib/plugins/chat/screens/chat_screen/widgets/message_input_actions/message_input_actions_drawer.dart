import 'package:flutter/widgets.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'types.dart';

/// 消息输入动作抽屉组件
///
/// 传入 [quickActionIds] 与 [onQuickActionIdsChanged] 时显示顶部 header，
/// 点右侧编辑图标进入编辑模式：网格变列表，可勾选动作在快捷工具栏
/// （quick_toolbar）常驻显示；再次点击复原网格。
class MessageInputActionsDrawer extends StatefulWidget {
  final List<MessageInputAction> actions;
  final OnFileSelected? onFileSelected;
  final OnSendMessage? onSendMessage;

  /// 当前勾选为快捷栏常驻的动作 id 集合
  final Set<String>? quickActionIds;

  /// 勾选变化回调（由调用方持久化并刷新 quick_toolbar）
  final ValueChanged<Set<String>>? onQuickActionIdsChanged;

  const MessageInputActionsDrawer({
    super.key,
    required this.actions,
    this.onFileSelected,
    this.onSendMessage,
    this.quickActionIds,
    this.onQuickActionIdsChanged,
  });

  @override
  State<MessageInputActionsDrawer> createState() =>
      _MessageInputActionsDrawerState();
}

class _MessageInputActionsDrawerState extends State<MessageInputActionsDrawer> {
  bool _editing = false;

  bool get _editable =>
      widget.quickActionIds != null && widget.onQuickActionIdsChanged != null;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    // 计算网格高度:根据 actions 数量动态计算
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      decoration: BoxDecoration(color: theme.surface),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_editable) _buildHeader(theme),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(context).size.height * 0.6, // 最大高度为屏幕的 60%
            ),
            child: _editing && _editable
                ? _buildEditList(theme)
                : _buildGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _editing ? '编辑快捷图标' : '更多操作',
              style: DsTypography.title.copyWith(color: theme.text),
            ),
          ),
          Pressable(
            onPressed: () => setState(() => _editing = !_editing),
            semanticLabel: _editing ? '完成' : '编辑快捷图标',
            builder: (context, states) => SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: DsIcon(
                  _editing ? DsIconKind.check : DsIconKind.edit,
                  size: 20,
                  color: theme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final actions = widget.actions;
    return GridView.builder(
      shrinkWrap: true,
      physics:
          actions.length > 8
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 24.0,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) => _buildActionItem(context, actions[index]),
    );
  }

  /// 编辑模式列表：勾选动作是否在快捷工具栏常驻显示
  Widget _buildEditList(AppThemeData theme) {
    final actions = widget.actions;
    return ListView.builder(
      shrinkWrap: true,
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        final checked = widget.quickActionIds!.contains(action.id);
        return Pressable(
          onPressed: () => _toggle(action.id, checked),
          semanticLabel: action.title,
          builder: (context, states) => Row(
            children: [
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: theme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Center(
                  child: DsIcon(action.icon, size: 22.0, color: theme.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  action.title,
                  style: DsTypography.body.copyWith(color: theme.text),
                ),
              ),
              DSSwitch(
                value: checked,
                onChanged: (value) => _toggle(action.id, checked),
                semanticLabel: action.title,
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggle(String id, bool currentlyChecked) {
    final ids = {...widget.quickActionIds!};
    currentlyChecked ? ids.remove(id) : ids.add(id);
    widget.onQuickActionIdsChanged!(ids);
  }

  Widget _buildActionItem(BuildContext context, MessageInputAction action) {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: () {
        Navigator.pop(context); // 关闭抽屉
        action.onTap();
      },
      onLongPress:
          action.onLongPress != null
              ? () {
                Navigator.pop(context); // 关闭抽屉
                action.onLongPress!();
              }
              : null,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60.0,
              height: 60.0,
              decoration: BoxDecoration(
                color: pressed ? theme.primary.mixWhite(0.8) : theme.surfaceAlt,
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Center(
                child: DsIcon(action.icon, size: 28.0, color: theme.primary),
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              action.title,
              style: DsTypography.body.copyWith(color: theme.textSub),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}
