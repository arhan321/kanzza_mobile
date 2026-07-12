import '../../core/network/api_exception.dart';
import '../datasources/cashier_transaction_remote_datasource.dart';
import '../models/cashier_transaction.dart';

class CashierTransactionRepository {
  CashierTransactionRepository({
    CashierTransactionRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource =
            remoteDataSource ??
            CashierTransactionRemoteDataSource();

  final CashierTransactionRemoteDataSource _remoteDataSource;

  Future<CashierTransactionModel> createTransaction({
    int? customerId,
    required List<Map<String, int>> items,
    required int paymentAmount,
    String? notes,
  }) async {
    final response = await _remoteDataSource.createTransaction(
      customerId: customerId,
      items: items,
      paymentAmount: paymentAmount,
      notes: notes,
    );

    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message:
            'Data transaksi dari server tidak lengkap.',
      );
    }

    try {
      return CashierTransactionModel.fromJson(data);
    } catch (error) {
      throw ApiException(
        message:
            'Data transaksi dari server tidak dapat dibaca: $error',
      );
    }
  }

  Future<List<CashierTransactionModel>> getTransactions({
    int perPage = 100,
  }) async {
    final response =
        await _remoteDataSource.getTransactions(
          perPage: perPage,
        );

    try {
      return response.dataAsList
          .whereType<Map>()
          .map(
            (item) => CashierTransactionModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (error) {
      throw ApiException(
        message:
            'Daftar transaksi dari server tidak dapat dibaca: $error',
      );
    }
  }
}
