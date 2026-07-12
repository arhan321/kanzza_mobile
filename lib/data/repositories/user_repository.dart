import '../../core/network/api_exception.dart';
import '../../core/storage/auth_storage.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_session.dart';
import '../models/user.dart';

class UserRepository {
  UserRepository({
    AuthRemoteDataSource? remoteDataSource,
    AuthStorage? authStorage,
  }) : _remoteDataSource = remoteDataSource ?? AuthRemoteDataSource(),
       _authStorage = authStorage ?? AuthStorage.instance;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthStorage _authStorage;

  Future<AuthSession> login({
    required String email,
    required String password,
    String deviceName = 'Kanzza Flutter',
  }) async {
    final response = await _remoteDataSource.login(
      email: email,
      password: password,
      deviceName: deviceName,
    );

    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message: 'Data login dari server tidak lengkap.',
      );
    }

    try {
      final session = AuthSession.fromApiData(data);

      await _authStorage.saveSession(
        token: session.token,
        user: session.user.toJson(),
      );

      return session;
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<AuthSession> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    String deviceName = 'Kanzza Flutter',
  }) async {
    final response = await _remoteDataSource.register(
      name: name,
      email: email,
      phone: phone,
      password: password,
      passwordConfirmation: passwordConfirmation,
      deviceName: deviceName,
    );

    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message: 'Data registrasi dari server tidak lengkap.',
      );
    }

    try {
      final session = AuthSession.fromApiData(data);

      await _authStorage.saveSession(
        token: session.token,
        user: session.user.toJson(),
      );

      return session;
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<UserModel> getProfile() async {
    final response = await _remoteDataSource.getProfile();
    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message: 'Data pengguna dari server tidak lengkap.',
      );
    }

    final user = UserModel.fromJson(data);

    await _authStorage.saveUser(user.toJson());

    return user;
  }

  Future<UserModel?> restoreSession() async {
    final hasToken = await _authStorage.hasToken();

    if (!hasToken) {
      return null;
    }

    try {
      return await getProfile();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _authStorage.clearSession();
        return null;
      }

      rethrow;
    }
  }

  Future<UserModel?> getCachedUser() async {
    final data = await _authStorage.getUser();

    if (data == null) {
      return null;
    }

    return UserModel.fromJson(data);
  }

  Future<String?> getToken() {
    return _authStorage.getToken();
  }

  Future<bool> isLoggedIn() {
    return _authStorage.hasToken();
  }

  Future<void> logout() async {
    try {
      final hasToken = await _authStorage.hasToken();

      if (hasToken) {
        await _remoteDataSource.logout();
      }
    } on ApiException {
      // Session lokal tetap harus dibersihkan walaupun server gagal dihubungi.
    } finally {
      await _authStorage.clearSession();
    }
  }

  Future<void> clearLocalSession() {
    return _authStorage.clearSession();
  }
}
