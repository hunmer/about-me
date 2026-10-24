import 'package:procm_sdk_dart/procm_sdk_dart.dart' as sdk;

typedef ProcmLogger = sdk.Logger;

sdk.Logger setupLoggerFromEnv() => sdk.setupLoggerFromEnv();
sdk.Logger getLogger() => sdk.getLogger();
