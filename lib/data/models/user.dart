class UserModel {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String status;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.phone,
    this.lastLoginAt,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: _parseNullableString(json['phone']),
      role: json['role']?.toString().trim().toLowerCase() ?? 'customer',
      status: json['status']?.toString().trim().toLowerCase() ?? 'active',
      lastLoginAt: _parseDateTime(json['last_login_at']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'status': status,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    bool clearPhone = false,
    String? role,
    String? status,
    DateTime? lastLoginAt,
    bool clearLastLoginAt = false,
    DateTime? createdAt,
    bool clearCreatedAt = false,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: clearPhone ? null : (phone ?? this.phone),
      role: role ?? this.role,
      status: status ?? this.status,
      lastLoginAt: clearLastLoginAt ? null : (lastLoginAt ?? this.lastLoginAt),
      createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
    );
  }

  bool get isActive => status == 'active';

  bool get isCustomer => role == 'customer';

  bool get isCashier => role == 'cashier';

  bool get isDriver => role == 'driver';

  bool get isOwner => role == 'owner';

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _parseNullableString(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }

    return text;
  }

  static DateTime? _parseDateTime(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  @override
  String toString() {
    return 'UserModel('
        'id: $id, '
        'name: $name, '
        'email: $email, '
        'phone: $phone, '
        'role: $role, '
        'status: $status'
        ')';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UserModel &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            email == other.email;
  }

  @override
  int get hashCode => Object.hash(id, email);
}
