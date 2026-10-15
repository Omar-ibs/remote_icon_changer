# app_icon_switcher — contract

Shared spec for everyone working on this package and on its first user (the
CubeMate app in `~/personal/rubic_cube`). Change it only by agreement.

## What it does

Switches the app's home-screen icon among icons **bundled in the app**, either
because the user picked one, or because an administrator assigned one from a
backend. Neither iOS nor Android can use a downloaded image as the app icon, so
the backend only ever names one of the bundled icons.

Precedence (the admin wins):

1. the remote assignment, if the backend names a known icon;
2. otherwise the user's choice, if any;
3. otherwise the default icon.

## Remote config

`GET <remoteUrl>` returns JSON:

```json
{ "icon": "midnight" }
```

- `"icon": null` or a missing key means "no assignment": the user's choice applies.
- An unknown id is treated as no assignment (and does not crash).
- Network or parse failures keep the last known assignment (persisted).
- Checked on `init()` and whenever the app resumes, at most once per
  `checkEvery` (default 6 hours) unless `refresh(force: true)`.
- Any HTTP status other than 200 counts as a failure.

## Dart API (`package:app_icon_switcher/app_icon_switcher.dart`)

```dart
class AppIcon {
  const AppIcon({required this.id, required this.androidAlias, this.iosName});
  final String id;            // stable id used by the app and the backend, e.g. "midnight"
  final String androidAlias;  // activity-alias simple name in the manifest, e.g. "IconMidnight"
  final String? iosName;      // alternate icon name on iOS; null = the primary icon
}

class AppIconSwitcher extends ChangeNotifier {
  AppIconSwitcher({
    required List<AppIcon> icons,
    required String defaultIconId,
    Uri? remoteUrl,                       // null = no remote checks
    Duration checkEvery = const Duration(hours: 6),
    http.Client? httpClient,
    IconStore? store,                     // default: SharedPreferencesIconStore
    AppIconSwitcherPlatform? platform,    // default: method channel
    DateTime Function()? clock,
  });

  List<AppIcon> get icons;
  String get defaultIconId;
  String? get userChoice;          // persisted
  String? get remoteAssignment;    // persisted last known valid assignment
  bool get isAssignedRemotely;     // remoteAssignment != null
  String get effectiveIconId;      // remote ?? user ?? default
  Future<bool> isSupported();

  Future<void> init();             // load store, apply, then refresh() if due
  Future<void> choose(String id);  // save the user's choice and apply (throws ArgumentError on unknown id)
  Future<bool> refresh({bool force = false}); // true if the assignment changed
  Future<void> apply();            // make the native icon match effectiveIconId

  /// Listens to app lifecycle: refresh on resume; on Android, performs a
  /// pending icon change when the app goes to the background (switching the
  /// launcher alias in the foreground can close the app on some launchers).
  void attachLifecycle();
  @override
  void dispose();
}

abstract interface class IconStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value); // null deletes
}
class SharedPreferencesIconStore implements IconStore { ... }   // keys prefixed "app_icon_switcher."
class MemoryIconStore implements IconStore { ... }              // for tests
```

`apply()` never calls the platform when the native icon already matches, so
iOS's "You have changed the icon" alert only shows for real changes. On iOS
the change is applied right away (it must happen in the foreground); on
Android it is queued and applied when the app is paused, or right away when
`apply()` is called while already in the background.

## Method channel `app_icon_switcher`

| Method | Arguments | Returns |
|---|---|---|
| `isSupported` | none | `bool` (iOS: `supportsAlternateIcons`; Android: `true`) |
| `getCurrentIcon` | none, or `{ "androidAliases": List<String> }` (Android only; omitted = every alias declared in the app) | `String?`: iOS `alternateIconName` (null = primary); Android: the simple name of the enabled alias, or null if none is found |
| `setIcon` | `{ "iosName": String?, "androidAlias": String, "androidAliases": List<String> }` | `bool` success |

Android `setIcon`: enable the declared alias whose short name (after the last dot) is `<androidAlias>`, then disable every
other alias in `androidAliases`, using `PackageManager.DONT_KILL_APP`.
iOS `setIcon`: `UIApplication.shared.setAlternateIconName(iosName)`.

## Icons in CubeMate

| id | name | iOS `iosName` / asset set | Android alias | Android mipmap |
|---|---|---|---|---|
| `classic` (default) | Classic | null / `AppIcon` | `IconClassic` | `ic_launcher` |
| `midnight` | Midnight | `AppIcon-Midnight` | `IconMidnight` | `ic_launcher_midnight` |
| `violet` | Violet | `AppIcon-Violet` | `IconViolet` | `ic_launcher_violet` |
| `mono` | Mono | `AppIcon-Mono` | `IconMono` | `ic_launcher_mono` |

In-app preview images: `assets/app_icons/<id>.png` (512×512).
