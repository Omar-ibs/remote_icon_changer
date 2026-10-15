import 'package:app_icon_switcher/app_icon_switcher.dart';
import 'package:app_icon_switcher_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the current icon and the choices', (tester) async {
    final switcher = AppIconSwitcher(
      icons: icons,
      defaultIconId: 'classic',
      store: MemoryIconStore(),
    );
    await tester.pumpWidget(MyApp(switcher: switcher));
    expect(find.text('Current icon'), findsOneWidget);
    expect(find.text('midnight'), findsOneWidget);
  });
}
