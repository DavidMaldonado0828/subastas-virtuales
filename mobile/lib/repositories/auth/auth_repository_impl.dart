import '../../models/auth/auth_models.dart';
import '../../services/auth/auth_service.dart';
import 'auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this.service});

  final AuthService service;

  @override
  Future<AuthResponse> login(LoginRequest request) => service.login(request);

  @override
  Future<void> logout() => service.clearSession();
}
