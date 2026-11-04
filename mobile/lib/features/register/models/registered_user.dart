class RegisteredUser {
  const RegisteredUser({
    required this.userId,
    required this.role,
    required this.name,
    required this.alias,
    required this.email,
  });

  final int userId;
  final String role;
  final String name;
  final String alias;
  final String email;

  factory RegisteredUser.fromJson(Map<String, dynamic> json) => RegisteredUser(
    userId: json['user_id'] as int,
    role: json['role'] as String,
    name: json['name'] as String,
    alias: json['alias'] as String,
    email: json['email'] as String,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'role': role,
    'name': name,
    'alias': alias,
    'email': email,
  };
}
