import 'user.dart';

class AuthSession {
  final String token;
  final String tokenType;
  final UserModel user;

  const AuthSession({
    required this.token,
    required this.tokenType,
    required this.user,
  });

  factory AuthSession.fromApiData(Map<String, dynamic> data) {
    final rawUser = data['user'];

    if (rawUser is! Map) {
      throw const FormatException(
        'Data user tidak ditemukan pada respons autentikasi.',
      );
    }

    final token = data['token']?.toString().trim() ?? '';

    if (token.isEmpty) {
      throw const FormatException(
        'Token autentikasi tidak ditemukan pada respons server.',
      );
    }

    return AuthSession(
      token: token,
      tokenType: data['token_type']?.toString() ?? 'Bearer',
      user: UserModel.fromJson(
        Map<String, dynamic>.from(rawUser),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'token_type': tokenType,
      'user': user.toJson(),
    };
  }
}
