import '../../core/network/api_exception.dart';
import '../datasources/customer_order_remote_datasource.dart';
import '../models/customer_order.dart';

class CustomerOrderRepository {
  CustomerOrderRepository({CustomerOrderRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? CustomerOrderRemoteDataSource();

  final CustomerOrderRemoteDataSource _remoteDataSource;

  Future<List<CustomerOrderModel>> getOrders({
    String? orderStatus,
    String? paymentStatus,
    String? search,
    int perPage = 100,
  }) async {
    final response = await _remoteDataSource.getOrders(
      orderStatus: orderStatus,
      paymentStatus: paymentStatus,
      search: search,
      perPage: perPage,
    );

    try {
      final orders = response.dataAsList
          .whereType<Map>()
          .map(
            (item) =>
                CustomerOrderModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();

      orders.sort(
        (first, second) => _orderDate(second).compareTo(_orderDate(first)),
      );

      return orders;
    } catch (error) {
      throw ApiException(
        message: 'Daftar pesanan dari server tidak dapat dibaca: $error',
      );
    }
  }

  Future<CustomerOrderModel> createOrder({
    required String deliveryMethod,
    required String paymentMethod,
    double? distanceKm,
    int? shippingCost,
    int? addressId,
    required List<Map<String, int>> items,
    String? notes,
  }) async {
    final response = await _remoteDataSource.createOrder(
      deliveryMethod: deliveryMethod,
      paymentMethod: paymentMethod,
      distanceKm: distanceKm,
      shippingCost: shippingCost,
      addressId: addressId,
      items: items,
      notes: notes,
    );

    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message:
            'Pesanan berhasil dikirim, tetapi respons server tidak lengkap.',
      );
    }

    try {
      return CustomerOrderModel.fromJson(data);
    } catch (error) {
      throw ApiException(
        message: 'Data pesanan dari server tidak dapat dibaca: $error',
      );
    }
  }

  Future<CustomerOrderModel> getOrderDetail(int orderId) async {
    final response = await _remoteDataSource.getOrderDetail(orderId);
    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message: 'Detail pesanan dari server tidak lengkap.',
      );
    }

    try {
      return CustomerOrderModel.fromJson(data);
    } catch (error) {
      throw ApiException(message: 'Detail pesanan tidak dapat dibaca: $error');
    }
  }

  Future<CustomerOrderModel> cancelOrder(int orderId) async {
    final response = await _remoteDataSource.cancelOrder(orderId);
    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message: 'Pesanan dibatalkan, tetapi respons server tidak lengkap.',
      );
    }

    try {
      return CustomerOrderModel.fromJson(data);
    } catch (error) {
      throw ApiException(
        message: 'Data pembatalan pesanan tidak dapat dibaca: $error',
      );
    }
  }

  Future<PaymentModel> createOrReusePayment(int orderId) async {
    final response = await _remoteDataSource.createOrReusePayment(orderId);

    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message: 'Data pembayaran dari server tidak lengkap.',
      );
    }

    try {
      return PaymentModel.fromJson(data);
    } catch (error) {
      throw ApiException(message: 'Data pembayaran tidak dapat dibaca: $error');
    }
  }

  Future<PaymentStatusResult> checkPaymentStatus(int orderId) async {
    final response = await _remoteDataSource.checkPaymentStatus(orderId);

    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message: 'Status pembayaran dari server tidak lengkap.',
      );
    }

    final rawPayment = data['payment'];

    if (rawPayment is! Map) {
      throw const ApiException(
        message: 'Data pembayaran tidak ditemukan pada respons server.',
      );
    }

    try {
      return PaymentStatusResult(
        payment: PaymentModel.fromJson(Map<String, dynamic>.from(rawPayment)),
        midtransStatus: data['midtrans_status']?.toString(),
        statusChanged: _parseBool(data['status_changed']),
        orderPaymentStatus:
            data['order_payment_status']?.toString().trim().toLowerCase() ??
            'unpaid',
        orderStatus:
            data['order_status']?.toString().trim().toLowerCase() ??
            'pending_payment',
        message: response.message,
      );
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }

      throw ApiException(
        message: 'Status pembayaran tidak dapat dibaca: $error',
      );
    }
  }

  static DateTime _orderDate(CustomerOrderModel order) {
    return order.createdAt ??
        order.updatedAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value.toInt() == 1;
    }

    final text = value?.toString().trim().toLowerCase();

    return text == 'true' || text == '1';
  }
}
