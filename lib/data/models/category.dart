class CategoryModel {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.isActive,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: _parseNullableString(json['description']),
      isActive: _parseBool(json['is_active'], fallback: true),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _parseBool(
    dynamic value, {
    required bool fallback,
  }) {
    if (value is bool) {
      return value;
    }

    if (value is int) {
      return value == 1;
    }

    final text = value?.toString().trim().toLowerCase();

    if (text == 'true' || text == '1') {
      return true;
    }

    if (text == 'false' || text == '0') {
      return false;
    }

    return fallback;
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
    return 'CategoryModel(id: $id, name: $name, slug: $slug)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CategoryModel &&
            runtimeType == other.runtimeType &&
            id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
