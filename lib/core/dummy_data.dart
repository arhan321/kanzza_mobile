class DummyUser {
  final String name;
  final String email;
  final String password;
  final String role;

  const DummyUser({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
  });
}

class DummyData {
  static const List<DummyUser> users = [
    DummyUser(
      name: "Athar Customer",
      email: "customer@kanzza.com",
      password: "123456",
      role: "customer",   
    ),

    DummyUser(
      name: "Kasir Kanzza",
      email: "cashier@kanzza.com",
      password: "123456",
      role: "cashier",
    ),

    DummyUser(
      name: "Driver Kanzza",
      email: "driver@kanzza.com",
      password: "123456",
      role: "driver",
    ),

    DummyUser(
      name: "Owner Kanzza",
      email: "owner@kanzza.com",
      password: "123456",
      role: "owner",
    ),
  ];
}