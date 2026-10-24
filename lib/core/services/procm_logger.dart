// Keep this path as a compatibility barrel for existing imports. The entry
// point imports the platform files directly so the web build does not create
// a library initialization boundary for this file.
export 'procm_logger_stub.dart' if (dart.library.io) 'procm_logger_io.dart';
