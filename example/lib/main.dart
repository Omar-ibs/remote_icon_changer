import 'package:remote_icon_changer/remote_icon_changer.dart';
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
  final changer = AppIconChanger(
    icons: icons,
    defaultIconId: 'classic',
    // remoteUrl: Uri.parse('https://example.com/app-icon.json'),
  )..attachLifecycle();
  changer.init();
  runApp(MyApp(changer: changer));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.changer});

  final AppIconChanger changer;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('App icon changer')),
        body: ListenableBuilder(
          listenable: changer,
          builder: (context, _) => RadioGroup<String>(
            groupValue: changer.userChoice ?? changer.defaultIconId,
            onChanged: (id) => _choose(context, id!),
            child: ListView(
              children: [
                ListTile(
                  title: const Text('Current icon'),
                  subtitle: Text(changer.effectiveIconId),
                ),
                if (changer.isAssignedRemotely)
                  const ListTile(title: Text('Assigned by the remote config')),
                if (changer.hasPendingChange)
                  const ListTile(title: Text('Changes when you leave the app')),
                for (final icon in changer.icons)
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
      await changer.choose(id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not switch: $e')));
    }
  }
}
