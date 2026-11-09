import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/register/registered_user.dart';
import '../../models/auth/auth_models.dart';
import '../../repositories/auth/auth_repository.dart';
import '../../services/auth/auth_service.dart'
    show statusFromAuthDio, detailFromAuthDio;

sealed class LoginEvent extends Equatable {
  const LoginEvent();
  @override
  List<Object?> get props => [];
}

final class LoginSubmitted extends LoginEvent {
  const LoginSubmitted(this.email, this.password);
  final String email;
  final String password;
  @override
  List<Object?> get props => [email, password];
}

final class LoginFieldChanged extends LoginEvent {
  const LoginFieldChanged(this.field);
  final String field;
  @override
  List<Object?> get props => [field];
}

final class LoginLogoutRequested extends LoginEvent {
  const LoginLogoutRequested();
}

sealed class LoginState extends Equatable {
  const LoginState({this.fieldErrors = const {}, this.message});
  final Map<String, String> fieldErrors;
  final String? message;
  @override
  List<Object?> get props => [fieldErrors, message];
}

final class LoginInitial extends LoginState {
  const LoginInitial({super.fieldErrors, super.message});
}

final class LoginSubmitting extends LoginState {
  const LoginSubmitting();
}

final class LoginSuccess extends LoginState {
  const LoginSuccess(this.user);
  final RegisteredUser user;
  @override
  List<Object?> get props => [user];
}

final class LoginFailure extends LoginState {
  const LoginFailure({super.fieldErrors, super.message});
}

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc(this.repository) : super(const LoginInitial()) {
    on<LoginSubmitted>(_submit);
    on<LoginLogoutRequested>((event, emit) async {
      await repository.logout();
      emit(const LoginInitial());
    });
    on<LoginFieldChanged>((event, emit) {
      if (!state.fieldErrors.containsKey(event.field)) return;
      final errors = Map<String, String>.of(state.fieldErrors)
        ..remove(event.field);
      emit(LoginInitial(fieldErrors: errors));
    });
  }

  final AuthRepository repository;

  Future<void> _submit(LoginSubmitted event, Emitter<LoginState> emit) async {
    final errors = <String, String>{};
    if (!_validEmail(event.email)) {
      errors['email'] = 'Ingresa un correo válido.';
    }
    if (event.password.isEmpty) errors['password'] = 'Ingresa tu contraseña.';
    if (errors.isNotEmpty) {
      emit(LoginFailure(fieldErrors: errors));
      return;
    }
    emit(const LoginSubmitting());
    try {
      final response = await repository.login(
        LoginRequest(email: event.email.trim(), password: event.password),
      );
      emit(LoginSuccess(response.user));
    } on DioException catch (error) {
      final status = statusFromAuthDio(error) ?? error.response?.statusCode;
      if (status == 422) {
        emit(
          LoginFailure(fieldErrors: _validationErrors(error.response?.data)),
        );
      } else if (status == 401) {
        emit(
          LoginFailure(
            message:
                detailFromAuthDio(error) ?? 'Email o contraseña incorrectos.',
          ),
        );
      } else if (status == 403) {
        emit(
          LoginFailure(
            message:
                detailFromAuthDio(error) ?? 'No tienes acceso a esta cuenta.',
          ),
        );
      } else if ({
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
      }.contains(error.type)) {
        emit(
          const LoginFailure(message: 'No se pudo conectar con el servidor'),
        );
      } else {
        emit(
          LoginFailure(
            message:
                detailFromAuthDio(error) ??
                'No fue posible completar la solicitud.',
          ),
        );
      }
    } catch (_) {
      emit(
        const LoginFailure(message: 'No fue posible completar la solicitud.'),
      );
    }
  }

  static bool _validEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  static Map<String, String> _validationErrors(dynamic body) {
    final result = <String, String>{};
    final detail = body is Map ? body['detail'] : null;
    if (detail is List) {
      for (final item in detail) {
        if (item is Map) {
          final loc = item['loc'];
          final field = loc is List && loc.isNotEmpty
              ? loc.last.toString()
              : '';
          if (field == 'email') result[field] = 'Ingresa un correo válido.';
          if (field == 'password') result[field] = 'Ingresa tu contraseña.';
        }
      }
    }
    if (result.isEmpty && detail is String) result['email'] = detail;
    return result;
  }
}
