import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kanzza_sales_app_fe/core/config/app_config.dart';
import 'package:kanzza_sales_app_fe/core/location/road_route_service.dart';
import 'package:kanzza_sales_app_fe/data/models/owner_dashboard.dart';
import 'package:kanzza_sales_app_fe/data/models/owner_product_input.dart';
import 'package:kanzza_sales_app_fe/data/models/customer_order.dart';

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

    test('COD remains disabled until backend explicitly supports it', () {
      expect(AppConfig.customerCodEnabled, isFalse);
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
