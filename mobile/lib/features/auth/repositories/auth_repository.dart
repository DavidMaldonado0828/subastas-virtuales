import '../models/auth_models.dart';

abstract interface class AuthRepository {
  Future<AuthResponse> login(LoginRequest request);
  Future<void> logout();
}
