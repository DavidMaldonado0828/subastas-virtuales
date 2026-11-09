import '../../models/register/registered_user.dart';

abstract interface class RegisterRepository {
  Future<RegisteredUser> register(Map<String, dynamic> payload);
  Future<void> saveUser(RegisteredUser user);
  Future<void> clearUser();
}
