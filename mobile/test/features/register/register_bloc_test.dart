import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:movil/features/register/models/registered_user.dart';
import 'package:movil/features/register/repositories/register_repository.dart';
import 'package:movil/features/register/bloc/register_bloc.dart';

class FakeRegisterRepository implements RegisterRepository {
  Future<RegisteredUser> Function(Map<String, dynamic>) registerCall =
      (_) async => const RegisteredUser(
        userId: 7,
        role: 'POSTOR',
        name: 'Nombre',
        alias: 'alias',
        email: 'a@b.co',
      );
  Map<String, dynamic>? savedPayload;
  @override
  Future<RegisteredUser> register(Map<String, dynamic> payload) =>
      registerCall(payload);
  @override
  Future<void> saveUser(RegisteredUser user) async {
    savedPayload = user.toJson();
  }

  @override
  Future<void> clearUser() async {
    savedPayload = null;
  }
}

const values = <String, String>{
  'name': 'Nombre',
  'alias': 'alias',
  'email': 'a@b.co',
  'phone_number': '123',
  'password': '12345678',
  'confirmPassword': '12345678',
  'address': '',
};

DioException apiError(int status, dynamic body) => DioException(
  requestOptions: RequestOptions(
    path: '/auth/register',
    extra: {
      'apiStatus': status,
      if (body is Map && body['detail'] is String) 'apiDetail': body['detail'],
    },
  ),
  response: Response(
    requestOptions: RequestOptions(path: '/auth/register'),
    statusCode: status,
    data: body,
  ),
  type: DioExceptionType.badResponse,
);

void main() {
  late FakeRegisterRepository repository;
  setUp(() => repository = FakeRegisterRepository());

  blocTest<RegisterBloc, RegisterState>(
    'éxito guarda usuario devuelto y emite éxito',
    build: () => RegisterBloc(repository),
    act: (bloc) {
      bloc.add(const RegisterRoleChanged('VENDEDOR'));
      bloc.add(const RegisterSubmitted(values));
    },
    expect: () => [
      isA<RegisterInitial>().having((s) => s.role, 'role', 'VENDEDOR'),
      isA<RegisterSubmitting>(),
      isA<RegisterSuccess>(),
    ],
    verify: (_) => expect(repository.savedPayload?['alias'], 'alias'),
  );

  blocTest<RegisterBloc, RegisterState>(
    '422 presenta errores por campo',
    build: () {
      repository.registerCall = (_) async => throw apiError(422, {
        'detail': [
          {
            'loc': ['body', 'email'],
            'type': 'value_error',
          },
        ],
      });
      return RegisterBloc(repository);
    },
    act: (bloc) {
      bloc.add(const RegisterRoleChanged('VENDEDOR'));
      bloc.add(const RegisterSubmitted(values));
    },
    expect: () => [
      isA<RegisterInitial>(),
      isA<RegisterSubmitting>(),
      isA<RegisterFailure>().having(
        (s) => s.fieldErrors['email'],
        'email error',
        'Ingresa un correo válido.',
      ),
    ],
  );

  blocTest<RegisterBloc, RegisterState>(
    '409 muestra detail',
    build: () {
      repository.registerCall = (_) async =>
          throw apiError(409, {'detail': 'El correo ya existe'});
      return RegisterBloc(repository);
    },
    act: (bloc) {
      bloc.add(const RegisterRoleChanged('VENDEDOR'));
      bloc.add(const RegisterSubmitted(values));
    },
    expect: () => [
      isA<RegisterInitial>(),
      isA<RegisterSubmitting>(),
      isA<RegisterFailure>().having(
        (s) => s.message,
        'message',
        'El correo ya existe',
      ),
    ],
  );

  blocTest<RegisterBloc, RegisterState>(
    'error de red muestra mensaje de conexión',
    build: () {
      repository.registerCall = (_) async => throw DioException(
        requestOptions: RequestOptions(path: '/auth/register'),
        type: DioExceptionType.connectionError,
      );
      return RegisterBloc(repository);
    },
    act: (bloc) {
      bloc.add(const RegisterRoleChanged('VENDEDOR'));
      bloc.add(const RegisterSubmitted(values));
    },
    expect: () => [
      isA<RegisterInitial>(),
      isA<RegisterSubmitting>(),
      isA<RegisterFailure>().having(
        (s) => s.message,
        'message',
        'No se pudo conectar con el servidor',
      ),
    ],
  );

  blocTest<RegisterBloc, RegisterState>(
    'política es obligatoria para Participante',
    build: () => RegisterBloc(repository),
    act: (bloc) => bloc.add(const RegisterSubmitted(values)),
    expect: () => [
      isA<RegisterFailure>().having(
        (s) => s.fieldErrors['accept_bid_policy'],
        'policy error',
        'Debes aceptar la política para registrarte como participante.',
      ),
    ],
  );
}
