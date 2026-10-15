import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_app_icon_switcher.dart';

/// The native side of [AppIconSwitcher]. Replace [instance] (or pass a
/// platform to the switcher) to fake it in tests.
abstract class AppIconSwitcherPlatform extends PlatformInterface {
  AppIconSwitcherPlatform() : super(token: _token);

  static final Object _token = Object();

  static AppIconSwitcherPlatform _instance = MethodChannelAppIconSwitcher();

  static AppIconSwitcherPlatform get instance => _instance;

  static set instance(AppIconSwitcherPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// iOS: `supportsAlternateIcons`; Android: always true.
  Future<bool> isSupported();

  /// iOS: the alternate icon name (null = primary). Android: the simple name
  /// of the enabled alias among [androidAliases] (or among every alias of the
  /// app when omitted), or null when none is found.
  Future<String?> getCurrentIcon({List<String>? androidAliases});

  /// iOS: sets [iosName] as the alternate icon (null = primary). Android:
  /// enables [androidAlias] and disables the other [androidAliases].
  Future<bool> setIcon({
    required String? iosName,
    required String androidAlias,
    required List<String> androidAliases,
  });
}
