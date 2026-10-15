import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_icon_switcher_platform.dart';

/// [AppIconSwitcherPlatform] over the `app_icon_switcher` method channel.
class MethodChannelAppIconSwitcher extends AppIconSwitcherPlatform {
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('app_icon_switcher');

  @override
  Future<bool> isSupported() async {
    try {
      return await methodChannel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<String?> getCurrentIcon({List<String>? androidAliases}) =>
      methodChannel.invokeMethod<String>(
        'getCurrentIcon',
        androidAliases == null ? null : {'androidAliases': androidAliases},
      );

  @override
  Future<bool> setIcon({
    required String? iosName,
    required String androidAlias,
    required List<String> androidAliases,
  }) async =>
      await methodChannel.invokeMethod<bool>('setIcon', {
        'iosName': iosName,
        'androidAlias': androidAlias,
        'androidAliases': androidAliases,
      }) ??
      false;
}
