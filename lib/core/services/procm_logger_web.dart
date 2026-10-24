import 'package:procm_sdk_dart/procm_sdk_dart.dart' as sdk;

/// Web has no process environment, so values are supplied at compile time:
/// `--dart-define=PROCM_WS_URL=...` (and the room/client defines).
const _wsUrl = String.fromEnvironment('PROCM_WS_URL');
const _roomId = String.fromEnvironment(
  'PROCM_ROOM_ID',
  defaultValue: 'aboutme',
);
const _clientName = String.fromEnvironment(
  'PROCM_CLIENT_NAME',
  defaultValue: 'aboutme-app-web',
);

class ProcmLogger {
  ProcmLogger._(this._delegate, this._client) {
    _client?.onState((state) {
      if (state != sdk.ProcmConnectionState.open) return;
      final pending = List<_PendingLog>.of(_pending);
      _pending.clear();
      for (final entry in pending) {
        entry.write(_delegate);
      }
    });
  }

  final sdk.Logger _delegate;
  final sdk.ProcmClient? _client;
  final List<_PendingLog> _pending = [];

  void info(String message, [Object? data]) {
    _write(_PendingLog.info(message, data));
  }

  void error(String message, [Object? data]) {
    _write(_PendingLog.error(message, data));
  }

  void _write(_PendingLog entry) {
    if (_client == null ||
        _client.connectionState == sdk.ProcmConnectionState.open) {
      entry.write(_delegate);
      return;
    }
    if (_pending.length >= 32) _pending.removeAt(0);
    _pending.add(entry);
  }
}

class _PendingLog {
  const _PendingLog._(this.level, this.message, this.data);

  factory _PendingLog.info(String message, Object? data) =>
      _PendingLog._(sdk.LogLevel.info, message, data);

  factory _PendingLog.error(String message, Object? data) =>
      _PendingLog._(sdk.LogLevel.error, message, data);

  final sdk.LogLevel level;
  final String message;
  final Object? data;

  void write(sdk.Logger logger) {
    logger.log(level, message, data);
  }
}

ProcmLogger _newLogger() {
  if (_wsUrl.isEmpty) {
    return ProcmLogger._(
      sdk.Logger(const sdk.LoggerOptions(level: sdk.LoggerThreshold.silent)),
      null,
    );
  }

  final client = sdk.createProcmClient(
    sdk.ProcmClientOptions(
      url: _wsUrl,
      roomId: _roomId,
      clientName: _clientName,
    ),
  );
  return ProcmLogger._(sdk.Logger(sdk.LoggerOptions(client: client)), client);
}

ProcmLogger? _logger;

ProcmLogger setupLoggerFromEnv() => _logger ??= _newLogger();

ProcmLogger getLogger() => _logger ??= _newLogger();
