import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_remote_icon_changer.dart';

/// The native side of [AppIconChanger]. Replace [instance] (or pass a
/// platform to the changer) to fake it in tests.
abstract class AppIconChangerPlatform extends PlatformInterface {
  AppIconChangerPlatform() : super(token: _token);

  static final Object _token = Object();

  static AppIconChangerPlatform _instance = MethodChannelAppIconChanger();

  static AppIconChangerPlatform get instance => _instance;

  static set instance(AppIconChangerPlatform instance) {
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
