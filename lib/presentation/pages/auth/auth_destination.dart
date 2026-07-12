import 'package:flutter/material.dart';

import '../../../data/models/user.dart';
import '../cashier/cashier_dashboard_page.dart';
import '../customer/customer_home_page.dart';
import '../driver/driver_dashboard_page.dart';
import '../owner/owner_dashboard_page.dart';

Widget? destinationForUser(UserModel user) {
  switch (user.role.trim().toLowerCase()) {
    case 'customer':
      return const CustomerHomePage();

    case 'cashier':
      return const CashierDashboardPage();

    case 'driver':
      return const DriverDashboardPage();

    case 'owner':
      return const OwnerDashboardPage();

    default:
      return null;
  }
}
