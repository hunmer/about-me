import 'dart:ui';

class JellyLive2DCropRegion {
  const JellyLive2DCropRegion._(this.rect);

  const JellyLive2DCropRegion.full() : rect = const Rect.fromLTWH(0, 0, 1, 1);

  final Rect rect;

  bool get isFull => rect == const Rect.fromLTWH(0, 0, 1, 1);

  double get zoom => 1 / rect.width;

  Offset sourceTranslation(Size sourceSize) => Offset(
    -rect.left * sourceSize.width * zoom,
    -rect.top * sourceSize.height * zoom,
  );

  Rect toImageRect(Size imageSize) => Rect.fromLTRB(
    rect.left * imageSize.width,
    rect.top * imageSize.height,
    rect.right * imageSize.width,
    rect.bottom * imageSize.height,
  );

  String encode() => '${rect.left},${rect.top},${rect.right},${rect.bottom}';

  static JellyLive2DCropRegion fromImageRect(Rect imageRect, Size imageSize) {
    if (imageSize.isEmpty) return const JellyLive2DCropRegion.full();
    return _validated(
      Rect.fromLTRB(
        imageRect.left / imageSize.width,
        imageRect.top / imageSize.height,
        imageRect.right / imageSize.width,
        imageRect.bottom / imageSize.height,
      ),
    );
  }

  static JellyLive2DCropRegion parse(String? value) {
    if (value == null) return const JellyLive2DCropRegion.full();
    final values = value.split(',').map(double.tryParse).toList();
    if (values.length != 4 || values.any((item) => item == null)) {
      return const JellyLive2DCropRegion.full();
    }
    return _validated(
      Rect.fromLTRB(values[0]!, values[1]!, values[2]!, values[3]!),
    );
  }

  static JellyLive2DCropRegion _validated(Rect value) {
    if (!value.left.isFinite ||
        !value.top.isFinite ||
        !value.right.isFinite ||
        !value.bottom.isFinite ||
        value.left < 0 ||
        value.top < 0 ||
        value.right > 1 ||
        value.bottom > 1 ||
        value.width <= 0.001 ||
        value.height <= 0.001) {
      return const JellyLive2DCropRegion.full();
    }
    return JellyLive2DCropRegion._(value);
  }
}
