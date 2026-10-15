import 'package:shared_preferences/shared_preferences.dart';

/// Where [AppIconSwitcher] keeps the user's choice and the last known remote
/// assignment.
abstract interface class IconStore {
  Future<String?> read(String key);

  /// Writes [value] under [key]; `null` deletes the key.
  Future<void> write(String key, String? value);
}

/// Stores values in SharedPreferences, with keys prefixed `app_icon_switcher.`.
class SharedPreferencesIconStore implements IconStore {
  SharedPreferencesIconStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String prefix = 'app_icon_switcher.';

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString('$prefix$key');

  @override
  Future<void> write(String key, String? value) => value == null
      ? _preferences.remove('$prefix$key')
      : _preferences.setString('$prefix$key', value);
}

/// Keeps values in memory. Handy for tests; share one instance between two
/// switchers to simulate an app restart.
class MemoryIconStore implements IconStore {
  MemoryIconStore([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}
