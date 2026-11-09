import '../register/registered_user.dart';

class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final DateTime expiresAt;
  final RegisteredUser user;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    accessToken: json['access_token'] as String,
    tokenType: json['token_type'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String),
    user: RegisteredUser.fromJson(json['user'] as Map<String, dynamic>),
  );
}
