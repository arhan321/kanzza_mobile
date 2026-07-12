import '../../core/network/api_exception.dart';
import '../datasources/driver_delivery_remote_datasource.dart';
import '../models/driver_delivery.dart';

class DriverDeliveryRepository {
  DriverDeliveryRepository({
    DriverDeliveryRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource =
            remoteDataSource ??
            DriverDeliveryRemoteDataSource();

  final DriverDeliveryRemoteDataSource _remoteDataSource;

  Future<List<DriverDeliveryModel>> getDeliveries({
    String? status,
    int perPage = 100,
  }) async {
    final response =
        await _remoteDataSource.getDeliveries(
      status: status,
      perPage: perPage,
    );

    try {
      final deliveries = response.dataAsList
          .whereType<Map>()
          .map(
            (item) => DriverDeliveryModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      deliveries.sort(
        (first, second) => second.sortDate.compareTo(
          first.sortDate,
        ),
      );

      return deliveries;
    } catch (error) {
      throw ApiException(
        message:
            'Daftar pengiriman dari server tidak dapat dibaca: $error',
      );
    }
  }

  Future<DriverDeliveryModel> getDeliveryDetail(
    int deliveryId,
  ) async {
    final response =
        await _remoteDataSource.getDeliveryDetail(
      deliveryId,
    );

    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message:
            'Detail pengiriman dari server tidak lengkap.',
      );
    }

    try {
      return DriverDeliveryModel.fromJson(data);
    } catch (error) {
      throw ApiException(
        message:
            'Detail pengiriman tidak dapat dibaca: $error',
      );
    }
  }

  Future<DriverDeliveryModel> updateDeliveryStatus({
    required int deliveryId,
    required String status,
    String? notes,
    String? proofImagePath,
  }) async {
    final allowedStatuses = <String>{
      'picked_up',
      'on_delivery',
      'delivered',
    };

    if (!allowedStatuses.contains(status)) {
      throw const ApiException(
        message:
            'Status pengiriman yang dipilih tidak valid.',
      );
    }

    final response =
        await _remoteDataSource.updateDeliveryStatus(
      deliveryId: deliveryId,
      status: status,
      notes: notes,
      proofImagePath: proofImagePath,
    );

    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message:
            'Status berhasil dikirim, tetapi respons server tidak lengkap.',
      );
    }

    try {
      return DriverDeliveryModel.fromJson(data);
    } catch (error) {
      throw ApiException(
        message:
            'Status pengiriman terbaru tidak dapat dibaca: $error',
      );
    }
  }
}
