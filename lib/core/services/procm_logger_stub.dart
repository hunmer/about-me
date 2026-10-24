class ProcmLogger {
  const ProcmLogger();

  void info(String message, [Object? data]) {}

  void error(String message, [Object? data]) {}
}

ProcmLogger setupLoggerFromEnv() => const ProcmLogger();
ProcmLogger getLogger() => const ProcmLogger();
