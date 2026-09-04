import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/controllers/notes_controller.dart';
import 'package:aboutme/plugins/notes/models/note.dart';
import 'package:aboutme/plugins/notes/widgets/search_note_item.dart';

class SearchScreen extends StatefulWidget {
  final NotesController controller;

  const SearchScreen({super.key, required this.controller});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Note> _searchResults = [];
  List<String> _selectedTags = [];
  DateTime? _startDate;
  DateTime? _endDate;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _query = '';
      });
      return;
    }

    setState(() {
      _query = query;
      _searchResults = widget.controller.searchNotes(
        query: query,
        tags: _selectedTags.isEmpty ? null : _selectedTags,
        startDate: _startDate,
        endDate: _endDate,
      );
    });
  }

  void _showFilterDialog() {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return JellyBox(
                  radius: theme.radii.xxl,
                  padding: EdgeInsets.all(theme.spacing.xl),
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'notes_filter'.tr,
                          textAlign: TextAlign.center,
                          style: DsTypography.title.copyWith(color: theme.text),
                        ),
                        SizedBox(height: theme.spacing.lg),
                        Text(
                          'notes_tags'.tr,
                          style: DsTypography.heading.copyWith(
                            color: theme.text,
                          ),
                        ),
                        SizedBox(height: theme.spacing.sm),
                        Wrap(
                          spacing: 8,
                          children: [
                            // This is a simplified version. In a real app, you'd fetch all available tags.
                            _buildTagChip('Work'),
                            _buildTagChip('Personal'),
                            _buildTagChip('Ideas'),
                            _buildTagChip('Important'),
                          ],
                        ),
                        SizedBox(height: theme.spacing.lg),
                        Text(
                          'notes_dateRange'.tr,
                          style: DsTypography.heading.copyWith(
                            color: theme.text,
                          ),
                        ),
                        SizedBox(height: theme.spacing.sm),
                        _buildDateRow(
                          theme,
                          label:
                              _startDate != null
                                  ? 'From: ${_formatDate(_startDate!)}'
                                  : 'notes_typeToSearch'.tr,
                          onTap: () async {
                            final date = await showDSDatePickerDialog(
                              context: context,
                              initial: _startDate ?? DateTime.now(),
                              theme: theme,
                            );
                            if (date != null) {
                              setState(() {
                                _startDate = date;
                              });
                              _onSearchChanged();
                            }
                          },
                        ),
                        _buildDateRow(
                          theme,
                          label:
                              _endDate != null
                                  ? 'To: ${_formatDate(_endDate!)}'
                                  : 'notes_typeToSearch'.tr,
                          onTap: () async {
                            final date = await showDSDatePickerDialog(
                              context: context,
                              initial: _endDate ?? DateTime.now(),
                              theme: theme,
                            );
                            if (date != null) {
                              setState(() {
                                _endDate = date;
                              });
                              _onSearchChanged();
                            }
                          },
                        ),
                        SizedBox(height: theme.spacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: DSButton(
                                label: 'notes_clearAll'.tr,
                                variant: DSButtonVariant.outline,
                                onPressed: () {
                                  setState(() {
                                    _selectedTags = [];
                                    _startDate = null;
                                    _endDate = null;
                                  });
                                  _onSearchChanged();
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                            SizedBox(width: theme.spacing.md),
                            Expanded(
                              child: DSButton(
                                label: 'notes_apply'.tr,
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
    );
  }

  Widget _buildDateRow(
    AppThemeData theme, {
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Pressable(
        onPressed: onTap,
        builder:
            (context, states) => Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                ),
                DsIcon(DsIconKind.calendar, size: 20, color: theme.primary),
              ],
            ),
      ),
    );
  }

  Widget _buildTagChip(String tag) {
    final isSelected = _selectedTags.contains(tag);
    return DSChip(
      label: tag,
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedTags.add(tag);
          } else {
            _selectedTags.remove(tag);
          }
        });
        _onSearchChanged();
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Scaffold(
      appBar: AppBar(
        leading: DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.chevronLeft,
                size: 38,
                color: theme.surface,
                iconColor: theme.text,
                onPressed: () => Navigator.pop(context),
              );
            },
          ),
        ),
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'notes_searchHint'.tr,
            border: InputBorder.none,
          ),
          autofocus: true,
        ),
        actions: [
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.sort,
                  size: 38,
                  color: theme.surface,
                  iconColor: theme.text,
                  onPressed: _showFilterDialog,
                );
              },
            ),
          ),
        ],
      ),
      body:
          _searchResults.isEmpty
              ? Center(
                child:
                    _query.isEmpty
                        ? Text(
                          'notes_typeToSearch'.tr,
                          style: DsTypography.body.copyWith(
                            color: theme.textSub,
                          ),
                        )
                        : Text(
                          'notes_noResultsFound'.tr,
                          style: DsTypography.body.copyWith(
                            color: theme.textSub,
                          ),
                        ),
              )
              : ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final note = _searchResults[index];
                  final folder =
                      note.folderId != null
                          ? widget.controller.getFolder(note.folderId!)
                          : null;
                  return SearchNoteItem(
                    note: note,
                    folderName: folder?.name ?? 'notes_noResultsFound'.tr,
                    query: _query,
                  );
                },
              ),
    );
  }
}
