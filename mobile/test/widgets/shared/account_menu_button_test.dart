import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/widgets/shared/account_menu_button.dart';

void main() {
  testWidgets('Mis productos aparece solo para VENDEDOR', (tester) async {
    Future<void> showRole(String role) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                AccountMenuButton(
                  alias: 'User',
                  role: role,
                  onLogout: () {},
                  onMyAuctions: () {},
                  onMyProducts: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
    }

    await showRole('VENDEDOR');
    expect(find.text('Mis productos'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await showRole('POSTOR');
    expect(find.text('Mis productos'), findsNothing);
  });
}
