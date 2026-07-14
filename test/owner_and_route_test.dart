import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kanzza_sales_app_fe/core/config/app_config.dart';
import 'package:kanzza_sales_app_fe/core/constants/api_endpoints.dart';
import 'package:kanzza_sales_app_fe/core/location/road_route_service.dart';
import 'package:kanzza_sales_app_fe/core/network/api_response.dart';
import 'package:kanzza_sales_app_fe/data/datasources/customer_order_remote_datasource.dart';
import 'package:kanzza_sales_app_fe/data/models/customer_order.dart';
import 'package:kanzza_sales_app_fe/data/models/owner_dashboard.dart';
import 'package:kanzza_sales_app_fe/data/models/owner_product_input.dart';
import 'package:kanzza_sales_app_fe/data/repositories/customer_order_repository.dart';

void main() {
  group('Owner API models', () {
    test('parses dashboard response from Laravel', () {
      final dashboard = OwnerDashboardModel.fromJson({
        'today_revenue': '125000',
        'today_transactions': 4,
        'pending_orders': 2,
        'low_stock_products': 1,
        'active_customers': 9,
        'top_products': [
          {
            'product_id': 7,
            'product_name': 'Nugget Ayam',
            'total_quantity': '6',
            'total_sales': '180000',
          },
        ],
      });

      expect(dashboard.todayRevenue, 125000);
      expect(dashboard.todayTransactions, 4);
      expect(dashboard.topProducts, hasLength(1));
      expect(dashboard.topProducts.single.name, 'Nugget Ayam');
      expect(dashboard.topProducts.single.totalSales, 180000);
    });

    test('serializes owner product fields using backend contract', () {
      const input = OwnerProductInput(
        categoryId: 3,
        sku: ' FRZ-01 ',
        name: ' Sosis Sapi ',
        description: ' Frozen ',
        costPrice: 20000,
        sellingPrice: 25000,
        stock: 12,
        minimumStock: 3,
        unit: ' pcs ',
        isActive: true,
      );

      expect(input.toMultipartFields(), {
        'category_id': 3,
        'sku': 'FRZ-01',
        'name': 'Sosis Sapi',
        'description': 'Frozen',
        'cost_price': 20000,
        'selling_price': 25000,
        'stock': 12,
        'minimum_stock': 3,
        'unit': 'pcs',
        'is_active': true,
      });
    });

    test('COD is enabled for the current backend contract', () {
      expect(AppConfig.customerCodEnabled, isTrue);
    });

    test('parses customer and cashier embedded in an order response', () {
      final order = CustomerOrderModel.fromJson({
        'id': 12,
        'order_number': 'ORD-12',
        'channel': 'online',
        'order_status': 'confirmed',
        'payment_status': 'paid',
        'delivery_method': 'delivery',
        'payment_method': 'midtrans',
        'grand_total': 85000,
        'customer': {
          'id': 4,
          'name': 'Customer Kanzza',
          'email': 'customer@example.com',
          'role': 'customer',
          'status': 'active',
        },
        'cashier': null,
        'items': [
          {'id': 1, 'product_id': 2, 'quantity': 3},
        ],
      });

      expect(order.customer?.name, 'Customer Kanzza');
      expect(order.cashier, isNull);
      expect(order.totalQuantity, 3);
    });

    test('distinguishes COD actions from Midtrans payment actions', () {
      final codOrder = CustomerOrderModel.fromJson({
        'id': 21,
        'order_number': 'ORD-COD-21',
        'channel': 'online',
        'order_status': 'confirmed',
        'payment_status': 'unpaid',
        'delivery_method': 'delivery',
        'payment_method': 'cash',
        'items': const [],
      });

      expect(codOrder.isCod, isTrue);
      expect(codOrder.canCustomerPayOnline, isFalse);
      expect(codOrder.canCustomerCancel, isTrue);
      expect(ApiEndpoints.updateOrderStatus(21), '/orders/21/status');
      expect(ApiEndpoints.assignDriver(21), '/orders/21/assign-driver');
    });

    test('parses status update and driver assignment responses', () async {
      final remote = _FakeCustomerOrderRemoteDataSource();
      final repository = CustomerOrderRepository(remoteDataSource: remote);

      final updated = await repository.updateOrderStatus(
        orderId: 21,
        status: 'processing',
      );
      final delivery = await repository.assignDriver(orderId: 21, driverId: 3);

      expect(remote.updatedOrderId, 21);
      expect(remote.updatedStatus, 'processing');
      expect(updated.orderStatus, 'processing');
      expect(remote.assignedDriverId, 3);
      expect(delivery.orderId, 21);
      expect(delivery.driver?.isDriver, isTrue);
    });
  });

  group('RoadRouteService', () {
    test('parses OSRM driving distance and points', () async {
      final service = RoadRouteService(
        client: MockClient((request) async {
          expect(request.url.host, 'router.project-osrm.org');
          return http.Response(
            '{"routes":[{"distance":3320.5,"geometry":{"coordinates":'
            '[[106.55,-6.28],[106.56,-6.27]]}}]}',
            200,
          );
        }),
      );

      final route = await service.getDrivingRoute(
        startLatitude: -6.28,
        startLongitude: 106.55,
        endLatitude: -6.27,
        endLongitude: 106.56,
      );

      expect(route.distanceKm, closeTo(3.3205, 0.00001));
      expect(route.points, hasLength(2));
      expect(route.points.last.latitude, -6.27);
      service.close();
    });

    test('rejects an OSRM response without a usable route', () async {
      final service = RoadRouteService(
        client: MockClient((_) async => http.Response('{"routes":[]}', 200)),
      );

      expect(
        () => service.getDrivingRoute(
          startLatitude: -6.28,
          startLongitude: 106.55,
          endLatitude: -6.27,
          endLongitude: 106.56,
        ),
        throwsA(isA<RoadRouteException>()),
      );
      service.close();
    });
  });
}

class _FakeCustomerOrderRemoteDataSource extends CustomerOrderRemoteDataSource {
  int? updatedOrderId;
  String? updatedStatus;
  int? assignedDriverId;

  @override
  Future<ApiResponse> updateOrderStatus({
    required int orderId,
    required String status,
  }) async {
    updatedOrderId = orderId;
    updatedStatus = status;
    return ApiResponse(
      success: true,
      message: 'Status diperbarui.',
      statusCode: 200,
      data: {
        'id': orderId,
        'order_number': 'ORD-$orderId',
        'order_status': status,
        'payment_status': 'unpaid',
        'delivery_method': 'delivery',
        'payment_method': 'cash',
        'items': const [],
      },
    );
  }

  @override
  Future<ApiResponse> assignDriver({
    required int orderId,
    required int driverId,
  }) async {
    assignedDriverId = driverId;
    return ApiResponse(
      success: true,
      message: 'Driver ditugaskan.',
      statusCode: 200,
      data: {
        'id': 9,
        'order_id': orderId,
        'status': 'assigned',
        'driver': {
          'id': driverId,
          'name': 'Driver Kanzza',
          'email': 'driver@kanzza.com',
          'role': 'driver',
          'status': 'active',
        },
      },
    );
  }
}
