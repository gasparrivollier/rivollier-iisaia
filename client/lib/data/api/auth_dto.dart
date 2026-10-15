/// `UserOut` in backend/openapi.json.
class UserDto {
  const UserDto({required this.id, required this.email, required this.displayName});

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
        id: json['id'] as int,
        email: json['email'] as String,
        displayName: json['display_name'] as String,
      );

  final int id;
  final String email;
  final String displayName;
}

/// `AuthResponse` in backend/openapi.json (returned by register and login).
class AuthSession {
  const AuthSession({required this.accessToken, required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: json['access_token'] as String,
        user: UserDto.fromJson(json['user'] as Map<String, dynamic>),
      );

  final String accessToken;
  final UserDto user;
}
