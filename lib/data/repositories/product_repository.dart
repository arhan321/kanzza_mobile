import '../../core/network/api_exception.dart';
import '../datasources/product_remote_datasource.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/owner_product_input.dart';

class ProductRepository {
  ProductRepository({ProductRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? ProductRemoteDataSource();

  final ProductRemoteDataSource _remoteDataSource;

  Future<List<CategoryModel>> getCategories({bool activeOnly = true}) async {
    final response = await _remoteDataSource.getCategories();

    try {
      return response.dataAsList
          .whereType<Map>()
          .map(
            (item) => CategoryModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((category) => !activeOnly || category.isActive)
          .toList();
    } catch (error) {
      throw ApiException(
        message: 'Data kategori dari server tidak dapat dibaca: $error',
      );
    }
  }

  Future<List<ProductModel>> getProducts({
    String? search,
    int? categoryId,
    bool? isActive = true,
    bool lowStock = false,
    int perPage = 100,
  }) async {
    final response = await _remoteDataSource.getProducts(
      search: search,
      categoryId: categoryId,
      isActive: isActive,
      lowStock: lowStock,
      perPage: perPage,
    );

    try {
      return response.dataAsList
          .whereType<Map>()
          .map((item) => ProductModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (error) {
      throw ApiException(
        message: 'Data produk dari server tidak dapat dibaca: $error',
      );
    }
  }

  Future<ProductModel> getProductDetail(int productId) async {
    final response = await _remoteDataSource.getProductDetail(productId);
    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message: 'Detail produk dari server tidak lengkap.',
      );
    }

    try {
      return ProductModel.fromJson(data);
    } catch (error) {
      throw ApiException(message: 'Detail produk tidak dapat dibaca: $error');
    }
  }

  Future<ProductModel> createOwnerProduct(OwnerProductInput input) async {
    final response = await _remoteDataSource.createOwnerProduct(
      fields: input.toMultipartFields(),
      imagePath: input.imagePath,
    );
    return _parseProduct(response.dataAsMap, 'Produk baru');
  }

  Future<ProductModel> updateOwnerProduct({
    required int productId,
    required OwnerProductInput input,
  }) async {
    final response = await _remoteDataSource.updateOwnerProduct(
      productId: productId,
      fields: input.toMultipartFields(),
      imagePath: input.imagePath,
    );
    return _parseProduct(response.dataAsMap, 'Produk yang diperbarui');
  }

  Future<void> deleteOwnerProduct(int productId) async {
    await _remoteDataSource.deleteOwnerProduct(productId);
  }

  Future<CategoryModel> createOwnerCategory({
    required String name,
    String? description,
    bool isActive = true,
  }) async {
    final response = await _remoteDataSource.createOwnerCategory(
      name: name,
      description: description,
      isActive: isActive,
    );
    return _parseCategory(response.dataAsMap, 'Kategori baru');
  }

  Future<CategoryModel> updateOwnerCategory({
    required int categoryId,
    required String name,
    String? description,
    required bool isActive,
  }) async {
    final response = await _remoteDataSource.updateOwnerCategory(
      categoryId: categoryId,
      name: name,
      description: description,
      isActive: isActive,
    );
    return _parseCategory(response.dataAsMap, 'Kategori yang diperbarui');
  }

  Future<void> deleteOwnerCategory(int categoryId) async {
    await _remoteDataSource.deleteOwnerCategory(categoryId);
  }

  ProductModel _parseProduct(Map<String, dynamic>? data, String label) {
    if (data == null) {
      throw ApiException(message: '$label dari server tidak lengkap.');
    }
    try {
      return ProductModel.fromJson(data);
    } catch (error) {
      throw ApiException(message: '$label tidak dapat dibaca: $error');
    }
  }

  CategoryModel _parseCategory(Map<String, dynamic>? data, String label) {
    if (data == null) {
      throw ApiException(message: '$label dari server tidak lengkap.');
    }
    try {
      return CategoryModel.fromJson(data);
    } catch (error) {
      throw ApiException(message: '$label tidak dapat dibaca: $error');
    }
  }
}
