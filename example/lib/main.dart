import 'package:app_icon_switcher/app_icon_switcher.dart';
import 'package:flutter/material.dart';

/// The icons this app bundles. To really switch icons, add the matching
/// activity-aliases (Android) and alternate icon sets (iOS); see the README.
const icons = [
  AppIcon(id: 'classic', androidAlias: 'IconClassic'),
  AppIcon(
    id: 'midnight',
    androidAlias: 'IconMidnight',
    iosName: 'AppIcon-Midnight',
  ),
];

void main() {
  final switcher = AppIconSwitcher(
    icons: icons,
    defaultIconId: 'classic',
    // remoteUrl: Uri.parse('https://example.com/app-icon.json'),
  )..attachLifecycle();
  switcher.init();
  runApp(MyApp(switcher: switcher));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.switcher});

  final AppIconSwitcher switcher;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('App icon switcher')),
        body: ListenableBuilder(
          listenable: switcher,
          builder: (context, _) => RadioGroup<String>(
            groupValue: switcher.userChoice ?? switcher.defaultIconId,
            onChanged: (id) => _choose(context, id!),
            child: ListView(
              children: [
                ListTile(
                  title: const Text('Current icon'),
                  subtitle: Text(switcher.effectiveIconId),
                ),
                if (switcher.isAssignedRemotely)
                  const ListTile(title: Text('Assigned by the remote config')),
                if (switcher.hasPendingChange)
                  const ListTile(title: Text('Changes when you leave the app')),
                for (final icon in switcher.icons)
                  RadioListTile<String>(title: Text(icon.id), value: icon.id),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _choose(BuildContext context, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await switcher.choose(id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not switch: $e')));
    }
  }
}
