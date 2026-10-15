import 'dart:convert';

import 'package:remote_icon_changer/remote_icon_changer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const icons = [
  AppIcon(id: 'classic', androidAlias: 'IconClassic'),
  AppIcon(
    id: 'midnight',
    androidAlias: 'IconMidnight',
    iosName: 'AppIcon-Midnight',
  ),
  AppIcon(id: 'violet', androidAlias: 'IconViolet', iosName: 'AppIcon-Violet'),
];
const aliases = ['IconClassic', 'IconMidnight', 'IconViolet'];

class FakePlatform extends AppIconChangerPlatform
    with MockPlatformInterfaceMixin {
  FakePlatform({this.current, this.supported = true});

  /// What the native side reports: an alias on Android, an iOS name on iOS.
  String? current;
  bool supported;
  final List<String> calls = [];
  final List<Map<String, Object?>> setIconArgs = [];

  @override
  Future<bool> isSupported() async {
    calls.add('isSupported');
    return supported;
  }

  @override
  Future<String?> getCurrentIcon({List<String>? androidAliases}) async {
    calls.add('getCurrentIcon');
    return current;
  }

  @override
  Future<bool> setIcon({
    required String? iosName,
    required String androidAlias,
    required List<String> androidAliases,
  }) async {
    calls.add('setIcon');
    setIconArgs.add({
      'iosName': iosName,
      'androidAlias': androidAlias,
      'androidAliases': androidAliases,
    });
    current = defaultTargetPlatform == TargetPlatform.android
        ? androidAlias
        : iosName;
    return true;
  }
}

/// A remote config server whose answer the test can change.
class FakeServer {
  Object? body = <String, Object?>{};
  int status = 200;
  bool fail = false;
  int requests = 0;

  late final MockClient client = MockClient((request) async {
    requests++;
    if (fail) throw http.ClientException('offline', request.url);
    return http.Response(
      body is String ? body! as String : jsonEncode(body),
      status,
    );
  });
}

final remoteUrl = Uri.parse('https://example.com/icon.json');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePlatform platform;
  late MemoryIconStore store;
  late FakeServer server;
  late DateTime now;

  AppIconChanger make({Uri? url}) => AppIconChanger(
    icons: icons,
    defaultIconId: 'classic',
    remoteUrl: url ?? remoteUrl,
    httpClient: server.client,
    store: store,
    platform: platform,
    clock: () => now,
  );

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    platform = FakePlatform();
    store = MemoryIconStore();
    server = FakeServer();
    now = DateTime.utc(2026, 1, 1, 12);
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('precedence', () {
    test('default when nothing is chosen or assigned', () async {
      final s = make();
      await s.init();
      expect(s.effectiveIconId, 'classic');
      expect(s.isAssignedRemotely, isFalse);
      expect(platform.calls, isNot(contains('setIcon')));
    });

    test('user choice beats the default', () async {
      final s = make();
      await s.init();
      await s.choose('violet');
      expect(s.userChoice, 'violet');
      expect(s.effectiveIconId, 'violet');
      expect(platform.current, 'AppIcon-Violet');
    });

    test('remote assignment beats the user choice', () async {
      server.body = {'icon': 'midnight'};
      final s = make();
      await s.init();
      await s.choose('violet');
      expect(s.userChoice, 'violet');
      expect(s.remoteAssignment, 'midnight');
      expect(s.isAssignedRemotely, isTrue);
      expect(s.effectiveIconId, 'midnight');
      expect(platform.current, 'AppIcon-Midnight');
    });
  });

  test('unknown remote id is ignored', () async {
    server.body = {'icon': 'rainbow'};
    final s = make();
    await s.init();
    expect(s.remoteAssignment, isNull);
    expect(s.effectiveIconId, 'classic');
  });

  test('missing key and non-object bodies mean no assignment', () async {
    server.body = {'icon': 'midnight'};
    final s = make();
    await s.init();
    server.body = <String, Object?>{};
    expect(await s.refresh(force: true), isTrue);
    expect(s.remoteAssignment, isNull);
  });

  test('null assignment clears it and the user choice applies again', () async {
    server.body = {'icon': 'midnight'};
    final s = make();
    await s.init();
    await s.choose('violet');
    expect(platform.current, 'AppIcon-Midnight');

    server.body = {'icon': null};
    expect(await s.refresh(force: true), isTrue);
    expect(s.remoteAssignment, isNull);
    expect(s.effectiveIconId, 'violet');
    expect(platform.current, 'AppIcon-Violet');
    expect(
      store.values.containsKey(AppIconChanger.remoteAssignmentKey),
      isFalse,
    );
  });

  group('failures keep the last assignment', () {
    late AppIconChanger s;
    setUp(() async {
      server.body = {'icon': 'midnight'};
      s = make();
      await s.init();
    });

    test('network error', () async {
      server.fail = true;
      expect(await s.refresh(force: true), isFalse);
      expect(s.remoteAssignment, 'midnight');
    });

    test('non-200 status', () async {
      server
        ..status = 500
        ..body = {'icon': null};
      expect(await s.refresh(force: true), isFalse);
      expect(s.remoteAssignment, 'midnight');
    });

    test('bad JSON', () async {
      server.body = 'not json {';
      expect(await s.refresh(force: true), isFalse);
      expect(s.remoteAssignment, 'midnight');
    });

    test('a failed check is retried without waiting', () async {
      server.fail = true;
      now = now.add(const Duration(hours: 7));
      await s.refresh();
      server.fail = false;
      server.body = {'icon': 'violet'};
      expect(await s.refresh(), isTrue);
      expect(s.remoteAssignment, 'violet');
    });
  });

  test('checks are throttled by checkEvery and force bypasses it', () async {
    server.body = {'icon': 'midnight'};
    final s = make();
    await s.init();
    expect(server.requests, 1);

    server.body = {'icon': 'violet'};
    now = now.add(const Duration(hours: 5));
    expect(await s.refresh(), isFalse);
    expect(server.requests, 1);
    expect(s.remoteAssignment, 'midnight');

    expect(await s.refresh(force: true), isTrue);
    expect(server.requests, 2);
    expect(s.remoteAssignment, 'violet');

    server.body = {'icon': 'classic'};
    now = now.add(const Duration(hours: 6));
    expect(await s.refresh(), isTrue);
    expect(server.requests, 3);
  });

  test('the throttle survives a restart', () async {
    server.body = {'icon': 'midnight'};
    await make().init();
    expect(server.requests, 1);
    now = now.add(const Duration(hours: 1));
    await make().init();
    expect(server.requests, 1);
  });

  test('no remote URL means no requests', () async {
    final s = AppIconChanger(
      icons: icons,
      defaultIconId: 'classic',
      httpClient: server.client,
      store: store,
      platform: platform,
    );
    await s.init();
    expect(await s.refresh(force: true), isFalse);
    expect(server.requests, 0);
  });

  test('state persists across a new instance with the same store', () async {
    server.body = {'icon': 'midnight'};
    final first = make();
    await first.init();
    await first.choose('violet');
    first.dispose();

    server.fail = true;
    final second = make();
    await second.init();
    expect(second.userChoice, 'violet');
    expect(second.remoteAssignment, 'midnight');
    expect(second.effectiveIconId, 'midnight');
  });

  test('stale stored ids are ignored', () async {
    store = MemoryIconStore({
      AppIconChanger.userChoiceKey: 'gone',
      AppIconChanger.remoteAssignmentKey: 'also-gone',
    });
    final s = make(url: null);
    await s.init();
    expect(s.userChoice, isNull);
    expect(s.remoteAssignment, isNull);
    expect(s.effectiveIconId, 'classic');
  });

  test('choose with an unknown id throws', () async {
    final s = make();
    await s.init();
    expect(() => s.choose('rainbow'), throwsArgumentError);
    expect(s.userChoice, isNull);
  });

  test('constructor rejects an unknown default', () {
    expect(
      () => AppIconChanger(
        icons: icons,
        defaultIconId: 'nope',
        store: store,
        platform: platform,
      ),
      throwsArgumentError,
    );
  });

  test('apply skips the platform call when the icon already matches', () async {
    platform.current = 'AppIcon-Violet';
    store = MemoryIconStore({AppIconChanger.userChoiceKey: 'violet'});
    final s = make();
    await s.init();
    await s.apply();
    expect(platform.calls, isNot(contains('setIcon')));
    expect(platform.calls, contains('getCurrentIcon'));
  });

  test('apply does nothing when alternate icons are unsupported', () async {
    platform.supported = false;
    final s = make();
    await s.init();
    await s.choose('violet');
    expect(platform.calls, isNot(contains('getCurrentIcon')));
    expect(platform.calls, isNot(contains('setIcon')));
  });

  test('notifies listeners on changes', () async {
    final s = make();
    var count = 0;
    s.addListener(() => count++);
    await s.init();
    final afterInit = count;
    await s.choose('violet');
    expect(count, greaterThan(afterInit));
  });

  group('lifecycle', () {
    testWidgets('iOS applies right away', (tester) async {
      final s = make();
      s.attachLifecycle();
      await tester.runAsync(s.init);
      await tester.runAsync(() => s.choose('violet'));
      expect(platform.current, 'AppIcon-Violet');
      expect(s.hasPendingChange, isFalse);
      s.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android defers until paused', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      platform.current = 'IconClassic';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final s = make();
      s.attachLifecycle();
      await tester.runAsync(s.init);
      await tester.runAsync(() => s.choose('violet'));
      expect(platform.calls, isNot(contains('setIcon')));
      expect(s.hasPendingChange, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(platform.setIconArgs, [
        {
          'iosName': 'AppIcon-Violet',
          'androidAlias': 'IconViolet',
          'androidAliases': aliases,
        },
      ]);
      expect(s.hasPendingChange, isFalse);

      // Already in the background: applies at once.
      await tester.runAsync(() => s.choose('midnight'));
      expect(platform.current, 'IconMidnight');
      s.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android without attachLifecycle applies at once', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final s = make();
      await tester.runAsync(s.init);
      await tester.runAsync(() => s.choose('violet'));
      expect(platform.current, 'IconViolet');
      s.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('resume triggers a refresh when due', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final s = make();
      s.attachLifecycle();
      await tester.runAsync(s.init);
      expect(server.requests, 1);

      server.body = {'icon': 'midnight'};
      now = now.add(const Duration(hours: 7));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(server.requests, 2);
      expect(s.remoteAssignment, 'midnight');
      s.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('method channel', () {
    final channel = MethodChannelAppIconChanger();
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel.methodChannel, (call) async {
            log.add(call);
            return switch (call.method) {
              'isSupported' => true,
              'getCurrentIcon' => 'IconMidnight',
              'setIcon' => true,
              _ => null,
            };
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel.methodChannel, null);
    });

    test('uses the remote_icon_changer channel', () {
      expect(channel.methodChannel.name, 'remote_icon_changer');
    });

    test('isSupported has no arguments', () async {
      expect(await channel.isSupported(), isTrue);
      expect(log.single.method, 'isSupported');
      expect(log.single.arguments, isNull);
    });

    test('getCurrentIcon sends no arguments, or the alias list', () async {
      expect(await channel.getCurrentIcon(), 'IconMidnight');
      expect(log.last.arguments, isNull);
      await channel.getCurrentIcon(androidAliases: aliases);
      expect(log.last.method, 'getCurrentIcon');
      expect(log.last.arguments, {'androidAliases': aliases});
    });

    test('setIcon sends iosName, androidAlias and androidAliases', () async {
      expect(
        await channel.setIcon(
          iosName: null,
          androidAlias: 'IconClassic',
          androidAliases: aliases,
        ),
        isTrue,
      );
      expect(log.single.method, 'setIcon');
      expect(log.single.arguments, {
        'iosName': null,
        'androidAlias': 'IconClassic',
        'androidAliases': aliases,
      });
    });

    test('isSupported is false when the plugin is missing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel.methodChannel, null);
      expect(await channel.isSupported(), isFalse);
    });

    test('the default platform instance is the method channel', () {
      expect(
        AppIconChangerPlatform.instance,
        isA<MethodChannelAppIconChanger>(),
      );
    });
  });
}
