// lib/presentation/pages/customer/customer_checkout_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/delivery_route_preview.dart';
import '../../../core/widgets/location_picker_card.dart';
import '../../../core/location/location_service.dart';
import '../../../core/location/road_route_service.dart';
import '../../../core/location/store_location.dart';
import '../../../data/models/address.dart';
import '../../../data/models/cart_item.dart';
import '../../../data/models/customer_order.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/address_repository.dart';
import '../../../data/repositories/customer_order_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../routes.dart';
import '../../providers/customer_notification_provider.dart';
import 'midtrans_payment_page.dart';

class CustomerCheckoutPage extends StatefulWidget {
  final int totalPrice;
  final List<CartItem> cartItems;

  const CustomerCheckoutPage({
    super.key,
    this.totalPrice = 0,
    this.cartItems = const [],
  });

  @override
  State<CustomerCheckoutPage> createState() => _CustomerCheckoutPageState();
}

class _CustomerCheckoutPageState extends State<CustomerCheckoutPage> {
  static const int _shippingRatePerKm = 5000;
  static const String _adminWhatsAppNumber = '6289652731947';
  static const String _adminWhatsAppMessage =
      'Min, saya mau order tapi ada masalah nih...';

  final AddressRepository _addressRepository = AddressRepository();
  final CustomerOrderRepository _orderRepository = CustomerOrderRepository();
  final UserRepository _userRepository = UserRepository();

  final TextEditingController _notesController = TextEditingController();

  final List<AddressModel> _addresses = [];

  UserModel? _currentUser;
  int? _selectedAddressId;
  String _deliveryMethod = 'delivery';
  String _paymentMethod = 'midtrans';
  bool _showDeliveryRoute = false;
  int _routeCheckRevision = 0;
  bool _isCheckingLocation = false;
  double? _checkedLocationAccuracy;
  double? _routeDistanceKm;

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSubmitting = false;
  bool _orderHasBeenCreated = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCheckoutData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp() async {
    final encodedMessage = Uri.encodeComponent(_adminWhatsAppMessage);
    final whatsappUri = Uri.parse(
      'https://wa.me/$_adminWhatsAppNumber?text=$encodedMessage',
    );

    try {
      final opened = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        _showSnackBar(
          'WhatsApp tidak dapat dibuka pada perangkat ini.',
          Colors.orange.shade500,
        );
      }
    } catch (error) {
      debugPrint('OPEN WHATSAPP ERROR: $error');

      if (!mounted) {
        return;
      }

      _showSnackBar(
        'WhatsApp tidak dapat dibuka. Silakan coba kembali.',
        Colors.orange.shade500,
      );
    }
  }

  int get _cartSubtotal {
    return widget.cartItems.fold<int>(
      0,
      (total, item) => total + item.subtotal,
    );
  }

  int get _totalQuantity {
    return widget.cartItems.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );
  }

  int get _shippingCost {
    if (_deliveryMethod == 'pickup') {
      return 0;
    }

    final distanceKm = _effectiveDistanceKm;
    return distanceKm == null ? 0 : (distanceKm * _shippingRatePerKm).round();
  }

  int get _checkoutTotal => _cartSubtotal + _shippingCost;

  double? get _effectiveDistanceKm => _routeDistanceKm;

  AddressModel? get _selectedAddress {
    if (_selectedAddressId == null) {
      return null;
    }

    for (final address in _addresses) {
      if (address.id == _selectedAddressId) {
        return address;
      }
    }

    return null;
  }

  Future<void> _loadCheckoutData({bool isRefresh = false}) async {
    if (mounted) {
      setState(() {
        if (isRefresh) {
          _isRefreshing = true;
        } else {
          _isLoading = true;
        }

        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        _userRepository.getProfile(),
        _addressRepository.getAddresses(),
      ]);

      final user = results[0] as UserModel;
      final addresses = results[1] as List<AddressModel>;

      if (!mounted) {
        return;
      }

      int? nextAddressId = _selectedAddressId;

      if (nextAddressId == null ||
          !addresses.any((address) => address.id == nextAddressId)) {
        if (addresses.isNotEmpty) {
          nextAddressId = addresses
              .firstWhere(
                (address) => address.isDefault,
                orElse: () => addresses.first,
              )
              .id;
        } else {
          nextAddressId = null;
        }
      }

      setState(() {
        _currentUser = user;
        _addresses
          ..clear()
          ..addAll(addresses);
        _selectedAddressId = nextAddressId;
        _showDeliveryRoute = false;
        _checkedLocationAccuracy = null;
        _routeDistanceKm = null;
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
        return;
      }

      _handleLoadError(error.firstValidationError);
    } catch (error) {
      debugPrint('LOAD CUSTOMER CHECKOUT ERROR: $error');

      _handleLoadError('Data checkout gagal dimuat. Silakan coba kembali.');
    }
  }

  void _handleLoadError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _isRefreshing = false;
      _errorMessage = message;
    });
  }

  Future<void> _handleUnauthorized() async {
    await _userRepository.clearLocalSession();

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Future<void> _refresh() async {
    if (_isRefreshing) {
      return;
    }

    await _loadCheckoutData(isRefresh: true);
  }

  Future<void> _checkCurrentDeviceLocation() async {
    final address = _selectedAddress;

    if (address == null || _isCheckingLocation || _isSubmitting) {
      return;
    }

    setState(() {
      _isCheckingLocation = true;
      _showDeliveryRoute = false;
      _checkedLocationAccuracy = null;
      _routeDistanceKm = null;
    });

    try {
      final detectedLocation = await const LocationService()
          .detectFreshCurrentLocation();

      final updatedAddress = await _addressRepository.updateAddress(
        addressId: address.id,
        label: address.label,
        recipientName: address.recipientName,
        phone: address.phone,
        fullAddress: detectedLocation.fullAddress,
        province: detectedLocation.province ?? address.province,
        city: detectedLocation.city ?? address.city,
        district: detectedLocation.district ?? address.district,
        postalCode: detectedLocation.postalCode ?? address.postalCode,
        latitude: detectedLocation.latitude,
        longitude: detectedLocation.longitude,
        isDefault: address.isDefault,
      );

      if (!mounted) {
        return;
      }

      final index = _addresses.indexWhere((item) => item.id == address.id);

      setState(() {
        if (index >= 0) {
          _addresses[index] = updatedAddress;
        }
        _checkedLocationAccuracy = detectedLocation.accuracy;
        _showDeliveryRoute = true;
        _routeCheckRevision++;
      });

      _showSnackBar(
        'Lokasi GPS terbaru berhasil diambil dengan akurasi '
        '±${detectedLocation.accuracy.round()} meter.',
        Colors.green.shade600,
      );
    } on LocationFailure catch (error) {
      if (mounted) {
        _showSnackBar(error.message, Colors.orange.shade600);
      }
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
        return;
      }

      if (mounted) {
        _showSnackBar(error.firstValidationError, Colors.red.shade400);
      }
    } catch (error) {
      debugPrint('CHECK CURRENT DEVICE LOCATION ERROR: $error');

      if (mounted) {
        _showSnackBar(
          'Lokasi terbaru gagal diperiksa. Silakan coba kembali.',
          Colors.red.shade400,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingLocation = false;
        });
      }
    }
  }

  Future<void> _showAddAddressSheet() async {
    final result = await showModalBottomSheet<_AddressFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return _AddAddressSheet(
          initialName: _currentUser?.name ?? '',
          initialPhone: _currentUser?.phone ?? '',
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    await _createAddress(result);
  }

  Future<void> _createAddress(_AddressFormResult form) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final address = await _addressRepository.createAddress(
        label: form.label,
        recipientName: form.recipientName,
        phone: form.phone,
        fullAddress: form.fullAddress,
        province: form.province,
        city: form.city,
        district: form.district,
        postalCode: form.postalCode,
        latitude: form.latitude,
        longitude: form.longitude,
        isDefault: form.isDefault,
      );

      if (!mounted) {
        return;
      }

      await _loadCheckoutData(isRefresh: true);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedAddressId = address.id;
      });

      _showSnackBar('Alamat berhasil disimpan.', Colors.green.shade500);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
        return;
      }

      if (!mounted) {
        return;
      }

      _showSnackBar(error.firstValidationError, Colors.red.shade400);
    } catch (error) {
      debugPrint('CREATE ADDRESS ERROR: $error');

      if (!mounted) {
        return;
      }

      _showSnackBar('Alamat gagal disimpan.', Colors.red.shade400);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _confirmAndCreateOrder() async {
    FocusScope.of(context).unfocus();

    if (_isSubmitting) {
      return;
    }

    if (widget.cartItems.isEmpty) {
      _showSnackBar('Keranjang belanja masih kosong.', Colors.orange.shade500);
      return;
    }

    final invalidItem = widget.cartItems.any(
      (item) => !item.isAvailable || item.quantityExceedsStock,
    );

    if (invalidItem) {
      _showSnackBar(
        'Terdapat produk yang tidak tersedia atau '
        'jumlahnya melebihi stok.',
        Colors.red.shade400,
      );
      return;
    }

    if (_paymentMethod == 'cash' && _deliveryMethod != 'delivery') {
      _showSnackBar(
        'COD hanya tersedia untuk pesanan yang diantar ke alamat.',
        Colors.orange.shade500,
      );
      return;
    }

    if (_deliveryMethod == 'delivery' && _selectedAddressId == null) {
      _showSnackBar(
        'Pilih atau tambahkan alamat pengiriman.',
        Colors.orange.shade500,
      );
      return;
    }

    if (_deliveryMethod == 'delivery' && !await _ensureRoadRoute()) {
      return;
    }

    final confirmed = await _showOrderConfirmation();

    if (confirmed != true || !mounted) {
      return;
    }

    await _createOrderAndPayment();
  }

  Future<bool> _ensureRoadRoute() async {
    if (_routeDistanceKm != null) return true;

    final address = _selectedAddress;
    final latitude = address?.latitude;
    final longitude = address?.longitude;

    if (latitude == null || longitude == null) {
      _showSnackBar(
        'Alamat belum memiliki koordinat GPS. Perbarui lokasi alamat dahulu.',
        Colors.orange.shade600,
      );
      return false;
    }

    setState(() => _isSubmitting = true);
    final routeService = RoadRouteService();

    try {
      final route = await routeService.getDrivingRoute(
        startLatitude: StoreLocation.latitude,
        startLongitude: StoreLocation.longitude,
        endLatitude: latitude,
        endLongitude: longitude,
      );

      if (!mounted) return false;
      setState(() {
        _routeDistanceKm = route.distanceKm;
        _showDeliveryRoute = true;
        _routeCheckRevision++;
      });
      return true;
    } on RoadRouteException catch (error) {
      if (mounted) {
        _showSnackBar(error.message, Colors.orange.shade600);
      }
      return false;
    } finally {
      routeService.close();
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool?> _showOrderConfirmation() {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
            ),
          ),
          title: Text(
            'Konfirmasi Pesanan',
            style: GoogleFonts.poppins(
              color: theme.textTheme.titleLarge?.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildConfirmationRow(
                  label: 'Jumlah item',
                  value: '$_totalQuantity item',
                ),
                _buildConfirmationRow(
                  label: 'Subtotal estimasi',
                  value: 'Rp ${_formatPrice(_cartSubtotal)}',
                ),
                _buildConfirmationRow(
                  label: 'Ongkos kirim',
                  value: 'Rp ${_formatPrice(_shippingCost)}',
                ),
                _buildConfirmationRow(
                  label: 'Total pembayaran',
                  value: 'Rp ${_formatPrice(_checkoutTotal)}',
                ),
                _buildConfirmationRow(
                  label: 'Pengiriman',
                  value: _deliveryMethod == 'delivery'
                      ? 'Diantar ke alamat'
                      : 'Ambil di toko',
                ),
                if (_deliveryMethod == 'delivery')
                  _buildConfirmationRow(
                    label: 'Alamat',
                    value: _selectedAddress?.label ?? '-',
                  ),
                _buildConfirmationRow(
                  label: 'Pembayaran',
                  value: _paymentMethod == 'cash'
                      ? 'Bayar di Tempat (COD)'
                      : 'Pembayaran Online (Midtrans)',
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B5EFF).withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    _deliveryMethod == 'pickup'
                        ? 'Tidak ada ongkos kirim untuk pengambilan di toko.'
                        : 'Ongkos kirim dihitung dari jarak rute toko dengan tarif Rp5.000/km.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7132F5),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                'Batal',
                style: GoogleFonts.inter(
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B5EFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Buat Pesanan'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConfirmationRow({required String label, required String value}) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                color: theme.textTheme.titleLarge?.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createOrderAndPayment() async {
    setState(() {
      _isSubmitting = true;
      _orderHasBeenCreated = false;
    });

    CustomerOrderModel? createdOrder;

    try {
      createdOrder = await _orderRepository.createOrder(
        deliveryMethod: _deliveryMethod,
        paymentMethod: _paymentMethod,
        distanceKm: _deliveryMethod == 'delivery' ? _effectiveDistanceKm : null,
        shippingCost: _shippingCost,
        addressId: _deliveryMethod == 'delivery' ? _selectedAddressId : null,
        items: widget.cartItems
            .map(
              (item) => <String, int>{
                'product_id': item.id,
                'quantity': item.quantity,
              },
            )
            .toList(),
        notes: _notesController.text.trim(),
      );

      _orderHasBeenCreated = true;

      if (!mounted) {
        return;
      }

      _refreshNotificationBadge();

      if (_deliveryMethod == 'delivery' &&
          createdOrder.shippingCost != _shippingCost) {
        await _orderRepository.cancelOrder(createdOrder.id);

        if (!mounted) {
          return;
        }

        _orderHasBeenCreated = false;
        _showSnackBar(
          'Perhitungan ongkos kirim backend belum sesuai Rp5.000/km. '
          'Pesanan dibatalkan otomatis agar total pembayaran tidak salah.',
          Colors.orange.shade600,
        );
        return;
      }

      if (_paymentMethod == 'cash') {
        if (createdOrder.paymentMethod?.toLowerCase() != 'cash') {
          await _orderRepository.cancelOrder(createdOrder.id);

          if (!mounted) {
            return;
          }

          _orderHasBeenCreated = false;
          _showSnackBar(
            'COD belum diaktifkan oleh backend. Pesanan dibatalkan otomatis agar stok tidak tertahan.',
            Colors.orange.shade600,
          );
          return;
        }

        await _showCodOrderCreated(createdOrder);
        return;
      }

      final payment = await _orderRepository.createOrReusePayment(
        createdOrder.id,
      );

      if (!mounted) {
        return;
      }

      if (!payment.canOpenPayment) {
        await _showOrderCreatedWithoutPayment(
          createdOrder,
          'Pesanan sudah dibuat, tetapi halaman '
          'pembayaran belum tersedia.',
        );
        return;
      }

      final shouldCheckPayment = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MidtransPaymentPage(
            redirectUrl: payment.redirectUrl!,
            orderNumber: createdOrder!.orderNumber,
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      if (shouldCheckPayment != true) {
        await _showOrderCreatedWithoutPayment(
          createdOrder,
          'Pembayaran belum diselesaikan. Anda dapat melanjutkan pembayaran '
              'dari halaman pesanan.',
        );
        return;
      }

      await _checkPaymentAndShowResult(createdOrder);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
        return;
      }

      if (!mounted) {
        return;
      }

      if (_orderHasBeenCreated && createdOrder != null) {
        await _showOrderCreatedWithoutPayment(
          createdOrder,
          'Pesanan sudah dibuat, tetapi pembayaran '
          'belum dapat dibuka. ${error.firstValidationError}',
        );
        return;
      }

      _showSnackBar(error.firstValidationError, Colors.red.shade400);
    } catch (error) {
      debugPrint('CREATE CUSTOMER ORDER ERROR: $error');

      if (!mounted) {
        return;
      }

      if (_orderHasBeenCreated && createdOrder != null) {
        await _showOrderCreatedWithoutPayment(
          createdOrder,
          'Pesanan sudah dibuat, tetapi terjadi '
          'gangguan ketika membuka pembayaran.',
        );
        return;
      }

      _showSnackBar(
        'Pesanan gagal dibuat. Silakan coba kembali.',
        Colors.red.shade400,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _checkPaymentAndShowResult(CustomerOrderModel order) async {
    PaymentStatusResult? result;
    String? checkError;

    try {
      result = await _orderRepository.checkPaymentStatus(order.id);
      _refreshNotificationBadge();
    } on ApiException catch (error) {
      checkError = error.firstValidationError;
    } catch (error) {
      debugPrint('CHECK PAYMENT ERROR: $error');
      checkError = 'Status pembayaran belum dapat diperiksa.';
    }

    if (!mounted) {
      return;
    }

    while (true) {
      final action = await _showPaymentResultDialog(
        order: order,
        result: result,
        errorMessage: checkError,
      );

      if (!mounted) {
        return;
      }

      if (action == _PaymentDialogAction.checkAgain) {
        setState(() {
          _isSubmitting = true;
        });

        try {
          result = await _orderRepository.checkPaymentStatus(order.id);
          checkError = null;
          _refreshNotificationBadge();
        } on ApiException catch (error) {
          checkError = error.firstValidationError;
        } catch (error) {
          checkError = 'Status pembayaran belum dapat diperiksa.';
        } finally {
          if (mounted) {
            setState(() {
              _isSubmitting = false;
            });
          }
        }

        continue;
      }

      Navigator.pop(context, true);
      return;
    }
  }

  void _refreshNotificationBadge() {
    if (!mounted) {
      return;
    }

    unawaited(
      context
          .read<CustomerNotificationProvider>()
          .refreshUnreadCount(),
    );
  }

  Future<_PaymentDialogAction?> _showPaymentResultDialog({
    required CustomerOrderModel order,
    required PaymentStatusResult? result,
    required String? errorMessage,
  }) {
    final theme = Theme.of(context);
    final paid = result?.isPaid == true;
    final paymentStatus = result?.payment.status ?? 'unknown';
    final statusColor = paid
        ? Colors.green.shade500
        : paymentStatus == 'pending'
        ? Colors.orange.shade500
        : Colors.red.shade400;

    final title = paid
        ? 'Pembayaran Berhasil'
        : paymentStatus == 'pending'
        ? 'Pembayaran Menunggu'
        : errorMessage != null
        ? 'Status Belum Diketahui'
        : 'Pembayaran Belum Berhasil';

    final message =
        errorMessage ??
        result?.message ??
        'Status pembayaran berhasil diperiksa.';

    return showDialog<_PaymentDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Column(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  paid
                      ? Icons.check_circle_rounded
                      : paymentStatus == 'pending'
                      ? Icons.schedule_rounded
                      : Icons.info_outline_rounded,
                  color: statusColor,
                  size: 47,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: theme.textTheme.titleLarge?.color,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                order.orderNumber,
                style: GoogleFonts.inter(
                  color: const Color(0xFF9B5EFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: theme.textTheme.bodyMedium?.color,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildPaymentResultRow(
                      label: 'Total',
                      value: 'Rp ${_formatPrice(order.grandTotal)}',
                    ),
                    _buildPaymentResultRow(
                      label: 'Status',
                      value: _paymentStatusLabel(
                        result?.orderPaymentStatus ?? paymentStatus,
                      ),
                      valueColor: statusColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            if (!paid)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext, _PaymentDialogAction.checkAgain);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Cek Status Pembayaran'),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, _PaymentDialogAction.finish);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B5EFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Selesai'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentResultRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: valueColor ?? theme.textTheme.titleLarge?.color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showOrderCreatedWithoutPayment(
    CustomerOrderModel order,
    String message,
  ) async {
    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Pesanan Berhasil Dibuat',
            style: GoogleFonts.poppins(
              color: theme.textTheme.titleLarge?.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                order.orderNumber,
                style: GoogleFonts.inter(
                  color: const Color(0xFF9B5EFF),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: theme.textTheme.bodyMedium?.color,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Pembayaran dapat dilanjutkan dari '
                'halaman pesanan customer.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: theme.textTheme.bodySmall?.color,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B5EFF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Mengerti'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    Navigator.pop(context, true);
  }

  Future<void> _showCodOrderCreated(CustomerOrderModel order) async {
    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Pesanan COD Berhasil',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '${order.orderNumber}\n\nSiapkan pembayaran tunai sebesar '
          'Rp ${_formatPrice(order.grandTotal)} saat pesanan tiba.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Lihat Pesanan'),
          ),
        ],
      ),
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
  }

  String _paymentStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Terbayar';
      case 'unpaid':
        return 'Belum Dibayar';
      case 'pending':
        return 'Menunggu';
      case 'expired':
        return 'Kedaluwarsa';
      case 'failed':
        return 'Gagal';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.04;
    final isTablet = screenWidth > 600;

    SystemChrome.setSystemUIOverlayStyle(
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const [Color(0xFF13102A), Color(0xFF0D0D12)]
                  : const [Color(0xFFF5F5FA), Color(0xFFE8E8F0)],
            ),
          ),
          child: Column(
            children: [
              _buildHeader(
                horizontalPadding: horizontalPadding,
                isDark: isDark,
                isTablet: isTablet,
              ),
              Expanded(
                child: _buildBody(
                  horizontalPadding: horizontalPadding,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required double horizontalPadding,
    required bool isDark,
    required bool isTablet,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        top: MediaQuery.of(context).padding.top + 14,
        bottom: 16,
      ),
      color: Colors.transparent,
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isSubmitting
                  ? null
                  : () {
                      Navigator.maybePop(context);
                    },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: isTablet ? 58 : 52,
                height: isTablet ? 58 : 52,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF16162A)
                      : const Color(0xFFF9F9FC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF28243F)
                        : const Color(0xFFE4E4EC),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: theme.textTheme.titleLarge?.color,
                  size: isTablet ? 29 : 26,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Checkout',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: theme.textTheme.titleLarge?.color,
                fontSize: isTablet ? 30 : 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: _openWhatsApp,
            style: TextButton.styleFrom(
              foregroundColor: theme.textTheme.bodyMedium?.color,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Hubungi Admin',
              style: GoogleFonts.inter(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: isTablet ? 13 : 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openWhatsApp,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: isTablet ? 56 : 50,
                height: isTablet ? 56 : 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CD466),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CD466).withValues(alpha: 0.32),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({required double horizontalPadding, required bool isDark}) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF9B5EFF)),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF9B5EFF),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          16,
          horizontalPadding,
          28,
        ),
        children: [
          _buildDeliveryMethodCard(isDark),
          const SizedBox(height: 16),
          if (_deliveryMethod == 'delivery') ...[
            _buildAddressSection(isDark),
            const SizedBox(height: 16),
          ] else ...[
            _buildPickupCard(isDark),
            const SizedBox(height: 16),
          ],
          _buildPaymentCard(isDark),
          const SizedBox(height: 16),
          _buildNotesCard(isDark),
          const SizedBox(height: 16),
          _buildOrderSummaryCard(isDark),
          const SizedBox(height: 18),
          _buildCheckoutButton(isDark),
          const SizedBox(height: 18),
          _buildAdminContactCard(isDark),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildDeliveryMethodCard(bool isDark) {
    return _sectionCard(
      isDark: isDark,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: RadioGroup<String>(
        groupValue: _deliveryMethod,
        onChanged: _selectDeliveryMethod,
        child: Column(
          children: [
            _deliveryOption(
              value: 'delivery',
              title: 'Di Antar ke Alamat',
              subtitle: 'Pesanan akan diantar ke lokasi Anda',
              icon: Icons.delivery_dining_rounded,
              isDark: isDark,
            ),
            Divider(
              height: 20,
              color: isDark ? const Color(0xFF28243F) : const Color(0xFFE6E6ED),
            ),
            _deliveryOption(
              value: 'pickup',
              title: 'Ambil di Toko',
              subtitle: 'Ambil pesanan langsung di toko kami',
              icon: Icons.storefront_rounded,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _deliveryOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final selected = _deliveryMethod == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSubmitting ? null : () => _selectDeliveryMethod(value),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Radio<String>(
                value: value,
                enabled: !_isSubmitting,
                activeColor: const Color(0xFF9255F5),
              ),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF242039)
                      : const Color(0xFFF3F3F7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF9255F5), size: 27),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }

  void _selectDeliveryMethod(String? value) {
    if (value == null || _isSubmitting) {
      return;
    }

    setState(() {
      _deliveryMethod = value;
      if (value == 'pickup' && _paymentMethod == 'cash') {
        _paymentMethod = 'midtrans';
      }
      _showDeliveryRoute = false;
      _checkedLocationAccuracy = null;
      _routeDistanceKm = value == 'delivery' ? null : 0;
    });
  }

  Widget _buildAddressSection(bool isDark) {
    return _sectionCard(
      isDark: isDark,
      child: RadioGroup<int>(
        groupValue: _selectedAddressId,
        onChanged: _selectAddress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _sectionTitle(
                    icon: Icons.location_on_outlined,
                    title: 'Alamat Pengiriman',
                  ),
                ),
                TextButton.icon(
                  onPressed: _isSubmitting ? null : _showAddAddressSheet,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Tambah'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_addresses.isEmpty)
              _buildEmptyAddress(isDark)
            else ...[
              ..._addresses.map(
                (address) =>
                    _buildAddressOption(address: address, isDark: isDark),
              ),
              if (_selectedAddress != null) ...[
                const SizedBox(height: 7),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting || _isCheckingLocation
                        ? null
                        : _checkCurrentDeviceLocation,
                    icon: _isCheckingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.gps_fixed_rounded),
                    label: Text(
                      _isCheckingLocation
                          ? 'Mengambil GPS Akurat...'
                          : _showDeliveryRoute
                          ? 'Cek Ulang Lokasi & Rute'
                          : 'Cek Lokasi & Tampilkan Rute',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9255F5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                if (_checkedLocationAccuracy != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Lokasi diambil langsung dari GPS perangkat • '
                    'akurasi ±${_checkedLocationAccuracy!.round()} meter',
                    style: GoogleFonts.inter(
                      color: Colors.green.shade600,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
              if (_showDeliveryRoute &&
                  _selectedAddress?.latitude != null &&
                  _selectedAddress?.longitude != null)
                DeliveryRoutePreview(
                  key: ValueKey(_routeCheckRevision),
                  customerLatitude: _selectedAddress!.latitude!,
                  customerLongitude: _selectedAddress!.longitude!,
                  onDistanceChanged: (distanceKm) {
                    if (mounted) {
                      setState(() {
                        _routeDistanceKm = distanceKm;
                      });
                    }
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAddress(bool isDark) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D12) : const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.add_location_alt_outlined,
            color: theme.textTheme.bodySmall?.color,
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            'Belum ada alamat',
            style: GoogleFonts.poppins(
              color: theme.textTheme.titleLarge?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tambahkan alamat untuk menggunakan '
            'metode pengiriman.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: theme.textTheme.bodySmall?.color,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _showAddAddressSheet,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah Alamat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B5EFF),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressOption({
    required AddressModel address,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final selected = _selectedAddressId == address.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSubmitting ? null : () => _selectAddress(address.id),
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF9B5EFF).withValues(alpha: 0.10)
                  : isDark
                  ? const Color(0xFF0D0D12)
                  : const Color(0xFFF7F7FB),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected
                    ? const Color(0xFF9B5EFF)
                    : isDark
                    ? const Color(0xFF1E1E35)
                    : const Color(0xFFE5E7EB),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Radio<int>(
                  value: address.id,
                  enabled: !_isSubmitting,
                  activeColor: const Color(0xFF9B5EFF),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            address.label,
                            style: GoogleFonts.poppins(
                              color: theme.textTheme.titleLarge?.color,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (address.isDefault)
                            _smallBadge(
                              text: 'Utama',
                              color: Colors.green.shade500,
                            ),
                          if (address.latitude != null &&
                              address.longitude != null)
                            _smallBadge(
                              text: 'GPS',
                              color: const Color(0xFF9B5EFF),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${address.recipientName} • '
                        '${address.phone}',
                        style: GoogleFonts.inter(
                          color: theme.textTheme.bodyMedium?.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address.fullAddress,
                        style: GoogleFonts.inter(
                          color: theme.textTheme.bodySmall?.color,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                      if (address.locationSummary.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          address.locationSummary,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF9B5EFF),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectAddress(int? value) {
    if (value == null || _isSubmitting) {
      return;
    }

    setState(() {
      _selectedAddressId = value;
      _showDeliveryRoute = false;
      _checkedLocationAccuracy = null;
      _routeDistanceKm = null;
    });
  }

  Widget _buildPickupCard(bool isDark) {
    final theme = Theme.of(context);

    return _sectionCard(
      isDark: isDark,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF9B5EFF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: Color(0xFF9B5EFF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ambil di Toko Kanzza',
                  style: GoogleFonts.poppins(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Alamat pengambilan dan jadwal '
                  'selanjutnya dapat dilihat pada detail pesanan.',
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                _smallBadge(
                  text: 'Tanpa alamat customer',
                  color: const Color(0xFF9B5EFF),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(bool isDark) {
    return _sectionCard(
      isDark: isDark,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: RadioGroup<String>(
        groupValue: _paymentMethod,
        onChanged: _selectPaymentMethod,
        child: Column(
          children: [
            _paymentOption(
              value: 'cash',
              title: 'Bayar di Tempat (COD)',
              subtitle: !AppConfig.customerCodEnabled
                  ? 'Belum didukung oleh server saat ini'
                  : _deliveryMethod == 'pickup'
                  ? 'COD hanya tersedia untuk pesanan delivery'
                  : 'Bayar tunai saat pesanan sampai',
              icon: Icons.payments_outlined,
              isDark: isDark,
              enabled:
                  AppConfig.customerCodEnabled && _deliveryMethod == 'delivery',
            ),
            Divider(
              height: 20,
              color: isDark ? const Color(0xFF28243F) : const Color(0xFFE6E6ED),
            ),
            _paymentOption(
              value: 'midtrans',
              title: 'Pembayaran Online (Midtrans)',
              subtitle: 'Transfer bank, QRIS, e-wallet, dan metode lainnya',
              icon: Icons.account_balance_wallet_rounded,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: _isSubmitting || !enabled
          ? null
          : () => _selectPaymentMethod(value),
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          Radio<String>(
            value: value,
            enabled: !_isSubmitting && enabled,
            activeColor: const Color(0xFF9255F5),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF242039) : const Color(0xFFF3F3F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF9255F5), size: 27),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectPaymentMethod(String? value) {
    if (value == null ||
        _isSubmitting ||
        (value == 'cash' &&
            (!AppConfig.customerCodEnabled || _deliveryMethod != 'delivery'))) {
      return;
    }

    setState(() => _paymentMethod = value);
  }

  Widget _buildNotesCard(bool isDark) {
    final theme = Theme.of(context);

    return _sectionCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(icon: Icons.notes_rounded, title: 'Catatan Pesanan'),
          const SizedBox(height: 11),
          TextField(
            controller: _notesController,
            enabled: !_isSubmitting,
            maxLines: 3,
            maxLength: 1000,
            style: GoogleFonts.inter(
              color: theme.textTheme.titleLarge?.color,
              fontSize: 12,
            ),
            decoration: InputDecoration(
              hintText: 'Contoh: mohon hubungi sebelum mengantar',
              hintStyle: GoogleFonts.inter(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 11,
              ),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF0D0D12)
                  : const Color(0xFFF7F7FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF9B5EFF),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard(bool isDark) {
    final theme = Theme.of(context);
    final isPickup = _deliveryMethod == 'pickup';

    return _sectionCard(
      isDark: isDark,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        children: [
          _summaryRow(
            label: 'Total Belanja',
            value: 'Rp ${_formatPrice(_cartSubtotal)}',
            valueFontSize: 15,
          ),
          const SizedBox(height: 2),
          _summaryRow(
            label: 'Ongkos Kirim',
            value: isPickup
                ? 'Rp 0'
                : _effectiveDistanceKm == null
                ? 'Cek lokasi dahulu'
                : 'Rp ${_formatPrice(_shippingCost)}',
            valueFontSize: isPickup || _effectiveDistanceKm != null ? 15 : 11,
          ),
          Divider(
            height: 26,
            thickness: 1.2,
            color: isDark ? const Color(0xFF6D6882) : const Color(0xFF4B4B55),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total Pembayaran',
                  style: GoogleFonts.poppins(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Rp ${_formatPrice(_checkoutTotal)}',
                textAlign: TextAlign.right,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF9255F5),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFF9255F5).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF9255F5).withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              isPickup
                  ? 'Harga dan stok tetap divalidasi ulang oleh server.'
                  : _effectiveDistanceKm == null
                  ? 'Cek lokasi terlebih dahulu untuk menghitung ongkos kirim.'
                  : 'Jarak ${_effectiveDistanceKm!.toStringAsFixed(2)} km × Rp5.000/km. Harga dan stok tetap divalidasi server.',
              style: GoogleFonts.inter(
                color: const Color(0xFF7C3AED),
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow({
    required String label,
    required String value,
    double valueFontSize = 13,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              color: theme.textTheme.titleLarge?.color,
              fontSize: valueFontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(bool isDark) {
    final disabled =
        _deliveryMethod == 'delivery' && _selectedAddressId == null;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: disabled || _isSubmitting ? null : _confirmAndCreateOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9255F5),
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark
              ? const Color(0xFF5C5878)
              : const Color(0xFFD1D5DB),
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.3,
                ),
              )
            : Text(
                _paymentMethod == 'cash'
                    ? 'Buat Pesanan COD'
                    : 'Lanjutkan ke Pembayaran',
              ),
      ),
    );
  }

  Widget _buildAdminContactCard(bool isDark) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF4CD466).withValues(alpha: 0.35),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF4CD466).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.chat_rounded,
              color: Color(0xFF35B954),
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hubungi Admin',
                  style: GoogleFonts.poppins(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ada kendala? Klik tombol di samping untuk chat admin.',
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _openWhatsApp,
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: const Text('Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CD466),
              foregroundColor: Colors.white,
              elevation: 5,
              shadowColor: const Color(0xFF4CD466).withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required bool isDark,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(15),
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 9,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle({required IconData icon, required String title}) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: const Color(0xFF9B5EFF), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            color: theme.textTheme.titleLarge?.color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _smallBadge({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, color: Colors.red.shade300, size: 64),
            const SizedBox(height: 17),
            Text(
              'Checkout gagal dimuat',
              style: GoogleFonts.poppins(
                color: theme.textTheme.titleLarge?.color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  'Terjadi kesalahan ketika mengambil data checkout.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 19),
            ElevatedButton.icon(
              onPressed: () {
                _loadCheckoutData();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B5EFF),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddAddressSheet extends StatefulWidget {
  final String initialName;
  final String initialPhone;

  const _AddAddressSheet({
    required this.initialName,
    required this.initialPhone,
  });

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _labelController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();

    _labelController = TextEditingController(text: 'Rumah');
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  void _applyDetectedLocation(DetectedLocation location) {
    setState(() {
      _latitude = location.latitude;
      _longitude = location.longitude;
      _addressController.text = location.fullAddress;
      _districtController.text = location.district ?? '';
      _cityController.text = location.city ?? '';
      _provinceController.text = location.province ?? '';
      _postalCodeController.text = location.postalCode ?? '';
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.pop(
      context,
      _AddressFormResult(
        label: _labelController.text.trim(),
        recipientName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        fullAddress: _addressController.text.trim(),
        district: _districtController.text.trim(),
        city: _cityController.text.trim(),
        province: _provinceController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        isDefault: _isDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16162A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF1E1E35)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tambah Alamat',
                        style: GoogleFonts.poppins(
                          color: theme.textTheme.titleLarge?.color,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _field(
                          controller: _labelController,
                          label: 'Label alamat',
                          hint: 'Rumah, Kantor, Kost',
                          icon: Icons.bookmark_outline,
                          validator: _required,
                        ),
                        const SizedBox(height: 13),
                        _field(
                          controller: _nameController,
                          label: 'Nama penerima',
                          hint: 'Nama lengkap penerima',
                          icon: Icons.person_outline,
                          validator: _required,
                        ),
                        const SizedBox(height: 13),
                        _field(
                          controller: _phoneController,
                          label: 'Nomor telepon',
                          hint: 'Contoh: 081234567890',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: _validatePhone,
                        ),
                        const SizedBox(height: 13),
                        LocationPickerCard(
                          initialLatitude: _latitude,
                          initialLongitude: _longitude,
                          autoDetect: true,
                          onLocationChanged: _applyDetectedLocation,
                        ),
                        const SizedBox(height: 13),
                        _field(
                          controller: _addressController,
                          label: 'Alamat lengkap',
                          hint: 'Jalan, nomor rumah, RT/RW, patokan',
                          icon: Icons.location_on_outlined,
                          maxLines: 3,
                          validator: _required,
                        ),
                        const SizedBox(height: 13),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                controller: _districtController,
                                label: 'Kecamatan',
                                hint: 'Opsional',
                                icon: Icons.map_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _field(
                                controller: _cityController,
                                label: 'Kota/Kabupaten',
                                hint: 'Opsional',
                                icon: Icons.location_city_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                controller: _provinceController,
                                label: 'Provinsi',
                                hint: 'Opsional',
                                icon: Icons.public_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _field(
                                controller: _postalCodeController,
                                label: 'Kode pos',
                                hint: 'Opsional',
                                icon: Icons.markunread_mailbox_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _isDefault,
                          activeThumbColor: const Color(0xFF9B5EFF),
                          onChanged: (value) {
                            setState(() {
                              _isDefault = value;
                            });
                          },
                          title: Text(
                            'Jadikan alamat utama',
                            style: GoogleFonts.inter(
                              color: theme.textTheme.titleLarge?.color,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Alamat ini akan dipilih otomatis.',
                            style: GoogleFonts.inter(
                              color: theme.textTheme.bodySmall?.color,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _submit,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Simpan Alamat'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9B5EFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.inter(
        color: theme.textTheme.titleLarge?.color,
        fontSize: 12,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF9B5EFF), size: 19),
        filled: true,
        fillColor: isDark ? const Color(0xFF0D0D12) : const Color(0xFFF7F7FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF9B5EFF), width: 1.5),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Field ini wajib diisi.';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    final requiredError = _required(value);

    if (requiredError != null) {
      return requiredError;
    }

    final normalized = value!.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');

    if (!RegExp(r'^[0-9]{10,15}$').hasMatch(normalized)) {
      return 'Nomor telepon harus 10–15 digit.';
    }

    return null;
  }
}

class _AddressFormResult {
  final String label;
  final String recipientName;
  final String phone;
  final String fullAddress;
  final String district;
  final String city;
  final String province;
  final String postalCode;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  const _AddressFormResult({
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.fullAddress,
    required this.district,
    required this.city,
    required this.province,
    required this.postalCode,
    this.latitude,
    this.longitude,
    required this.isDefault,
  });
}

enum _PaymentDialogAction { checkAgain, finish }
