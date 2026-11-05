import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/models/auth_models.dart';
import '../../features/register/models/registered_user.dart';

class AuthSession extends ChangeNotifier {
  AuthSession(this.storage);

  final FlutterSecureStorage storage;
  static const tokenKey = 'subastas.accessToken';
  static const userKey = 'subastas.user';
  static const expiresAtKey = 'subastas.expiresAt';

  String? token;
  RegisteredUser? user;

  bool get isAuthenticated => token != null && user != null;

  Future<void> restore() async {
    try {
      final savedToken = await storage.read(key: tokenKey);
      final savedUser = await storage.read(key: userKey);
      final expiresAt = DateTime.tryParse(
        await storage.read(key: expiresAtKey) ?? '',
      );
      if (savedToken == null ||
          savedUser == null ||
          expiresAt == null ||
          !expiresAt.isAfter(DateTime.now())) {
        await clear(notify: false);
        return;
      }
      token = savedToken;
      user = RegisteredUser.fromJson(
        jsonDecode(savedUser) as Map<String, dynamic>,
      );
    } catch (_) {
      await clear(notify: false);
    }
    notifyListeners();
  }

  Future<void> save(AuthResponse response) async {
    await storage.write(key: tokenKey, value: response.accessToken);
    await storage.write(
      key: userKey,
      value: jsonEncode(response.user.toJson()),
    );
    await storage.write(
      key: expiresAtKey,
      value: response.expiresAt.toUtc().toIso8601String(),
    );
    token = response.accessToken;
    user = response.user;
    notifyListeners();
  }

  Future<void> clear({bool notify = true}) async {
    await storage.delete(key: tokenKey);
    await storage.delete(key: userKey);
    await storage.delete(key: expiresAtKey);
    token = null;
    user = null;
    if (notify) notifyListeners();
  }
}
