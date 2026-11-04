import '../models/registered_user.dart';
import '../services/register_service.dart';
import 'register_repository.dart';

class RegisterRepositoryImpl implements RegisterRepository {
  RegisterRepositoryImpl({required this.service});

  final RegisterService service;

  @override
  Future<RegisteredUser> register(Map<String, dynamic> payload) async {
    return service.register(payload);
  }

  @override
  Future<void> saveUser(RegisteredUser user) =>
      service.saveUser(user);

  @override
  Future<void> clearUser() => service.clearUser();
}
