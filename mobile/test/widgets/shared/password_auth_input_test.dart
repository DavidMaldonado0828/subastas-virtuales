import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/widgets/shared/password_auth_input.dart';

void main() {
  testWidgets('muestra el ojo solo mientras la contraseña tiene texto', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PasswordAuthInput(
            controller: controller,
            label: 'Contraseña',
          ),
        ),
      ),
    );

    expect(find.byType(IconButton), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);

    await tester.enterText(find.byType(TextField), 'clave123');
    await tester.pump();

    expect(find.byType(IconButton), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isFalse);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    expect(find.byType(IconButton), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
  });
}
