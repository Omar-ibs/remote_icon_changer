import 'package:remote_icon_changer/remote_icon_changer.dart';
import 'package:remote_icon_changer_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the current icon and the choices', (tester) async {
    final changer = AppIconChanger(
      icons: icons,
      defaultIconId: 'classic',
      store: MemoryIconStore(),
    );
    await tester.pumpWidget(MyApp(changer: changer));
    expect(find.text('Current icon'), findsOneWidget);
    expect(find.text('midnight'), findsOneWidget);
  });
}
