// lib/routes.dart

import 'package:flutter/material.dart';
import 'package:kanzza_sales_app_fe/presentation/pages/auth/login_page.dart';
import 'package:kanzza_sales_app_fe/presentation/pages/auth/register_page.dart';
import 'package:kanzza_sales_app_fe/presentation/pages/cashier/cashier_dashboard_page.dart';
import 'package:kanzza_sales_app_fe/presentation/pages/cashier/cashier_products_page.dart';
import 'package:kanzza_sales_app_fe/presentation/pages/cashier/offline_transaction_page.dart';
import 'package:kanzza_sales_app_fe/presentation/pages/cashier/transaction_history_page.dart';
import 'package:kanzza_sales_app_fe/presentation/pages/cashier/manage_products_page.dart'; // TAMBAHKAN
import 'package:kanzza_sales_app_fe/presentation/pages/customer/customer_home_page.dart';
import 'package:kanzza_sales_app_fe/presentation/pages/driver/driver_dashboard_page.dart';
import 'package:kanzza_sales_app_fe/presentation/pages/owner/owner_dashboard_page.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String customerHome = '/customer-home';
  static const String cashierDashboard = '/cashier-dashboard';
  static const String cashierProducts = '/cashier-products';
  static const String cashierTransaction = '/cashier-transaction';
  static const String offlineTransaction = '/offline-transaction';
  static const String transactionHistory = '/transaction-history';
  static const String manageProducts = '/manage-products'; // TAMBAHKAN
  static const String driverDashboard = '/driver-dashboard';
  static const String ownerDashboard = '/owner-dashboard';

  static Map<String, WidgetBuilder> get routes {
    return {
      login: (context) => const LoginPage(),
      register: (context) => const RegisterPage(),
      customerHome: (context) => const CustomerHomePage(),
      cashierDashboard: (context) => const CashierDashboardPage(),
      cashierProducts: (context) => const CashierProductsPage(),

      offlineTransaction: (context) => const OfflineTransactionPage(),
      transactionHistory: (context) => const TransactionHistoryPage(),
      manageProducts: (context) => const ManageProductsPage(), // TAMBAHKAN
      driverDashboard: (context) => const DriverDashboardPage(),
      ownerDashboard: (context) => const OwnerDashboardPage(),
    };
  }
}
