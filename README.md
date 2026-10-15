# app_icon_switcher

Switch your app's home-screen icon among icons **bundled in the app**, on iOS
and Android. The icon can come from:

- the user, who picks one in your app, or
- an administrator, through a small JSON file on your backend.

## Limits

- **Bundled icons only.** Neither iOS nor Android lets an app use a downloaded
  image as its icon. The backend only names one of the icons you shipped; a new
  icon needs an app update.
- **iOS shows a system alert** ("You have changed the icon for …") every time
  the icon changes. The package never calls iOS when the icon already matches,
  so the alert only appears for real changes. iOS only allows the change while
  the app is in the foreground, so it happens right away.
- **Android launchers can be slow and rough.** Switching works by enabling one
  `<activity-alias>` and disabling the others. Launchers can take a few seconds
  to update, and some close the app when its launcher entry changes. So once
  `attachLifecycle()` has been called, Android changes are queued and applied
  when the app goes to the background (or right away if it already is).
  Without `attachLifecycle()` they apply immediately.
- Other platforms: `isSupported()` returns false and `apply()` does nothing.

## Which icon wins

1. the remote assignment, if the backend names a known icon;
2. otherwise the user's choice, if any;
3. otherwise the default icon.

The user's choice is kept while an assignment is in force, so it comes back
once the backend clears the assignment.

## Remote config

`GET <remoteUrl>` returns:

```json
{ "icon": "midnight" }
```

- `"icon": null` or a missing key means "no assignment": the user's choice applies.
- An unknown id is treated as no assignment.
- Any status other than 200, a timeout (10 s), or a body that isn't a JSON
  object counts as a failure and keeps the last known assignment, which is
  persisted.
- Checked on `init()` and whenever the app resumes, at most once per
  `checkEvery` (default 6 hours; the last check time is persisted too).
  `refresh(force: true)` skips the wait. A failed check doesn't start the
  wait, so it's retried on the next resume.

## Usage

```dart
import 'dart:async';

import 'package:app_icon_switcher/app_icon_switcher.dart';
import 'package:flutter/widgets.dart';

final iconSwitcher = AppIconSwitcher(
  icons: const [
    AppIcon(id: 'classic', androidAlias: 'IconClassic'), // iosName null = primary icon
    AppIcon(id: 'midnight', androidAlias: 'IconMidnight', iosName: 'AppIcon-Midnight'),
  ],
  defaultIconId: 'classic',
  remoteUrl: Uri.parse('https://example.com/app-icon.json'), // optional
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  iconSwitcher.attachLifecycle(); // refresh on resume; Android applies on pause
  unawaited(iconSwitcher.init()); // load saved state, apply, check the backend
  runApp(const MyApp());
}

// In a picker:
await iconSwitcher.choose('midnight'); // ArgumentError for an unknown id
iconSwitcher.effectiveIconId;          // what the icon is (or is about to be)
iconSwitcher.isAssignedRemotely;       // explain why the user's pick has no effect
iconSwitcher.hasPendingChange;         // Android: "changes when you leave the app"
```

`AppIconSwitcher` is a `ChangeNotifier`, so a `ListenableBuilder` keeps a
picker up to date. State lives in SharedPreferences (keys prefixed
`app_icon_switcher.`). In tests pass `store: MemoryIconStore()`, a fake
`platform`, an `httpClient` (`MockClient` from `package:http/testing.dart`) and
a `clock`.

Native errors surface from `choose()` and `apply()`. During `init()`,
`refresh()` and lifecycle-triggered changes they're reported through
`FlutterError.reportError` instead of thrown.

## Setup

Each `AppIcon` needs a matching entry on both platforms.

### Android

In `android/app/src/main/AndroidManifest.xml`:

1. Remove the `MAIN`/`LAUNCHER` `<intent-filter>` from `MainActivity` (keep the
   activity itself). Otherwise the app shows up twice in the launcher.
2. Add one `<activity-alias>` per icon inside `<application>`, after
   `MainActivity`. Its name ends in the `androidAlias`. Only the default one is
   `enabled="true"`.

```xml
<activity-alias
    android:name=".IconClassic"
    android:targetActivity=".MainActivity"
    android:icon="@mipmap/ic_launcher"
    android:enabled="true"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
</activity-alias>
<activity-alias
    android:name=".IconMidnight"
    android:targetActivity=".MainActivity"
    android:icon="@mipmap/ic_launcher_midnight"
    android:enabled="false"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
</activity-alias>
```

- The remote config needs `<uses-permission android:name="android.permission.INTERNET"/>`
  in the main manifest (debug builds get it automatically, release builds don't).
- Aliases are matched by their simple name (the part after the last dot), so
  this works even when `applicationId` differs from the manifest namespace.
- Add `android:roundIcon` too if you ship round icons. Icons go in
  `res/mipmap-*` (adaptive icons in `mipmap-anydpi-v26`).
- Anything that launches `MainActivity` by component name (shortcuts, some
  notification setups) keeps working, since the activity still exists.

### iOS

1. In `ios/Runner/Assets.xcassets`, add one **App Icon** set per alternate
   icon, named like its `iosName` (e.g. `AppIcon-Midnight`). The primary icon
   stays `AppIcon`; that's the one with `iosName: null`.
2. In the Runner target's build settings (Debug, Release and Profile), list the
   alternate sets, space-separated:

   ```
   ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = AppIcon-Midnight AppIcon-Violet
   ```

   and/or include every app icon set in the catalog:

   ```
   ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS = YES
   ```

   Xcode then writes the `CFBundleAlternateIcons` entries into the built
   Info.plist; no manual plist edits are needed.

## Method channel

Channel `app_icon_switcher`:

| Method | Arguments | Returns |
|---|---|---|
| `isSupported` | none | `bool` (iOS: `supportsAlternateIcons`; Android: `true`) |
| `getCurrentIcon` | none, or `{ "androidAliases": List<String> }` (Android) | `String?`: iOS alternate name (null = primary); Android: enabled alias's simple name |
| `setIcon` | `{ "iosName": String?, "androidAlias": String, "androidAliases": List<String> }` | `bool` |
