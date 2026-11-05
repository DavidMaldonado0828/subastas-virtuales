import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/core/auth/auth_session.dart';
import 'package:movil/features/auth/bloc/login_bloc.dart';
import 'package:movil/features/auth/models/auth_models.dart';
import 'package:movil/features/auth/repositories/auth_repository.dart';
import 'package:movil/features/register/models/registered_user.dart';

class FakeAuthRepository implements AuthRepository {
  Future<AuthResponse> Function(LoginRequest) loginCall = (_) async =>
      authResponse;
  @override
  Future<AuthResponse> login(LoginRequest request) => loginCall(request);
  @override
  Future<void> logout() async {}
}

const testUser = RegisteredUser(
  userId: 4,
  role: 'POSTOR',
  name: 'Ana',
  alias: 'ana',
  email: 'ana@example.com',
);
final authResponse = AuthResponse(
  accessToken: 'jwt',
  tokenType: 'bearer',
  expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  user: testUser,
);

DioException apiError(int status, dynamic body) => DioException(
  requestOptions: RequestOptions(
    path: '/auth/login',
    extra: {
      'apiStatus': status,
      if (body is Map && body['detail'] is String) 'apiDetail': body['detail'],
    },
  ),
  response: Response(
    requestOptions: RequestOptions(path: '/auth/login'),
    statusCode: status,
    data: body,
  ),
  type: DioExceptionType.badResponse,
);

class MemoryStorage extends FlutterSecureStorage {
  final values = <String, String>{};
  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];
  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values.remove(key);
}

void main() {
  late FakeAuthRepository repository;
  setUp(() => repository = FakeAuthRepository());

  blocTest<LoginBloc, LoginState>(
    'login exitoso emite envío y usuario autenticado',
    build: () => LoginBloc(repository),
    act: (bloc) => bloc.add(const LoginSubmitted('ana@example.com', 'clave')),
    expect: () => [
      isA<LoginSubmitting>(),
      isA<LoginSuccess>().having((s) => s.user.alias, 'alias', 'ana'),
    ],
  );

  blocTest<LoginBloc, LoginState>(
    '401 muestra el mensaje genérico del API',
    build: () {
      repository.loginCall = (_) async =>
          throw apiError(401, {'detail': 'Email o contraseña incorrectos.'});
      return LoginBloc(repository);
    },
    act: (bloc) => bloc.add(const LoginSubmitted('ana@example.com', 'bad')),
    expect: () => [
      isA<LoginSubmitting>(),
      isA<LoginFailure>().having(
        (s) => s.message,
        'message',
        'Email o contraseña incorrectos.',
      ),
    ],
  );

  blocTest<LoginBloc, LoginState>(
    '403 muestra el detalle de cuenta bloqueada',
    build: () {
      repository.loginCall = (_) async =>
          throw apiError(403, {'detail': 'Su cuenta está bloqueada.'});
      return LoginBloc(repository);
    },
    act: (bloc) => bloc.add(const LoginSubmitted('ana@example.com', 'clave')),
    expect: () => [
      isA<LoginSubmitting>(),
      isA<LoginFailure>().having(
        (s) => s.message,
        'message',
        'Su cuenta está bloqueada.',
      ),
    ],
  );

  blocTest<LoginBloc, LoginState>(
    '422 coloca validaciones de API en su campo',
    build: () {
      repository.loginCall = (_) async => throw apiError(422, {
        'detail': [
          {
            'loc': ['body', 'email'],
            'type': 'value_error',
          },
        ],
      });
      return LoginBloc(repository);
    },
    act: (bloc) => bloc.add(const LoginSubmitted('ana@example.com', 'clave')),
    expect: () => [
      isA<LoginSubmitting>(),
      isA<LoginFailure>().having(
        (s) => s.fieldErrors['email'],
        'email error',
        'Ingresa un correo válido.',
      ),
    ],
  );

  blocTest<LoginBloc, LoginState>(
    'error de conexión presenta su texto específico',
    build: () {
      repository.loginCall = (_) async => throw DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        type: DioExceptionType.connectionError,
      );
      return LoginBloc(repository);
    },
    act: (bloc) => bloc.add(const LoginSubmitted('ana@example.com', 'clave')),
    expect: () => [
      isA<LoginSubmitting>(),
      isA<LoginFailure>().having(
        (s) => s.message,
        'message',
        'No se pudo conectar con el servidor',
      ),
    ],
  );

  test('restaura la sesión almacenada solo si el token no expiró', () async {
    final storage = MemoryStorage()
      ..values[AuthSession.tokenKey] = 'jwt'
      ..values[AuthSession.userKey] = jsonEncode(testUser.toJson())
      ..values[AuthSession.expiresAtKey] = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .toIso8601String();
    final session = AuthSession(storage);
    await session.restore();
    expect(session.isAuthenticated, isTrue);
    expect(session.user?.alias, 'ana');
  });
}
