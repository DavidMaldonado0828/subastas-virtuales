import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../models/register/registered_user.dart';

class RegisterService {
  RegisterService({required this.client, required this.storage});

  final ApiClient client;
  final FlutterSecureStorage storage;
  static const _userKey = 'subastas.user';

  Future<RegisteredUser> register(Map<String, dynamic> payload) async {
    final response = await client.dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: payload,
    );
    return RegisteredUser.fromJson(response.data!);
  }

  Future<void> saveUser(RegisteredUser user) =>
      storage.write(key: _userKey, value: jsonEncode(user.toJson()));

  Future<void> clearUser() => storage.delete(key: _userKey);
}

int? statusFromDio(DioException error) =>
    error.requestOptions.extra['apiStatus'] as int?;

String? detailFromDio(DioException error) =>
    error.requestOptions.extra['apiDetail'] as String?;
