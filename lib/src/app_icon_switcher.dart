import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'app_icon.dart';
import 'app_icon_switcher_platform.dart';
import 'icon_store.dart';

/// Keeps the app's home-screen icon in line with, in order of precedence:
///
/// 1. the remote assignment, if the backend names a known icon;
/// 2. otherwise the user's choice, if any;
/// 3. otherwise the default icon.
///
/// Only icons bundled in the app can be used; the backend names one of them.
class AppIconSwitcher extends ChangeNotifier {
  AppIconSwitcher({
    required List<AppIcon> icons,
    required String defaultIconId,
    this._remoteUrl,
    this._checkEvery = const Duration(hours: 6),
    http.Client? httpClient,
    IconStore? store,
    AppIconSwitcherPlatform? platform,
    DateTime Function()? clock,
  }) : _icons = List.unmodifiable(icons),
       _defaultIconId = defaultIconId,
       _httpClient = httpClient,
       _ownsHttpClient = httpClient == null,
       _store = store ?? SharedPreferencesIconStore(),
       _platform = platform ?? AppIconSwitcherPlatform.instance,
       _clock = clock ?? DateTime.now {
    final ids = <String>{};
    for (final icon in icons) {
      if (!ids.add(icon.id)) {
        throw ArgumentError.value(icon.id, 'icons', 'Duplicate icon id');
      }
    }
    if (!ids.contains(defaultIconId)) {
      throw ArgumentError.value(
        defaultIconId,
        'defaultIconId',
        'Not one of the icons',
      );
    }
  }

  /// Store keys (the SharedPreferences store adds its own prefix).
  static const String userChoiceKey = 'user_choice';
  static const String remoteAssignmentKey = 'remote_assignment';
  static const String lastCheckKey = 'last_check';

  /// How long a remote fetch may take before it counts as a failure.
  static const Duration fetchTimeout = Duration(seconds: 10);

  final List<AppIcon> _icons;
  final String _defaultIconId;
  final Uri? _remoteUrl;
  final Duration _checkEvery;
  http.Client? _httpClient;
  final bool _ownsHttpClient;
  final IconStore _store;
  final AppIconSwitcherPlatform _platform;
  final DateTime Function() _clock;

  String? _userChoice;
  String? _remoteAssignment;
  DateTime? _lastCheck;
  bool? _supported;
  bool _pending = false;
  bool _disposed = false;

  AppLifecycleListener? _lifecycleListener;
  AppLifecycleState? _lifecycleState;
  Future<bool>? _refreshing;

  List<AppIcon> get icons => _icons;
  String get defaultIconId => _defaultIconId;

  /// The icon the user picked, persisted. Null if they never picked one.
  String? get userChoice => _userChoice;

  /// The last known valid assignment from the remote config, persisted.
  String? get remoteAssignment => _remoteAssignment;

  bool get isAssignedRemotely => _remoteAssignment != null;

  /// `remoteAssignment ?? userChoice ?? defaultIconId`.
  String get effectiveIconId =>
      _remoteAssignment ?? _userChoice ?? _defaultIconId;

  /// The [AppIcon] for [effectiveIconId].
  AppIcon get effectiveIcon => _iconById(effectiveIconId)!;

  /// True on Android while an icon change waits for the app to go to the
  /// background.
  bool get hasPendingChange => _pending;

  Future<bool> isSupported() async => _supported ??= await _platform
      .isSupported()
      .catchError((Object _) => false);

  AppIcon? _iconById(String? id) {
    if (id == null) return null;
    for (final icon in _icons) {
      if (icon.id == id) return icon;
    }
    return null;
  }

  String? _knownId(String? id) => _iconById(id)?.id;

  /// Loads the persisted state, applies the effective icon, then checks the
  /// remote config if a check is due.
  Future<void> init() async {
    _userChoice = _knownId(await _store.read(userChoiceKey));
    _remoteAssignment = _knownId(await _store.read(remoteAssignmentKey));
    _lastCheck = DateTime.tryParse(await _store.read(lastCheckKey) ?? '');
    _notify();
    await _applyReporting();
    if (_remoteUrl != null) await refresh();
  }

  /// Saves the user's choice and applies it (unless a remote assignment
  /// overrides it). Throws [ArgumentError] for an unknown id.
  Future<void> choose(String id) async {
    if (_iconById(id) == null) {
      throw ArgumentError.value(id, 'id', 'Unknown icon');
    }
    _userChoice = id;
    await _store.write(userChoiceKey, id);
    _notify();
    await apply();
  }

  /// Fetches the remote config, at most once per `checkEvery` unless [force].
  /// Returns true if the assignment changed. Failures keep the last
  /// assignment and return false.
  Future<bool> refresh({bool force = false}) {
    if (_remoteUrl == null) return Future.value(false);
    return _refreshing ??= _refresh(
      force,
    ).whenComplete(() => _refreshing = null);
  }

  Future<bool> _refresh(bool force) async {
    final now = _clock();
    final last = _lastCheck;
    if (!force && last != null && now.difference(last) < _checkEvery) {
      return false;
    }

    final String? assigned;
    try {
      final client = _httpClient ??= http.Client();
      final response = await client
          .get(_remoteUrl!, headers: const {'Accept': 'application/json'})
          .timeout(fetchTimeout);
      if (response.statusCode != 200) return false;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map) return false;
      final icon = body['icon'];
      assigned = icon is String ? _knownId(icon) : null;
    } catch (_) {
      return false;
    }
    if (_disposed) return false;

    _lastCheck = now;
    await _store.write(lastCheckKey, now.toUtc().toIso8601String());
    if (assigned == _remoteAssignment) return false;

    _remoteAssignment = assigned;
    await _store.write(remoteAssignmentKey, assigned);
    _notify();
    await _applyReporting();
    return true;
  }

  /// Makes the native icon match [effectiveIconId]. Does nothing when it
  /// already matches. On Android, while the app is in the foreground and
  /// [attachLifecycle] was called, the change is queued until the app is
  /// paused.
  Future<void> apply() async {
    if (_deferring) {
      _setPending(true);
      return;
    }
    await _applyNow();
  }

  bool get _deferring {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    if (_lifecycleListener == null) return false;
    return !_inBackground(_lifecycleState);
  }

  static bool _inBackground(AppLifecycleState? state) =>
      state == AppLifecycleState.paused ||
      state == AppLifecycleState.hidden ||
      state == AppLifecycleState.detached;

  Future<void> _applyNow() async {
    _setPending(false);
    if (!await isSupported()) return;
    final target = effectiveIcon;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final aliases = [for (final icon in _icons) icon.androidAlias];
    final current = await _platform.getCurrentIcon(
      androidAliases: isAndroid ? aliases : null,
    );
    final wanted = isAndroid ? target.androidAlias : target.iosName;
    if (current == wanted) return;
    await _platform.setIcon(
      iosName: target.iosName,
      androidAlias: target.androidAlias,
      androidAliases: aliases,
    );
  }

  Future<void> _applyReporting() async {
    try {
      await apply();
    } catch (error, stack) {
      _report(error, stack);
    }
  }

  void _report(Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'app_icon_switcher',
        context: ErrorDescription('while switching the app icon'),
        silent: error is PlatformException,
      ),
    );
  }

  /// Refreshes the remote config whenever the app resumes and, on Android,
  /// applies a queued icon change when the app is paused (switching the
  /// launcher alias in the foreground can close the app on some launchers).
  void attachLifecycle() {
    if (_lifecycleListener != null) return;
    _lifecycleState = WidgetsBinding.instance.lifecycleState;
    _lifecycleListener = AppLifecycleListener(onStateChange: _onStateChange);
  }

  void _onStateChange(AppLifecycleState state) {
    _lifecycleState = state;
    switch (state) {
      case AppLifecycleState.resumed:
        refresh().catchError((Object _) => false);
      case AppLifecycleState.paused:
        if (_pending) {
          _applyNow().catchError(_report);
        }
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _setPending(bool value) {
    if (_pending == value) return;
    _pending = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    if (_ownsHttpClient) _httpClient?.close();
    super.dispose();
  }
}
