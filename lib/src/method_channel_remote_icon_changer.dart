import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'remote_icon_changer_platform.dart';

/// [AppIconChangerPlatform] over the `remote_icon_changer` method channel.
class MethodChannelAppIconChanger extends AppIconChangerPlatform {
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('remote_icon_changer');

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
