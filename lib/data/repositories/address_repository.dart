import '../../core/network/api_exception.dart';
import '../datasources/address_remote_datasource.dart';
import '../models/address.dart';

class AddressRepository {
  AddressRepository({
    AddressRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource =
            remoteDataSource ?? AddressRemoteDataSource();

  final AddressRemoteDataSource _remoteDataSource;

  Future<List<AddressModel>> getAddresses() async {
    final response =
        await _remoteDataSource.getAddresses();

    try {
      final addresses = response.dataAsList
          .whereType<Map>()
          .map(
            (item) => AddressModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      addresses.sort((first, second) {
        if (first.isDefault != second.isDefault) {
          return first.isDefault ? -1 : 1;
        }

        return second.id.compareTo(first.id);
      });

      return addresses;
    } catch (error) {
      throw ApiException(
        message:
            'Data alamat dari server tidak dapat dibaca: $error',
      );
    }
  }

  Future<AddressModel> createAddress({
    required String label,
    required String recipientName,
    required String phone,
    required String fullAddress,
    String? province,
    String? city,
    String? district,
    String? postalCode,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final response =
        await _remoteDataSource.createAddress(
      label: label,
      recipientName: recipientName,
      phone: phone,
      fullAddress: fullAddress,
      province: province,
      city: city,
      district: district,
      postalCode: postalCode,
      latitude: latitude,
      longitude: longitude,
      isDefault: isDefault,
    );

    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message:
            'Alamat berhasil dikirim, tetapi respons server tidak lengkap.',
      );
    }

    try {
      return AddressModel.fromJson(data);
    } catch (error) {
      throw ApiException(
        message:
            'Alamat dari server tidak dapat dibaca: $error',
      );
    }
  }

  Future<AddressModel> updateAddress({
    required int addressId,
    required String label,
    required String recipientName,
    required String phone,
    required String fullAddress,
    String? province,
    String? city,
    String? district,
    String? postalCode,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final response =
        await _remoteDataSource.updateAddress(
      addressId: addressId,
      body: {
        'label': label.trim(),
        'recipient_name': recipientName.trim(),
        'phone': phone.trim(),
        'full_address': fullAddress.trim(),
        'province': _nullableText(province),
        'city': _nullableText(city),
        'district': _nullableText(district),
        'postal_code': _nullableText(postalCode),
        'latitude': latitude,
        'longitude': longitude,
        'is_default': isDefault,
      },
    );

    final data = response.dataAsMap;

    if (data == null) {
      throw const ApiException(
        message:
            'Alamat berhasil diperbarui, tetapi respons server tidak lengkap.',
      );
    }

    try {
      return AddressModel.fromJson(data);
    } catch (error) {
      throw ApiException(
        message:
            'Alamat terbaru dari server tidak dapat dibaca: $error',
      );
    }
  }

  Future<void> deleteAddress(int addressId) async {
    await _remoteDataSource.deleteAddress(addressId);
  }

  static String? _nullableText(String? value) {
    final text = value?.trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }
}
