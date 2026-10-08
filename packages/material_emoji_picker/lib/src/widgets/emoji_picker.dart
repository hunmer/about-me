import "dart:async";

import "package:flutter/material.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:material_emoji_picker/src/controllers/emoji.dart";
import "package:material_emoji_picker/src/models/emoji_category.dart";

class EmojiPicker extends HookConsumerWidget {
  const EmojiPicker({
    this.prependCategories = const IList.empty(),
    this.appendCategories = const IList.empty(),
    required this.onSelection,
    this.allowFreeText = false,
    super.key,
  });

  final IList<EmojiCategory> prependCategories;
  final IList<EmojiCategory> appendCategories;
  final FutureOr<void> Function(String value, bool isFreeText) onSelection;
  final bool allowFreeText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = useState<int>(0);
    final search = useState("");

    final scrollController = useScrollController();
    final scrollViewKey = useMemoized(() => GlobalKey());

    final categoryScrollController = useScrollController();

    return Container(
      padding: .all(16),
      constraints: .loose(.new(500, 700)),
      child: switch (ref.watch(EmojiController.provider)) {
        AsyncError(:final error) => throw error,
        AsyncLoading _ => Center(child: CircularProgressIndicator()),
        AsyncData(value: final categories) => HookBuilder(
          builder: (context) {
            final combined = useMemoized(
              () =>
                  prependCategories.addAll(categories).addAll(appendCategories),
            );

            final headerKeys = useMemoized(
              () =>
                  List.generate(combined.length, (_) => GlobalKey()).toIList(),
              [combined],
            );

            final chipKeys = useMemoized(
              () =>
                  List.generate(combined.length, (_) => GlobalKey()).toIList(),
              [combined],
            );

            useEffect(() {
              Future<void> syncSelectedCategoryWithScroll() async {
                await WidgetsBinding.instance.endOfFrame;

                final viewport = scrollViewKey.currentContext
                    ?.findRenderObject();
                if (viewport is! RenderBox) return;

                final selectedIndex = headerKeys.lastIndexWhere((headerKey) {
                  final renderObject = headerKey.currentContext
                      ?.findRenderObject();

                  if (renderObject is! RenderBox) return false;

                  final top = renderObject
                      .localToGlobal(Offset.zero, ancestor: viewport)
                      .dy;

                  return top <= 20;
                });

                if (selectedIndex != selectedCategory.value) {
                  selectedCategory.value = selectedIndex;
                  final chipContext = chipKeys[selectedIndex].currentContext;

                  if (chipContext != null && chipContext.mounted) {
                    await Scrollable.ensureVisible(
                      chipContext,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: 0,
                    );
                  }
                }
              }

              scrollController.addListener(syncSelectedCategoryWithScroll);
              return () => scrollController.removeListener(
                syncSelectedCategoryWithScroll,
              );
            }, [scrollController, headerKeys]);

            return Column(
              children: [
                SearchBar(
                  hintText: "Search emoji",
                  padding: const WidgetStatePropertyAll<EdgeInsets>(
                    .symmetric(horizontal: 16.0),
                  ),
                  leading: Icon(Icons.search),
                  onChanged: (value) => search.value = value,
                  trailing: [
                    if (allowFreeText)
                      IconButton(
                        onPressed: search.value.isEmpty
                            ? null
                            : () => onSelection(search.value, true),
                        icon: Icon(Icons.send),
                      ),
                  ],
                ),
                SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: Scrollbar(
                    controller: categoryScrollController,
                    child: ListView(
                      padding: .only(bottom: 12),
                      scrollDirection: .horizontal,
                      controller: categoryScrollController,
                      children: combined
                          .mapIndexed(
                            (index, category) => Padding(
                              key: chipKeys[index],
                              padding: .symmetric(horizontal: 4),
                              child: FilterChip(
                                label: Text(category.name),
                                avatar: category.icon,
                                selected: selectedCategory.value == index,
                                showCheckmark: false,
                                onSelected: (_) {
                                  selectedCategory.value = index;
                                  final headerContext =
                                      headerKeys[index].currentContext;
                                  if (headerContext != null) {
                                    Scrollable.ensureVisible(
                                      headerContext,
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                      alignment: 0,
                                    );
                                  }
                                },
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    key: scrollViewKey,
                    controller: scrollController,
                    slivers: combined
                        .mapIndexed(
                          (index, category) => Builder(
                            builder: (context) {
                              final headerKey = headerKeys[index];
                              final searchTerm = search.value.toLowerCase();
                              final emojis = searchTerm.isEmpty
                                  ? category.emojis
                                  : category.emojis
                                        .where(
                                          (emoji) =>
                                              emoji.aliases.join().contains(
                                                searchTerm,
                                              ) ||
                                              emoji.description.contains(
                                                searchTerm,
                                              ) ||
                                              emoji.tags.join().contains(
                                                searchTerm,
                                              ),
                                        )
                                        .toIList();

                              if (emojis.isEmpty) {
                                return SliverToBoxAdapter(
                                  child: SizedBox.shrink(key: headerKey),
                                );
                              }

                              return SliverMainAxisGroup(
                                slivers: [
                                  SliverToBoxAdapter(
                                    child: Text(
                                      key: headerKey,
                                      category.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  SliverGrid.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 56,
                                          mainAxisExtent: 56,
                                        ),
                                    itemCount: emojis.length,
                                    itemBuilder: (context, index) {
                                      final emoji = emojis[index];

                                      return IconButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () =>
                                            onSelection(emoji.value, false),
                                        icon: SizedBox.square(
                                          dimension: 36,
                                          child: FittedBox(child: emoji.widget),
                                        ),
                                      );
                                    },
                                  ),
                                  SliverToBoxAdapter(
                                    child: SizedBox(height: 4),
                                  ),
                                ],
                              );
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            );
          },
        ),
      },
    );
  }
}
