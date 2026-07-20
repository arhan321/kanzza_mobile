import 'package:flutter/material.dart';

import '../cashier/cashier_products_page.dart';

class OwnerProductsPage extends StatelessWidget {
  const OwnerProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CashierProductsPage(mode: ProductManagementMode.owner);
  }
}
