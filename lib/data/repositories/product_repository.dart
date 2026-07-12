import '../../core/network/api_exception.dart';
import '../datasources/product_remote_datasource.dart';
import '../models/category.dart';
import '../models/product.dart';

class ProductRepository {
  ProductRepository({
    ProductRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource =
            remoteDataSource ?? ProductRemoteDataSource();

  final ProductRemoteDataSource _remoteDataSource;

  Future<List<CategoryModel>> getCategories() async {
    final response = await _remoteDataSource.getCategories();

    try {
      return response.dataAsList
          .whereType<Map>()
          .map(
            (item) => CategoryModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((category) => category.isActive)
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
    bool isActive = true,
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
          .map(
            (item) => ProductModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (error) {
      throw ApiException(
        message: 'Data produk dari server tidak dapat dibaca: $error',
      );
    }
  }

  Future<ProductModel> getProductDetail(int productId) async {
    final response =
        await _remoteDataSource.getProductDetail(productId);
    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message: 'Detail produk dari server tidak lengkap.',
      );
    }

    try {
      return ProductModel.fromJson(data);
    } catch (error) {
      throw ApiException(
        message: 'Detail produk tidak dapat dibaca: $error',
      );
    }
  }
}
