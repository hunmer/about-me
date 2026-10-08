## 1.0.0

Initial release.

## 1.0.0+1

Fixup readme.

## 1.0.1

Use `IList`s for categories. These `IList`s can be used by consumers via dot-shorthands, e.g. `.new([])`.

## 1.0.2

Publicly export EmojiController for use as needed.

## 1.0.3

Add scrollbar to category list, for more intuitive scrolling on desktop.

## 1.1.0

- Minify emoji json for a smaller bundle
- Use a Sliver-based approach for rendering the emoji view, resulting in much better performance
- Add more padding to search bar
- Filter out empty categories, helpful for search

## 1.1.1

Wait for end of frame before highlighting categories, fixing an issue where category highlights could be one scroll outdated.

## 1.1.2

Make search case-insensitive.

## 1.2.0

Add `isFreeText` to `onSelection` callback, useful for recording only recent emojis and not text reactions.
