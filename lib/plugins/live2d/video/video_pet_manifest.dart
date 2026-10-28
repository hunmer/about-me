/// Built-in package. Sources are resolved relative to the manifest's URI.
const kDefaultVideoPetManifestAsset =
    'assets/live2d/video/dsh_pet/manifest.json';

const _unset = Object();

class VideoPetManifest {
  const VideoPetManifest({
    required this.id,
    required this.name,
    this.schemaVersion = 1,
    this.canvasWidth = 512,
    this.canvasHeight = 512,
    this.animations = const [],
    this.idleAnimationId = '',
    this.hover = const VideoPetBinding(),
    this.click = const VideoPetBinding(),
    this.movement = const VideoPetMovement(),
    this.regions = const [],
    this.metadata = const {},
  });

  final String id;
  final String name;
  final int schemaVersion;
  final double canvasWidth;
  final double canvasHeight;
  final List<VideoPetAnimation> animations;
  final String idleAnimationId;
  final VideoPetBinding hover;
  final VideoPetBinding click;
  final VideoPetMovement movement;
  final List<VideoPetRegion> regions;
  final Map<String, dynamic> metadata;

  factory VideoPetManifest.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'] ?? 1;
    _require(
      version is int && version == 1,
      'Unsupported schemaVersion: $version',
    );
    final result = VideoPetManifest(
      schemaVersion: version as int,
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      canvasWidth: _number(json, 'canvasWidth', 512),
      canvasHeight: _number(json, 'canvasHeight', 512),
      animations: List.unmodifiable(
        _objects(json, 'animations').map(VideoPetAnimation.fromJson),
      ),
      idleAnimationId: _string(json, 'idleAnimationId'),
      hover: VideoPetBinding.fromJson(_object(json, 'hover')),
      click: VideoPetBinding.fromJson(_object(json, 'click')),
      movement: VideoPetMovement.fromJson(_object(json, 'movement')),
      regions: List.unmodifiable(
        _objects(json, 'regions').map(VideoPetRegion.fromJson),
      ),
      metadata: Map.unmodifiable(_object(json, 'metadata')),
    );
    result.validate();
    return result;
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'name': name,
    'canvasWidth': canvasWidth,
    'canvasHeight': canvasHeight,
    'animations': animations.map((a) => a.toJson()).toList(),
    'idleAnimationId': idleAnimationId,
    'hover': hover.toJson(),
    'click': click.toJson(),
    'movement': movement.toJson(),
    'regions': regions.map((r) => r.toJson()).toList(),
    'metadata': metadata,
  };

  VideoPetManifest copyWith({
    String? id,
    String? name,
    int? schemaVersion,
    double? canvasWidth,
    double? canvasHeight,
    List<VideoPetAnimation>? animations,
    String? idleAnimationId,
    VideoPetBinding? hover,
    VideoPetBinding? click,
    VideoPetMovement? movement,
    List<VideoPetRegion>? regions,
    Map<String, dynamic>? metadata,
  }) => VideoPetManifest(
    id: id ?? this.id,
    name: name ?? this.name,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    canvasWidth: canvasWidth ?? this.canvasWidth,
    canvasHeight: canvasHeight ?? this.canvasHeight,
    animations: List.unmodifiable(animations ?? this.animations),
    idleAnimationId: idleAnimationId ?? this.idleAnimationId,
    hover: hover ?? this.hover,
    click: click ?? this.click,
    movement: movement ?? this.movement,
    regions: List.unmodifiable(regions ?? this.regions),
    metadata: Map.unmodifiable(metadata ?? this.metadata),
  );

  VideoPetAnimation? animation(String id) {
    for (final animation in animations) {
      if (animation.id == id) return animation;
    }
    return null;
  }

  /// Equal priorities preserve manifest order. Coordinates are normalized.
  VideoPetRegion? hitTest(double x, double y) {
    if (!x.isFinite || !y.isFinite || x < 0 || x > 1 || y < 0 || y > 1) {
      return null;
    }
    VideoPetRegion? result;
    for (final region in regions) {
      if (region.enabled &&
          region.contains(x, y) &&
          (result == null || region.priority > result.priority)) {
        result = region;
      }
    }
    return result;
  }

  void validate() {
    _require(schemaVersion == 1, 'Unsupported schemaVersion: $schemaVersion');
    _require(id.trim().isNotEmpty, 'Manifest id must not be empty');
    _require(name.trim().isNotEmpty, 'Manifest name must not be empty');
    _require(canvasWidth.isFinite && canvasWidth > 0, 'Invalid canvasWidth');
    _require(canvasHeight.isFinite && canvasHeight > 0, 'Invalid canvasHeight');
    _require(animations.isNotEmpty, 'Manifest must contain animations');
    final ids = <String>{};
    for (final animation in animations) {
      animation.validate();
      _require(ids.add(animation.id), 'Duplicate animation: ${animation.id}');
    }
    _require(
      ids.contains(idleAnimationId),
      'Unknown idle animation: $idleAnimationId',
    );
    hover.validate(ids);
    click.validate(ids);
    movement.validate(ids);
    final regionIds = <String>{};
    for (final region in regions) {
      region.validate(ids);
      _require(regionIds.add(region.id), 'Duplicate region: ${region.id}');
    }
  }
}

class VideoPetMovement {
  const VideoPetMovement({
    this.leftAnimationId = '',
    this.rightAnimationId = '',
    this.turnLeftAnimationId = '',
    this.turnRightAnimationId = '',
    this.speed = 40,
    this.minIdleSeconds = 5,
    this.maxIdleSeconds = 15,
  });

  final String leftAnimationId;
  final String rightAnimationId;
  final String turnLeftAnimationId;
  final String turnRightAnimationId;

  /// Logical pixels per second.
  final double speed;
  final double minIdleSeconds;
  final double maxIdleSeconds;

  /// Call after manifest validation; both walking directions are required.
  bool get enabled => leftAnimationId.isNotEmpty && rightAnimationId.isNotEmpty;

  factory VideoPetMovement.fromJson(Map<String, dynamic> json) {
    final result = VideoPetMovement(
      leftAnimationId: _string(json, 'leftAnimationId'),
      rightAnimationId: _string(json, 'rightAnimationId'),
      turnLeftAnimationId: _string(json, 'turnLeftAnimationId'),
      turnRightAnimationId: _string(json, 'turnRightAnimationId'),
      speed: _number(json, 'speed', 40),
      minIdleSeconds: _number(json, 'minIdleSeconds', 5),
      maxIdleSeconds: _number(json, 'maxIdleSeconds', 15),
    );
    result.validate();
    return result;
  }

  Map<String, dynamic> toJson() => {
    'leftAnimationId': leftAnimationId,
    'rightAnimationId': rightAnimationId,
    'turnLeftAnimationId': turnLeftAnimationId,
    'turnRightAnimationId': turnRightAnimationId,
    'speed': speed,
    'minIdleSeconds': minIdleSeconds,
    'maxIdleSeconds': maxIdleSeconds,
  };

  VideoPetMovement copyWith({
    String? leftAnimationId,
    String? rightAnimationId,
    String? turnLeftAnimationId,
    String? turnRightAnimationId,
    double? speed,
    double? minIdleSeconds,
    double? maxIdleSeconds,
  }) => VideoPetMovement(
    leftAnimationId: leftAnimationId ?? this.leftAnimationId,
    rightAnimationId: rightAnimationId ?? this.rightAnimationId,
    turnLeftAnimationId: turnLeftAnimationId ?? this.turnLeftAnimationId,
    turnRightAnimationId: turnRightAnimationId ?? this.turnRightAnimationId,
    speed: speed ?? this.speed,
    minIdleSeconds: minIdleSeconds ?? this.minIdleSeconds,
    maxIdleSeconds: maxIdleSeconds ?? this.maxIdleSeconds,
  );

  void validate([Set<String>? knownIds]) {
    for (final id in [
      leftAnimationId,
      rightAnimationId,
      turnLeftAnimationId,
      turnRightAnimationId,
    ]) {
      _require(
        id.isEmpty ||
            (id.trim().isNotEmpty &&
                (knownIds == null || knownIds.contains(id))),
        'Unknown movement animation: $id',
      );
    }
    _require(speed.isFinite && speed > 0, 'movement.speed must be positive');
    _require(
      minIdleSeconds.isFinite &&
          minIdleSeconds >= 0 &&
          maxIdleSeconds.isFinite &&
          maxIdleSeconds >= minIdleSeconds,
      'Invalid movement idle time range',
    );
  }
}

class VideoPetAnimation {
  const VideoPetAnimation({
    required this.id,
    required this.name,
    this.category = '',
    this.sources = const {},
    this.spritesheet,
  });

  final String id;
  final String name;
  final String category;
  final Map<String, String> sources;
  final VideoPetSpritesheet? spritesheet;

  /// Validated spritesheets have exactly one image source.
  String? get imageFormat => sources.containsKey('webp')
      ? 'webp'
      : sources.containsKey('png')
      ? 'png'
      : null;

  String? get imageSource => sources[imageFormat];

  factory VideoPetAnimation.fromJson(Map<String, dynamic> json) {
    final sources = _object(json, 'sources');
    _require(
      sources.values.every((v) => v is String),
      'sources must contain strings',
    );
    final spritesheetJson = json['spritesheet'];
    _require(
      spritesheetJson == null || spritesheetJson is Map,
      'spritesheet must be an object',
    );
    return VideoPetAnimation(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      category: _string(json, 'category'),
      sources: Map.unmodifiable(sources.cast<String, String>()),
      spritesheet: spritesheetJson == null
          ? null
          : VideoPetSpritesheet.fromJson(
              Map<String, dynamic>.from(spritesheetJson as Map),
            ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'sources': Map<String, String>.of(sources),
    if (spritesheet != null) 'spritesheet': spritesheet!.toJson(),
  };

  VideoPetAnimation copyWith({
    String? id,
    String? name,
    String? category,
    Map<String, String>? sources,
    Object? spritesheet = _unset,
  }) => VideoPetAnimation(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    sources: Map.unmodifiable(sources ?? this.sources),
    spritesheet: identical(spritesheet, _unset)
        ? this.spritesheet
        : spritesheet as VideoPetSpritesheet?,
  );

  Uri? resolveSource(String format, Uri baseUri) {
    final source = sources[format];
    return source == null ? null : baseUri.resolve(source);
  }

  void validate() {
    _require(id.trim().isNotEmpty, 'Animation id must not be empty');
    _require(name.trim().isNotEmpty, 'Animation name must not be empty');
    _require(sources.isNotEmpty, 'Animation $id has no sources');
    final hasImage = imageSource != null;
    if (spritesheet != null || hasImage) {
      _require(
        spritesheet != null && sources.length == 1 && hasImage,
        'Spritesheet animation $id must contain only a png or webp source and spritesheet metadata',
      );
      spritesheet!.validate();
    }
    for (final entry in sources.entries) {
      _require(
        entry.key == 'png' ||
            entry.key == 'webp' ||
            entry.key == 'webm' ||
            entry.key == 'mov',
        'Unsupported source: ${entry.key}',
      );
      final uri = Uri.tryParse(entry.value);
      _require(
        entry.value.trim().isNotEmpty &&
            !RegExp(r'[\x00-\x1f\\]').hasMatch(entry.value) &&
            uri != null &&
            (!uri.hasScheme ||
                const ['http', 'https', 'file', 'data'].contains(uri.scheme)),
        'Invalid source for $id/${entry.key}',
      );
      if (entry.key == imageFormat && uri != null) {
        _require(
          uri.scheme == 'data'
              ? uri.data?.mimeType == 'image/${entry.key}'
              : uri.path.toLowerCase().endsWith('.${entry.key}'),
          '${entry.key.toUpperCase()} source for $id must use image/${entry.key} data or end with .${entry.key}',
        );
      }
    }
  }
}

class VideoPetSpritesheet {
  const VideoPetSpritesheet({
    required this.frameWidth,
    required this.frameHeight,
    required this.columns,
    required this.rows,
    required this.frameCount,
    required this.fps,
  });

  final int frameWidth;
  final int frameHeight;
  final int columns;
  final int rows;
  final int frameCount;
  final double fps;

  factory VideoPetSpritesheet.fromJson(Map<String, dynamic> json) {
    return VideoPetSpritesheet(
      frameWidth: _integer(json, 'frameWidth'),
      frameHeight: _integer(json, 'frameHeight'),
      columns: _integer(json, 'columns'),
      rows: _integer(json, 'rows'),
      frameCount: _integer(json, 'frameCount'),
      fps: _number(json, 'fps', 0),
    );
  }

  Map<String, dynamic> toJson() => {
    'frameWidth': frameWidth,
    'frameHeight': frameHeight,
    'columns': columns,
    'rows': rows,
    'frameCount': frameCount,
    'fps': fps,
  };

  @override
  bool operator ==(Object other) =>
      other is VideoPetSpritesheet &&
      frameWidth == other.frameWidth &&
      frameHeight == other.frameHeight &&
      columns == other.columns &&
      rows == other.rows &&
      frameCount == other.frameCount &&
      fps == other.fps;

  @override
  int get hashCode =>
      Object.hash(frameWidth, frameHeight, columns, rows, frameCount, fps);

  void validate() {
    _require(frameWidth > 0, 'spritesheet.frameWidth must be positive');
    _require(frameHeight > 0, 'spritesheet.frameHeight must be positive');
    _require(columns > 0, 'spritesheet.columns must be positive');
    _require(rows > 0, 'spritesheet.rows must be positive');
    _require(frameCount > 0, 'spritesheet.frameCount must be positive');
    _require(
      frameCount <= columns * rows,
      'spritesheet.frameCount exceeds grid capacity',
    );
    _require(fps.isFinite && fps > 0, 'spritesheet.fps must be positive');
  }
}

class VideoPetBinding {
  const VideoPetBinding({
    this.animationIds = const [],
    this.strategy = 'random',
  });

  final List<String> animationIds;
  final String strategy;

  factory VideoPetBinding.fromJson(Map<String, dynamic> json) {
    final ids = json['animationIds'] ?? const <String>[];
    _require(
      ids is List && ids.every((v) => v is String),
      'animationIds must be strings',
    );
    return VideoPetBinding(
      animationIds: List.unmodifiable((ids as List).cast<String>()),
      strategy: _string(json, 'strategy', 'random'),
    );
  }

  Map<String, dynamic> toJson() => {
    'animationIds': List<String>.of(animationIds),
    'strategy': strategy,
  };

  VideoPetBinding copyWith({List<String>? animationIds, String? strategy}) =>
      VideoPetBinding(
        animationIds: List.unmodifiable(animationIds ?? this.animationIds),
        strategy: strategy ?? this.strategy,
      );

  void validate([Set<String>? knownIds]) {
    _require(
      strategy == 'random' || strategy == 'sequence',
      'Invalid binding strategy: $strategy',
    );
    for (final id in animationIds) {
      _require(
        id.trim().isNotEmpty && (knownIds == null || knownIds.contains(id)),
        'Unknown binding animation: $id',
      );
    }
  }
}

class VideoPetRegion {
  const VideoPetRegion({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.enabled = true,
    this.priority = 0,
    this.hover,
    this.click,
  });

  final String id;
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
  final bool enabled;
  final int priority;

  /// Null inherits the manifest binding; an empty binding disables this action.
  final VideoPetBinding? hover;
  final VideoPetBinding? click;

  factory VideoPetRegion.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'] ?? true;
    final priority = json['priority'] ?? 0;
    _require(enabled is bool, 'enabled must be a bool');
    _require(priority is int, 'priority must be an integer');
    return VideoPetRegion(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      x: _number(json, 'x', 0),
      y: _number(json, 'y', 0),
      width: _number(json, 'width', 0),
      height: _number(json, 'height', 0),
      enabled: enabled as bool,
      priority: priority as int,
      hover: json['hover'] == null
          ? null
          : VideoPetBinding.fromJson(_object(json, 'hover')),
      click: json['click'] == null
          ? null
          : VideoPetBinding.fromJson(_object(json, 'click')),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'enabled': enabled,
    'priority': priority,
    'hover': hover?.toJson(),
    'click': click?.toJson(),
  };

  VideoPetRegion copyWith({
    String? id,
    String? name,
    double? x,
    double? y,
    double? width,
    double? height,
    bool? enabled,
    int? priority,
    Object? hover = _unset,
    Object? click = _unset,
  }) => VideoPetRegion(
    id: id ?? this.id,
    name: name ?? this.name,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    enabled: enabled ?? this.enabled,
    priority: priority ?? this.priority,
    hover: identical(hover, _unset) ? this.hover : hover as VideoPetBinding?,
    click: identical(click, _unset) ? this.click : click as VideoPetBinding?,
  );

  bool contains(double px, double py) =>
      px >= x && px <= x + width && py >= y && py <= y + height;

  void validate([Set<String>? knownIds]) {
    _require(id.trim().isNotEmpty, 'Region id must not be empty');
    _require(name.trim().isNotEmpty, 'Region name must not be empty');
    _require(
      x.isFinite &&
          y.isFinite &&
          width.isFinite &&
          height.isFinite &&
          x >= 0 &&
          y >= 0 &&
          width > 0 &&
          height > 0 &&
          x + width <= 1 &&
          y + height <= 1,
      'Invalid normalized region: $id',
    );
    hover?.validate(knownIds);
    click?.validate(knownIds);
  }
}

void _require(bool condition, String message) {
  if (!condition) throw FormatException(message);
}

String _string(Map<String, dynamic> json, String key, [String fallback = '']) {
  final value = json[key] ?? fallback;
  _require(value is String, '$key must be a string');
  return value as String;
}

double _number(Map<String, dynamic> json, String key, double fallback) {
  final value = json[key] ?? fallback;
  _require(value is num, '$key must be a number');
  return (value as num).toDouble();
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  _require(value is int, '$key must be an integer');
  return value as int;
}

Map<String, dynamic> _object(Map<String, dynamic> json, String key) {
  final value = json[key] ?? const <String, dynamic>{};
  _require(
    value is Map && value.keys.every((k) => k is String),
    '$key must be an object',
  );
  return Map<String, dynamic>.from(value as Map);
}

List<Map<String, dynamic>> _objects(Map<String, dynamic> json, String key) {
  final value = json[key] ?? const [];
  _require(value is List, '$key must be an array');
  return (value as List).map((entry) {
    _require(
      entry is Map && entry.keys.every((k) => k is String),
      '$key entries must be objects',
    );
    return Map<String, dynamic>.from(entry as Map);
  }).toList();
}
