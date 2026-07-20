import '../../core/network/api_exception.dart';
import '../datasources/owner_remote_datasource.dart';
import '../models/owner_dashboard.dart';
import '../models/owner_sales_report.dart';
import '../../core/network/api_download.dart';
import '../models/user.dart';

class OwnerRepository {
  OwnerRepository({OwnerRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? OwnerRemoteDataSource();

  final OwnerRemoteDataSource _remoteDataSource;

  Future<OwnerDashboardModel> getDashboard({String period = 'today'}) async {
    final response = await _remoteDataSource.getDashboard(period: period);
    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message: 'Ringkasan dashboard owner dari server tidak lengkap.',
      );
    }

    try {
      return OwnerDashboardModel.fromJson(data);
    } catch (error) {
      throw ApiException(
        message: 'Ringkasan dashboard owner tidak dapat dibaca: $error',
      );
    }
  }

  Future<List<UserModel>> getUsers({
    String? search,
    String? role,
    String? status,
    bool staffOnly = false,
    int perPage = 100,
  }) async {
    final response = await _remoteDataSource.getUsers(
      search: search,
      role: role,
      status: status,
      staffOnly: staffOnly,
      perPage: perPage,
    );

    try {
      return response.dataAsList
          .whereType<Map>()
          .map((item) => UserModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (error) {
      throw ApiException(message: 'Daftar pengguna tidak dapat dibaca: $error');
    }
  }

  Future<UserModel> createStaff({
    required String name,
    required String email,
    required String password,
    required String role,
    required String status,
    String? phone,
  }) async {
    final response = await _remoteDataSource.createStaff(
      name: name,
      email: email,
      password: password,
      role: role,
      status: status,
      phone: phone,
    );

    return _parseUser(response.dataAsMap, 'Data staff baru');
  }

  Future<OwnerSalesReportModel> getSalesReport({
    required DateTime startDate,
    required DateTime endDate,
    String? channel,
  }) async {
    final response = await _remoteDataSource.getSalesReport(
      startDate: startDate,
      endDate: endDate,
      channel: channel,
    );
    final data = response.dataAsMap;
    if (data == null) {
      throw const ApiException(message: 'Data laporan penjualan tidak lengkap.');
    }
    try {
      return OwnerSalesReportModel.fromJson(data);
    } catch (error) {
      throw ApiException(message: 'Laporan penjualan tidak dapat dibaca: $error');
    }
  }

  Future<ApiDownload> downloadSalesReport({
    required DateTime startDate,
    required DateTime endDate,
    required String format,
    String? channel,
  }) {
    return _remoteDataSource.downloadSalesReport(
      startDate: startDate,
      endDate: endDate,
      channel: channel,
      format: format,
    );
  }

  Future<UserModel> updateUserRole({
    required int userId,
    required String role,
  }) async {
    final response = await _remoteDataSource.updateUserRole(
      userId: userId,
      role: role,
    );

    return _parseUser(response.dataAsMap, 'Data perubahan role');
  }

  Future<UserModel> updateUserStatus({
    required int userId,
    required String status,
  }) async {
    final response = await _remoteDataSource.updateUserStatus(
      userId: userId,
      status: status,
    );

    return _parseUser(response.dataAsMap, 'Data perubahan status');
  }

  UserModel _parseUser(Map<String, dynamic>? data, String label) {
    if (data == null) {
      throw ApiException(message: '$label dari server tidak lengkap.');
    }

    try {
      return UserModel.fromJson(data);
    } catch (error) {
      throw ApiException(message: '$label tidak dapat dibaca: $error');
    }
  }
}
