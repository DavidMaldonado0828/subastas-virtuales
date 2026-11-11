import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/core/auth/auth_session.dart';
import 'package:movil/models/home/auction.dart';
import 'package:movil/models/register/registered_user.dart';
import 'package:movil/pages/home/home_page.dart';
import 'package:movil/repositories/home/auction_repository.dart';

class _Repository implements AuctionRepository {
  @override
  Future<AuctionPage> fetch({
    required int limit,
    required int offset,
    bool closed = false,
  }) async => const AuctionPage(items: [], limit: 10, offset: 0);
  @override
  Future<MyAuctionPage> fetchMyAuctions({
    required int limit,
    required int offset,
  }) async => const MyAuctionPage(items: []);
}

Future<void> _pump(WidgetTester tester, String role) async {
  final session = AuthSession(const FlutterSecureStorage())
    ..user = RegisteredUser(
      userId: 1,
      role: role,
      name: 'Usuario',
      alias: 'alias',
      email: 'mail@example.test',
    );
  await tester.pumpWidget(
    RepositoryProvider<AuctionRepository>.value(
      value: _Repository(),
      child: MaterialApp(home: HomePage(session: session)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('POSTOR ve Mis subastas y Cerrar sesión', (tester) async {
    await _pump(tester, 'POSTOR');
    await tester.tap(find.byTooltip('Cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Mis subastas'), findsOneWidget);
    expect(find.text('Cerrar sesi\u00f3n'), findsOneWidget);
  });

  testWidgets('VENDEDOR ve sus subastas y productos', (tester) async {
    await _pump(tester, 'VENDEDOR');
    await tester.tap(find.byTooltip('Cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Mis subastas'), findsOneWidget);
    expect(find.text('Mis productos'), findsOneWidget);
    expect(find.text('Mis pujas'), findsNothing);
    expect(find.text('Cerrar sesi\u00f3n'), findsOneWidget);
  });

  testWidgets('ADMIN solo ve Cerrar sesión', (tester) async {
    await _pump(tester, 'ADMIN');
    await tester.tap(find.byTooltip('Cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Mis subastas'), findsNothing);
    expect(find.text('Mis productos'), findsNothing);
    expect(find.text('Cerrar sesi\u00f3n'), findsOneWidget);
  });
}
