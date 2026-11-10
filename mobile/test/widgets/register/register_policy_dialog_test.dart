import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/bloc/register/register_bloc.dart';
import 'package:movil/core/config/register_policy_content.dart';
import 'package:movil/models/register/registered_user.dart';
import 'package:movil/pages/register/register_page.dart';
import 'package:movil/repositories/register/register_repository.dart';

class _RegisterRepository implements RegisterRepository {
  @override
  Future<RegisteredUser> register(Map<String, dynamic> payload) async =>
      const RegisteredUser(
        userId: 1,
        role: 'POSTOR',
        name: 'Participante',
        alias: 'alias',
        email: 'alias@example.test',
      );

  @override
  Future<void> clearUser() async {}

  @override
  Future<void> saveUser(RegisteredUser user) async {}
}

void main() {
  testWidgets('el enlace abre la política y Acepto marca el checkbox', (
    tester,
  ) async {
    final bloc = RegisterBloc(_RegisterRepository());
    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          home: RegisterPage(storage: const FlutterSecureStorage()),
        ),
      ),
    );

    final link = find.text('pol\u00edtica de pujas');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(find.text(registerPolicyTitle), findsOneWidget);
    expect(find.text('Cerrar'), findsOneWidget);
    expect(find.text('Acepto'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);

    await tester.tap(find.text('Acepto'));
    await tester.pumpAndSettle();

    expect(bloc.state.acceptedPolicy, isTrue);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });
}
