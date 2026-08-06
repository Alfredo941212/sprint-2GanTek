import 'package:flutter_test/flutter_test.dart';
import 'package:gantek/app.dart';

void main() {
  testWidgets('Muestra la pantalla de inicio de sesión', (tester) async {
    await tester.pumpWidget(const GanTekApp());

    expect(find.text('GanTek'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
