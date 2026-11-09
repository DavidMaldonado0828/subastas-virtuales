import 'package:dio/dio.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';
import '../../models/auth/auth_models.dart';

class AuthService {
  AuthService({required this.client, required this.session});

  final ApiClient client;
  final AuthSession session;

  Future<AuthResponse> login(LoginRequest request) async {
    final response = await client.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: request.toJson(),
    );
    final result = AuthResponse.fromJson(response.data!);
    await session.save(result);
    return result;
  }

  Future<void> clearSession() => session.clear();
}

int? statusFromAuthDio(DioException error) =>
    error.requestOptions.extra['apiStatus'] as int?;

String? detailFromAuthDio(DioException error) =>
    error.requestOptions.extra['apiDetail'] as String?;
