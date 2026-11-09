import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/register/registered_user.dart';
import '../../repositories/register/register_repository.dart';
import '../../services/register/register_service.dart'
    show statusFromDio, detailFromDio;

sealed class RegisterEvent extends Equatable {
  const RegisterEvent();
  @override
  List<Object?> get props => [];
}

final class RegisterRoleChanged extends RegisterEvent {
  const RegisterRoleChanged(this.role);
  final String role;
  @override
  List<Object?> get props => [role];
}

final class RegisterPolicyChanged extends RegisterEvent {
  const RegisterPolicyChanged(this.accepted);
  final bool accepted;
  @override
  List<Object?> get props => [accepted];
}

final class RegisterFieldChanged extends RegisterEvent {
  const RegisterFieldChanged(this.field);
  final String field;
  @override
  List<Object?> get props => [field];
}

final class RegisterSubmitted extends RegisterEvent {
  const RegisterSubmitted(this.values);
  final Map<String, String> values;
  @override
  List<Object?> get props => [values];
}

final class RegisterLoggedOut extends RegisterEvent {
  const RegisterLoggedOut();
}

sealed class RegisterState extends Equatable {
  const RegisterState({
    this.role = 'POSTOR',
    this.acceptedPolicy = false,
    this.fieldErrors = const {},
    this.message,
  });
  final String role;
  final bool acceptedPolicy;
  final Map<String, String> fieldErrors;
  final String? message;
  @override
  List<Object?> get props => [role, acceptedPolicy, fieldErrors, message];
}

final class RegisterInitial extends RegisterState {
  const RegisterInitial({
    super.role,
    super.acceptedPolicy,
    super.fieldErrors,
    super.message,
  });
}

final class RegisterSubmitting extends RegisterState {
  const RegisterSubmitting({
    required super.role,
    required super.acceptedPolicy,
  });
}

final class RegisterSuccess extends RegisterState {
  const RegisterSuccess(
    this.user, {
    required super.role,
    required super.acceptedPolicy,
  });
  final RegisteredUser user;
  @override
  List<Object?> get props => [...super.props, user];
}

final class RegisterFailure extends RegisterState {
  const RegisterFailure({
    required super.role,
    required super.acceptedPolicy,
    super.fieldErrors,
    super.message,
  });
}

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc(this.repository) : super(const RegisterInitial()) {
    on<RegisterRoleChanged>(
      (event, emit) => emit(
        RegisterInitial(
          role: event.role,
          acceptedPolicy: event.role == state.role && state.acceptedPolicy,
        ),
      ),
    );
    on<RegisterPolicyChanged>(
      (event, emit) => emit(
        RegisterInitial(role: state.role, acceptedPolicy: event.accepted),
      ),
    );
    on<RegisterFieldChanged>((event, emit) {
      if (!state.fieldErrors.containsKey(event.field)) return;
      final errors = Map<String, String>.of(state.fieldErrors)
        ..remove(event.field);
      if (event.field == 'password') {
        if (errors['confirmPassword'] == 'Las contraseñas no coinciden.') {
          errors.remove('confirmPassword');
        }
      } else if (event.field == 'confirmPassword' &&
          errors['password']?.isEmpty == true) {
        errors.remove('password');
      }
      emit(
        RegisterFailure(
          role: state.role,
          acceptedPolicy: state.acceptedPolicy,
          fieldErrors: errors,
        ),
      );
    });
    on<RegisterSubmitted>(_submit);
    on<RegisterLoggedOut>((event, emit) async {
      await repository.clearUser();
      emit(const RegisterInitial());
    });
  }

  final RegisterRepository repository;

  Future<void> _submit(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    final role = state.role;
    final accepted = state.acceptedPolicy;
    if (role == 'POSTOR' && !accepted) {
      emit(
        RegisterFailure(
          role: role,
          acceptedPolicy: false,
          fieldErrors: const {
            'accept_bid_policy':
                'Debes aceptar la política para registrarte como participante.',
          },
        ),
      );
      return;
    }
    final values = event.values;
    final errors = <String, String>{};
    if (values['name']!.trim().isEmpty) {
      errors['name'] = 'Ingresa tu nombre.';
    }
    if (values['alias']!.trim().isEmpty) {
      errors['alias'] = 'Ingresa tu alias.';
    }
    if (!_validEmail(values['email']!)) {
      errors['email'] = 'Ingresa un correo válido.';
    }
    if (values['phone_number']!.trim().isEmpty) {
      errors['phone_number'] = 'Ingresa tu teléfono.';
    }
    if (values['password']!.length < 8) {
      errors['password'] = 'Usa al menos 8 caracteres.';
    } else if (values['password']!.length > 128) {
      errors['password'] = 'La contraseña no puede superar 128 caracteres.';
    }
    if (values['confirmPassword']!.isEmpty) {
      errors['confirmPassword'] = 'Confirma tu contraseña.';
    } else if (values['password'] != values['confirmPassword']) {
      errors.putIfAbsent('password', () => '');
      errors['confirmPassword'] = 'Las contraseñas no coinciden.';
    }
    if (errors.isNotEmpty) {
      emit(
        RegisterFailure(
          role: role,
          acceptedPolicy: accepted,
          fieldErrors: errors,
        ),
      );
      return;
    }
    emit(RegisterSubmitting(role: role, acceptedPolicy: accepted));
    final payload = <String, dynamic>{
      'role': role,
      'name': values['name']!.trim(),
      'alias': values['alias']!.trim(),
      'email': values['email']!.trim(),
      'phone_number': values['phone_number']!.trim(),
      'password': values['password'],
      'address': values['address']!.trim().isEmpty
          ? null
          : values['address']!.trim(),
      'accept_bid_policy': role == 'POSTOR' && accepted,
    };
    try {
      final user = await repository.register(payload);
      emit(RegisterSuccess(user, role: role, acceptedPolicy: accepted));
    } on DioException catch (error) {
      final status = statusFromDio(error);
      if (status == 422) {
        emit(
          RegisterFailure(
            role: role,
            acceptedPolicy: accepted,
            fieldErrors: _validationErrors(error.response?.data),
          ),
        );
      } else {
        final message =
            error.type == DioExceptionType.connectionError ||
                error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.receiveTimeout
            ? 'No se pudo conectar con el servidor'
            : detailFromDio(error) ?? 'Ocurrió un error. Inténtalo de nuevo.';
        emit(
          RegisterFailure(
            role: role,
            acceptedPolicy: accepted,
            message: message,
          ),
        );
      }
    } catch (_) {
      emit(
        RegisterFailure(
          role: role,
          acceptedPolicy: accepted,
          message: 'Ocurrió un error. Inténtalo de nuevo.',
        ),
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
          if (field.isNotEmpty) {
            result[field] = _messageFor(field, item['type']?.toString() ?? '');
          }
        }
      }
    }
    if (result.isEmpty && detail is String) result['email'] = detail;
    return result;
  }

  static String _messageFor(String field, String type) => switch (field) {
    'email' => 'Ingresa un correo válido.',
    'password' when type.contains('too_short') => 'Usa al menos 8 caracteres.',
    'password' when type.contains('too_long') =>
      'La contraseña no puede superar 128 caracteres.',
    'name' => 'Ingresa tu nombre.',
    'alias' => 'Ingresa tu alias.',
    'phone_number' => 'Ingresa tu teléfono.',
    _ => 'Revisa este campo.',
  };
}
