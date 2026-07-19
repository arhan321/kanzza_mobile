class ApiEndpoints {
  ApiEndpoints._();

  // Health
  static const String health = '/health';

  // Authentication
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String profile = '/auth/me';

  // Catalog
  static const String categories = '/categories';
  static const String products = '/products';

  // Customer
  static const String addresses = '/addresses';
  static const String orders = '/orders';
  static const String notifications = '/notifications';
  static const String notificationUnreadCount = '/notifications/unread-count';
  static const String markAllNotificationsAsRead = '/notifications/read-all';

  // Cashier
  static const String cashierTransactions = '/cashier/transactions';
  static const String cashierProducts = '/cashier/products';

  // Driver
  static const String driverDeliveries = '/driver/deliveries';

  // Owner
  static const String ownerDashboard = '/owner/dashboard';
  static const String ownerUsers = '/owner/users';
  static const String ownerCategories = '/owner/categories';
  static const String ownerProducts = '/owner/products';

  static String categoryDetail(int categoryId) {
    return '/categories/$categoryId';
  }

  static String productDetail(int productId) {
    return '/products/$productId';
  }

  static String addressDetail(int addressId) {
    return '/addresses/$addressId';
  }

  static String orderDetail(int orderId) {
    return '/orders/$orderId';
  }

  static String orderPayment(int orderId) {
    return '/orders/$orderId/payment';
  }

  static String checkOrderPayment(int orderId) {
    return '/orders/$orderId/payment/check';
  }

  static String cancelOrder(int orderId) {
    return '/orders/$orderId/cancel';
  }

  static String markNotificationAsRead(int notificationId) {
    return '/notifications/$notificationId/read';
  }

  static String updateOrderStatus(int orderId) {
    return '/orders/$orderId/status';
  }

  static String assignDriver(int orderId) {
    return '/orders/$orderId/assign-driver';
  }

  static String cashierTransactionDetail(int transactionId) {
    return '/cashier/transactions/$transactionId';
  }

  static String cashierProductDetail(int productId) {
    return '/cashier/products/$productId';
  }

  static String driverDeliveryDetail(int deliveryId) {
    return '/driver/deliveries/$deliveryId';
  }

  static String updateDriverDeliveryStatus(int deliveryId) {
    return '/driver/deliveries/$deliveryId/status';
  }

  static String ownerCategoryDetail(int categoryId) {
    return '/owner/categories/$categoryId';
  }

  static String ownerProductDetail(int productId) {
    return '/owner/products/$productId';
  }

  static String ownerUserRole(int userId) {
    return '/owner/users/$userId/role';
  }

  static String ownerUserStatus(int userId) {
    return '/owner/users/$userId/status';
  }
}
