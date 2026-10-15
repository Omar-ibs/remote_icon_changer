import 'package:flutter/foundation.dart';

/// One icon bundled in the app.
@immutable
class AppIcon {
  const AppIcon({required this.id, required this.androidAlias, this.iosName});

  /// Stable id used by the app and the backend, e.g. `"midnight"`.
  final String id;

  /// Simple name of the `<activity-alias>` in the Android manifest, e.g.
  /// `"IconMidnight"`.
  final String androidAlias;

  /// Alternate icon name on iOS; `null` means the primary icon.
  final String? iosName;

  @override
  bool operator ==(Object other) =>
      other is AppIcon &&
      other.id == id &&
      other.androidAlias == androidAlias &&
      other.iosName == iosName;

  @override
  int get hashCode => Object.hash(id, androidAlias, iosName);

  @override
  String toString() =>
      'AppIcon($id, androidAlias: $androidAlias, iosName: $iosName)';
}
