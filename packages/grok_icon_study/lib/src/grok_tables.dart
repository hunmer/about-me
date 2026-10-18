// Ported from grok-icon-study replica/src/tables.js — playlists, blink, login wrap, springs.
// Source symbols: g1e VBe w_t cSe rnt int ant ont snt.
import 'dart:math' as math;

const List<({String label, List<String> states})> grokGroups = [
  (label: 'Lifecycle', states: ['sleeping', 'waking', 'idle', 'listening', 'thinking', 'searching', 'working']),
  (label: 'Reactions', states: [
    'excited', 'surprised', 'suspicious', 'angry', 'drowsy', 'happy', 'curious',
    'confused', 'bored', 'proud', 'shy', 'sad', 'laughing', 'scared', 'playful', 'celebrate',
  ]),
  (label: 'Agent morphs', states: ['orbit', 'radar', 'progress']),
  (label: 'Product lifecycle', states: [
    'spawning', 'humming', 'loading', 'dictating', 'writing', 'sending', 'receiving',
    'uploading', 'notifying', 'alerting', 'dragging', 'bouncing', 'powering-down',
  ]),
];

const Map<String, List<int>> eyePlaylist = {
  'sleeping': [13, 22, 4], 'waking': [13], 'idle': [0, 8], 'listening': [10, 1, 19],
  'thinking': [8, 16, 14, 17, 5], 'searching': [15, 9, 3, 20, 12, 18],
  'working': [7, 16, 11, 10], 'excited': [2, 17, 21, 3, 11], 'surprised': [3, 21],
  'suspicious': [14, 5, 23], 'angry': [7, 16], 'drowsy': [4, 22, 13],
  'happy': [2, 11, 17, 19], 'curious': [3, 21, 0, 15], 'confused': [14, 5, 8],
  'bored': [4, 22, 0], 'proud': [15, 8, 2], 'shy': [0, 24, 13], 'sad': [4, 13, 22],
  'laughing': [2, 11, 17], 'scared': [3, 21], 'playful': [2, 17, 11, 8],
  'celebrate': [2, 8, 17], 'orbit': [0, 8], 'radar': [0, 8], 'progress': [0, 8],
  'spawning': [3, 0], 'humming': [0, 8], 'loading': [0, 8], 'dictating': [10, 1, 19],
  'sending': [0, 8], 'receiving': [19, 0, 8], 'uploading': [15, 9, 8], 'writing': [15, 9],
  'notifying': [3, 21, 0], 'alerting': [3, 21], 'bouncing': [2, 17],
  'dragging': [3, 15, 0], 'powering-down': [13, 22],
};

const Map<String, (double, double)> eyeHoldMs = {
  'sleeping': (6000, 10000), 'waking': (800, 800), 'idle': (9000, 16000),
  'listening': (2800, 5000), 'thinking': (2000, 3600), 'searching': (1000, 1800),
  'working': (1800, 3200), 'excited': (1100, 2000), 'surprised': (2500, 4000),
  'suspicious': (2600, 4500), 'angry': (2200, 3800), 'drowsy': (4000, 8000),
  'happy': (2500, 4500), 'curious': (1800, 3200), 'confused': (2200, 3800),
  'bored': (3500, 6000), 'proud': (3500, 6000), 'shy': (3000, 5500),
  'sad': (4000, 7000), 'laughing': (1200, 2400), 'scared': (900, 1800),
  'playful': (1500, 3000), 'celebrate': (1400, 2600), 'orbit': (4000, 8000),
  'radar': (4000, 8000), 'progress': (4000, 8000), 'spawning': (1200, 1200),
  'humming': (5000, 9000), 'loading': (6000, 10000), 'dictating': (4000, 8000),
  'sending': (4000, 8000), 'receiving': (4000, 8000), 'uploading': (4000, 8000),
  'writing': (4000, 8000), 'notifying': (1500, 2600), 'alerting': (2000, 3600),
  'bouncing': (3000, 6000), 'dragging': (1600, 3000), 'powering-down': (6000, 9000),
};

/// null 表示该状态不眨眼。
const Map<String, (double, double)?> blinkMs = {
  'sleeping': null, 'waking': null, 'idle': (6000, 14000), 'listening': (3000, 7000),
  'thinking': (3500, 7000), 'searching': (1600, 4000), 'working': (2800, 5500),
  'excited': (2000, 4000), 'surprised': (1800, 3500), 'suspicious': (4500, 8000),
  'angry': (3500, 7000), 'drowsy': null, 'happy': (2500, 5000), 'curious': (2500, 5500),
  'confused': (2800, 5500), 'bored': (4000, 8000), 'proud': (3500, 7000),
  'shy': (3000, 6000), 'sad': (4000, 8000), 'laughing': (2500, 5000),
  'scared': (1200, 3000), 'playful': (2000, 4500), 'celebrate': (2200, 4500),
  'orbit': null, 'radar': null, 'progress': null, 'spawning': null, 'humming': (4000, 8000),
  'loading': null, 'dictating': null, 'sending': null, 'receiving': null, 'uploading': null,
  'writing': null, 'notifying': (2000, 4000), 'alerting': null, 'bouncing': null,
  'dragging': (2200, 4500), 'powering-down': null,
};

const List<String> onboarding = [
  'curious', 'happy', 'playful', 'excited', 'listening', 'proud', 'laughing', 'shy',
];
const double onboardingMs = 1200;
String onboardMood(int n) =>
    n % 2 == 0 ? 'idle' : onboarding[((n - 1) ~/ 2) % onboarding.length];

/// (freq, damp)
const Map<String, (double, double)> springs = {
  'spin': (5, 0.9),
  'x': (3.5, 1),
  'y': (4, 1),
  'squash': (10, 0.8),
  'blink': (26, 1),
  'eyeScale': (9, 0.85),
  'gazeX': (13, 1),
  'gazeY': (13, 1),
  'notify': (9, 0.55),
  'humDots': (6, 1),
  'overlay': (14, 1),
  'overlayMix': (11, 1),
  'shape': (10, 1),
  'overlayTurn': (14, 1),
  'spinTurn': (6.2, 1),
};

class FaceTune {
  final double size, gap, height, eyeWidth, eyeHeight;
  const FaceTune(this.size, this.gap, this.height, this.eyeWidth, this.eyeHeight);
}

const FaceTune faceTune = FaceTune(0.86, 1.18, 1, 0.96, 0.92);
const double poseTurn = 17, poseTilt = -14, poseRoll = 29;
const double poseHomeTurn = 33, poseHomeTilt = -19, poseHomeRoll = 38;
const bool uniformEyesDefault = true;
const Set<String> vT = {'happy', 'excited', 'proud'};
const Set<String> bT = {'playful'};
const Set<String> winkStates = {'idle', 'happy', 'excited', 'curious', 'playful'};
const Map<String, double> shapeZoom = {
  'blob': 0.92, 'pebble': 0.96, 'squircle': 0.84, 'tablet': 1, 'wedge': 0.94,
  'hex': 0.94, 'cloud': 1, 'teardrop': 1,
};
const double viewScale = 259 / 229;
double shapeZoomOf(String name) => shapeZoom[name] ?? 1;
double poseScaleOf(String name) => shapeZoomOf(name) * viewScale;
double shapeEyeScaleOf(String name) => shapeZoom['blob']! / shapeZoomOf(name);
const double viewHalf = 259 / 2;
const double viewMid = -15 + viewHalf;

const Map<String, double> overlayZoom = {
  'dots': 1.5, 'orbit': 1.14, 'radar': 1.14, 'progress': 1.32, 'gather': 1.15,
  'wave': 1.42, 'send': 1.12, 'receive': 1.12, 'dock': 1.3, 'ball': 1.22,
  'whirl': 1.45, 'pencil': 1.18, 'bang': 1.28, 'standby': 1.75,
};
double overlayViewZoomOf(String? kind, double scale) =>
    kind == null ? 1 : math.max(overlayZoom[kind]! / math.max(scale, 1), 1);

/// 登录墨色渐变（Source G_t / MNe / Y_t），light/dark 两套 from→to。
const Map<String, (int, int, int, int)> ink = {
  'black': (0xFF585858, 0xFF000000, 0xFFFFFFFF, 0xFFC2C2C2),
  'brown': (0xFFAE8968, 0xFF855C36, 0xFFA27952, 0xFF604227),
  'red': (0xFFFF5667, 0xFFE02135, 0xFFFF3E51, 0xFFA21826),
  'orange': (0xFFFF8838, 0xFFE05B00, 0xFFFF781C, 0xFFC24E00),
  'yellow': (0xFFFFAF38, 0xFFE08600, 0xFFFFA31C, 0xFFC27400),
  'green': (0xFF1CCF82, 0xFF009957, 0xFF00C972, 0xFF008048),
  'cyan': (0xFF58D3C5, 0xFF00A592, 0xFF1CC3B0, 0xFF007769),
  'blue': (0xFF459FFE, 0xFF0E74E0, 0xFF2A92FE, 0xFF0C64C1),
  'violet': (0xFFB792FE, 0xFF804EE0, 0xFF9159FE, 0xFF5C39A1),
  'magenta': (0xFFFF77BE, 0xFFE02A88, 0xFFFF47A6, 0xFFA21E62),
  'gray': (0xFFA6A6A6, 0xFF696969, 0xFFB7B7B7, 0xFF777777),
};
const double inkAngle = 135;

