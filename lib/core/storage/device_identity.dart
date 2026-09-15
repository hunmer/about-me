import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentity {
  static const _preferenceKey = 'storage_device_id';
  static String _id = const Uuid().v4();

  static String get id => _id;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_preferenceKey);
    if (stored != null && stored.isNotEmpty) {
      _id = stored;
    } else {
      await prefs.setString(_preferenceKey, _id);
    }
  }
}
