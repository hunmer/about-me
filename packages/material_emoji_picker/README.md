A configurable emoji picker for Flutter. It defaults to Unicode emojis sourced from [gemoji](https://github.com/wooorm/gemoji), but can be extended with custom emojis rendered as arbitrary Flutter widgets.

## Features

- Up-to-date Unicode emojis, sourced from gemoji
- Custom emoji categories that can be prepended or appended to the default categories
- Custom emojis can be rendered as arbitrary Flutter widgets, supporting images, GIFs, stickers, and more
- Recent emojis can be easily implemented using `prependCategories`
- Optional free-text selection
- Designed for high performance using slivers and a custom scroll listener
- Sleek Material 3 design

![A screenshot of the emoji picker, showing a search bar, category selection, and two categories of emojis](https://git.federated.nexus/Henry-Hiles/material_emoji_picker/raw/branch/main/assets/screenshots/main.png)

## Getting started

Add the package to your project with `flutter pub get`.

## Usage

`EmojiPicker` is can be used in a variety of contexts, including bottom sheets, dialogs, or directly in your widget tree.

For example, using it as a bottom sheet:

```dart
showModalBottomSheet(
  isScrollControlled: true,
  context: context,
  builder: (context) => EmojiPicker(
    onSelection: (emoji, isFreeText) {
      Navigator.of(context).pop();
      message.sendReaction(emoji);
    },
  ),
);
```

### Custom emojis

Custom categories can contain `Emoji` objects whose `widget` can be any Flutter widget. This makes it possible to use image-based emojis, GIFs, stickers, or other custom visual representations:

```dart
Emoji(
  widget: Image.network('https://example.com/blob.webp'),
  value: ':blob:',
  aliases: ['blob'],
  description: 'Blob',
  tags: ['custom', 'blob'],
)
```

### Accepted Parameters

- `IList<EmojiCategory> prependCategories`: Categories to prepend to the default emoji list
- `IList<EmojiCategory> appendCategories`: Categories to append to the default emoji list
- `required FutureOr<void> Function(String value) onSelection`: Function to be called when an emoji is selected
- `bool allowFreeText = false`: Whether to allow free text to be returned. Defaults to `false`.
