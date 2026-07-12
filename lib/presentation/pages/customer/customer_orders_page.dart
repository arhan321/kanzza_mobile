// lib/presentation/pages/customer/customer_orders_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/models/cart_item.dart';
import '../../../data/models/customer_order.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/customer_order_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../routes.dart';
import '../../providers/customer_cart_provider.dart';
import 'customer_cart_page.dart';
import 'midtrans_payment_page.dart';

class CustomerOrdersPage extends StatefulWidget {
  const CustomerOrdersPage({super.key});

  @override
  State<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends State<CustomerOrdersPage> {
  final CustomerOrderRepository _orderRepository = CustomerOrderRepository();
  final ProductRepository _productRepository = ProductRepository();
  final UserRepository _userRepository = UserRepository();

  final List<CustomerOrderModel> _orders = [];

  _OrderFilter _selectedFilter = _OrderFilter.all;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  bool _isLoading = true;
  bool _isRefreshing = false;
  int? _processingOrderId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders({bool isRefresh = false}) async {
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
      final orders = await _orderRepository.getOrders(perPage: 100);

      if (!mounted) {
        return;
      }

      setState(() {
        _orders
          ..clear()
          ..addAll(orders);

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
      debugPrint('LOAD CUSTOMER ORDERS ERROR: $error');

      _handleLoadError('Pesanan gagal dimuat. Silakan coba kembali.');
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

    await _loadOrders(isRefresh: true);
  }

  List<CustomerOrderModel> get _filteredOrders {
    final filtered = _orders.where((order) {
      if (!_matchesSelectedFilter(order)) {
        return false;
      }

      final orderDate = _orderDate(order).toLocal();

      if (_filterStartDate != null) {
        final start = DateTime(
          _filterStartDate!.year,
          _filterStartDate!.month,
          _filterStartDate!.day,
        );

        if (orderDate.isBefore(start)) {
          return false;
        }
      }

      if (_filterEndDate != null) {
        final end = DateTime(
          _filterEndDate!.year,
          _filterEndDate!.month,
          _filterEndDate!.day,
          23,
          59,
          59,
          999,
        );

        if (orderDate.isAfter(end)) {
          return false;
        }
      }

      return true;
    }).toList();

    filtered.sort(
      (first, second) => _orderDate(second).compareTo(_orderDate(first)),
    );

    return filtered;
  }

  bool _matchesSelectedFilter(CustomerOrderModel order) {
    switch (_selectedFilter) {
      case _OrderFilter.all:
        return true;

      case _OrderFilter.unpaid:
        return !order.isPaid && order.orderStatus != 'cancelled';

      case _OrderFilter.processing:
        return const {
          'confirmed',
          'processing',
          'ready',
          'assigned',
        }.contains(order.orderStatus);

      case _OrderFilter.shipping:
        return const {'picked_up', 'on_delivery'}.contains(order.orderStatus);

      case _OrderFilter.completed:
        return order.orderStatus == 'delivered';

      case _OrderFilter.cancelled:
        return order.orderStatus == 'cancelled';
    }
  }

  DateTime _orderDate(CustomerOrderModel order) {
    return order.createdAt ??
        order.updatedAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _canCancel(CustomerOrderModel order) {
    return !order.isPaid && order.orderStatus != 'cancelled';
  }

  bool _canPay(CustomerOrderModel order) {
    return !order.isPaid && order.orderStatus != 'cancelled';
  }

  Future<void> _showFilterDialog() async {
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    DateTime? temporaryStart = _filterStartDate;
    DateTime? temporaryEnd = _filterEndDate;

    final applied = await showDialog<_DateFilterResult>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickStart() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: temporaryStart ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return _datePickerTheme(
                    context: context,
                    child: child!,
                    isDark: isDark,
                  );
                },
              );

              if (picked == null) {
                return;
              }

              setDialogState(() {
                temporaryStart = picked;

                if (temporaryEnd != null &&
                    temporaryStart!.isAfter(temporaryEnd!)) {
                  temporaryEnd = temporaryStart;
                }
              });
            }

            Future<void> pickEnd() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: temporaryEnd ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return _datePickerTheme(
                    context: context,
                    child: child!,
                    isDark: isDark,
                  );
                },
              );

              if (picked == null) {
                return;
              }

              setDialogState(() {
                temporaryEnd = picked;

                if (temporaryStart != null &&
                    temporaryEnd!.isBefore(temporaryStart!)) {
                  temporaryStart = temporaryEnd;
                }
              });
            }

            return AlertDialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF1E1E35)
                      : const Color(0xFFE8E8F0),
                ),
              ),
              title: Text(
                'Filter Tanggal',
                style: GoogleFonts.poppins(
                  color: theme.textTheme.titleLarge?.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dateField(
                    context: context,
                    label: 'Dari tanggal',
                    date: temporaryStart,
                    onTap: pickStart,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _dateField(
                    context: context,
                    label: 'Sampai tanggal',
                    date: temporaryEnd,
                    onTap: pickEnd,
                    isDark: isDark,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      temporaryStart = null;
                      temporaryEnd = null;
                    });
                  },
                  child: const Text('Reset'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
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
                    Navigator.pop(
                      dialogContext,
                      _DateFilterResult(
                        start: temporaryStart,
                        end: temporaryEnd,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B5EFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: const Text('Terapkan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (applied == null || !mounted) {
      return;
    }

    setState(() {
      _filterStartDate = applied.start;
      _filterEndDate = applied.end;
    });
  }

  Theme _datePickerTheme({
    required BuildContext context,
    required Widget child,
    required bool isDark,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: isDark
            ? const ColorScheme.dark(
                primary: Color(0xFF9B5EFF),
                onPrimary: Colors.white,
                surface: Color(0xFF16162A),
                onSurface: Color(0xFFF0EAFF),
              )
            : const ColorScheme.light(
                primary: Color(0xFF9B5EFF),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Color(0xFF1F2937),
              ),
      ),
      child: child,
    );
  }

  Widget _dateField({
    required BuildContext context,
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D0D12) : const Color(0xFFF7F7FB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: Color(0xFF9B5EFF),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 9,
                      ),
                    ),
                    Text(
                      date == null
                          ? 'Pilih tanggal'
                          : DateFormat('dd/MM/yyyy').format(date),
                      style: GoogleFonts.inter(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelOrder(CustomerOrderModel order) async {
    final confirmed = await _showCancelConfirmation(order);

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _processingOrderId = order.id;
    });

    try {
      await _orderRepository.cancelOrder(order.id);

      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Pesanan ${order.orderNumber} berhasil dibatalkan.',
        Colors.green.shade500,
      );

      await _loadOrders(isRefresh: true);
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
      debugPrint('CANCEL CUSTOMER ORDER ERROR: $error');

      if (!mounted) {
        return;
      }

      _showSnackBar('Pesanan gagal dibatalkan.', Colors.red.shade400);
    } finally {
      if (mounted) {
        setState(() {
          _processingOrderId = null;
        });
      }
    }
  }

  Future<bool?> _showCancelConfirmation(CustomerOrderModel order) {
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
            'Batalkan Pesanan',
            style: GoogleFonts.poppins(
              color: theme.textTheme.titleLarge?.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Batalkan pesanan ${order.orderNumber}? '
            'Stok produk akan dikembalikan oleh sistem.',
            style: GoogleFonts.inter(
              color: theme.textTheme.bodyMedium?.color,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                'Tidak',
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
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: const Text('Ya, Batalkan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _continuePayment(CustomerOrderModel order) async {
    if (_processingOrderId != null) {
      return;
    }

    setState(() {
      _processingOrderId = order.id;
    });

    try {
      final payment = await _orderRepository.createOrReusePayment(order.id);

      if (!mounted) {
        return;
      }

      if (!payment.canOpenPayment) {
        _showSnackBar(
          'Halaman pembayaran belum tersedia.',
          Colors.orange.shade500,
        );
        return;
      }

      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MidtransPaymentPage(
            redirectUrl: payment.redirectUrl!,
            orderNumber: order.orderNumber,
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      await _checkPaymentStatus(order, showResultDialog: true);
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
      debugPrint('CONTINUE PAYMENT ERROR: $error');

      if (!mounted) {
        return;
      }

      _showSnackBar('Pembayaran belum dapat dibuka.', Colors.red.shade400);
    } finally {
      if (mounted) {
        setState(() {
          _processingOrderId = null;
        });
      }
    }
  }

  Future<void> _checkPaymentStatus(
    CustomerOrderModel order, {
    bool showResultDialog = false,
  }) async {
    if (_processingOrderId != null && _processingOrderId != order.id) {
      return;
    }

    setState(() {
      _processingOrderId = order.id;
    });

    try {
      final result = await _orderRepository.checkPaymentStatus(order.id);

      if (!mounted) {
        return;
      }

      if (showResultDialog) {
        await _showPaymentStatusDialog(order: order, result: result);
      } else {
        _showSnackBar(
          result.isPaid ? 'Pembayaran berhasil dikonfirmasi.' : result.message,
          result.isPaid ? Colors.green.shade500 : Colors.orange.shade500,
        );
      }

      await _loadOrders(isRefresh: true);
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
      debugPrint('CHECK ORDER PAYMENT ERROR: $error');

      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Status pembayaran belum dapat diperiksa.',
        Colors.red.shade400,
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingOrderId = null;
        });
      }
    }
  }

  Future<void> _showPaymentStatusDialog({
    required CustomerOrderModel order,
    required PaymentStatusResult result,
  }) {
    final theme = Theme.of(context);
    final paid = result.isPaid;
    final color = paid ? Colors.green.shade500 : Colors.orange.shade500;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  paid ? Icons.check_circle_rounded : Icons.schedule_rounded,
                  color: color,
                  size: 46,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                paid ? 'Pembayaran Berhasil' : 'Pembayaran Menunggu',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: theme.textTheme.titleLarge?.color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
              const SizedBox(height: 8),
              Text(
                result.message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: theme.textTheme.bodyMedium?.color,
                  fontSize: 12,
                  height: 1.5,
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
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _reorder(CustomerOrderModel order) async {
    if (_processingOrderId != null) {
      return;
    }

    setState(() {
      _processingOrderId = order.id;
    });

    try {
      final products = await _productRepository.getProducts(
        isActive: true,
        perPage: 100,
      );

      if (!mounted) {
        return;
      }

      final productMap = <int, ProductModel>{
        for (final product in products) product.id: product,
      };

      final cartProvider = context.read<CustomerCartProvider>();

      int successCount = 0;
      int skippedCount = 0;

      for (final item in order.items) {
        final product = productMap[item.productId];

        if (product == null || !product.canBeSold) {
          skippedCount++;
          continue;
        }

        final quantity = item.quantity > product.stock
            ? product.stock
            : item.quantity;

        if (quantity <= 0) {
          skippedCount++;
          continue;
        }

        final result = await cartProvider.addItem(
          CartItem.fromProduct(product, quantity: quantity),
        );

        if (result.success) {
          successCount++;
        } else {
          skippedCount++;
        }
      }

      if (!mounted) {
        return;
      }

      if (successCount == 0) {
        _showSnackBar(
          'Produk pada pesanan ini sudah tidak tersedia.',
          Colors.orange.shade500,
        );
        return;
      }

      final openCart = await _showReorderResult(
        successCount: successCount,
        skippedCount: skippedCount,
      );

      if (!mounted || openCart != true) {
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerCartPage()),
      );
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
      debugPrint('REORDER ERROR: $error');

      if (!mounted) {
        return;
      }

      _showSnackBar('Produk gagal ditambahkan kembali.', Colors.red.shade400);
    } finally {
      if (mounted) {
        setState(() {
          _processingOrderId = null;
        });
      }
    }
  }

  Future<bool?> _showReorderResult({
    required int successCount,
    required int skippedCount,
  }) {
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Produk Ditambahkan',
            style: GoogleFonts.poppins(
              color: theme.textTheme.titleLarge?.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '$successCount jenis produk berhasil '
            'ditambahkan ke keranjang.'
            '${skippedCount > 0 ? ' $skippedCount jenis produk dilewati karena tidak tersedia atau stok berubah.' : ''}',
            style: GoogleFonts.inter(
              color: theme.textTheme.bodyMedium?.color,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Nanti'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B5EFF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Buka Keranjang'),
            ),
          ],
        );
      },
    );
  }

  void _showOrderDetail(CustomerOrderModel order) {
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final theme = Theme.of(bottomSheetContext);

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.90,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16162A) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: Column(
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
                            'Detail Pesanan',
                            style: GoogleFonts.poppins(
                              color: theme.textTheme.titleLarge?.color,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(bottomSheetContext);
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF9B5EFF,
                                  ).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(
                                  Icons.receipt_long_outlined,
                                  color: Color(0xFF9B5EFF),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.orderNumber,
                                      style: GoogleFonts.poppins(
                                        color:
                                            theme.textTheme.titleLarge?.color,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      _formatDateTime(_orderDate(order)),
                                      style: GoogleFonts.inter(
                                        color: theme.textTheme.bodySmall?.color,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _statusBadge(
                                label: _orderStatusLabel(order),
                                color: _orderStatusColor(order),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _detailSection(
                            isDark: isDark,
                            children: [
                              _detailRow(
                                label: 'Status pembayaran',
                                value: _paymentStatusLabel(order.paymentStatus),
                                valueColor: order.isPaid
                                    ? Colors.green.shade500
                                    : Colors.orange.shade500,
                              ),
                              _detailRow(
                                label: 'Metode pembayaran',
                                value: _paymentMethodLabel(order.paymentMethod),
                              ),
                              _detailRow(
                                label: 'Pengiriman',
                                value: _deliveryMethodLabel(
                                  order.deliveryMethod,
                                ),
                              ),
                              _detailRow(
                                label: 'Jumlah item',
                                value: '${order.totalQuantity} item',
                              ),
                            ],
                          ),
                          if (!order.isPickup) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Alamat Pengiriman',
                              style: GoogleFonts.poppins(
                                color: theme.textTheme.titleLarge?.color,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _addressCard(order, isDark),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            'Produk',
                            style: GoogleFonts.poppins(
                              color: theme.textTheme.titleLarge?.color,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...order.items.map(
                            (item) => _orderItemCard(item, isDark),
                          ),
                          const SizedBox(height: 16),
                          _detailSection(
                            isDark: isDark,
                            children: [
                              _detailRow(
                                label: 'Subtotal',
                                value: 'Rp ${_formatPrice(order.subtotal)}',
                              ),
                              _detailRow(
                                label: 'Ongkos kirim',
                                value: 'Rp ${_formatPrice(order.shippingCost)}',
                              ),
                              if (order.discount > 0)
                                _detailRow(
                                  label: 'Diskon',
                                  value: '- Rp ${_formatPrice(order.discount)}',
                                  valueColor: Colors.green.shade500,
                                ),
                              const Divider(height: 18),
                              _detailRow(
                                label: 'Total',
                                value: 'Rp ${_formatPrice(order.grandTotal)}',
                                valueColor: const Color(0xFF9B5EFF),
                                bold: true,
                              ),
                            ],
                          ),
                          if (order.notes != null &&
                              order.notes!.trim().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Catatan',
                              style: GoogleFonts.poppins(
                                color: theme.textTheme.titleLarge?.color,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E1E35)
                                    : const Color(0xFFF7F7FB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                order.notes!,
                                style: GoogleFonts.inter(
                                  color: theme.textTheme.bodyMedium?.color,
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _addressCard(CustomerOrderModel order, bool isDark) {
    final theme = Theme.of(context);
    final address = order.addressSnapshot;

    final recipient = address?['recipient_name']?.toString();
    final phone = address?['phone']?.toString();
    final fullAddress = address?['full_address']?.toString();
    final district = address?['district']?.toString();
    final city = address?['city']?.toString();
    final province = address?['province']?.toString();
    final postalCode = address?['postal_code']?.toString();

    final location = [
      district,
      city,
      province,
      postalCode,
    ].where((value) => value != null && value.trim().isNotEmpty).join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: Color(0xFF9B5EFF),
            size: 21,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recipient != null && recipient.trim().isNotEmpty)
                  Text(
                    phone != null && phone.trim().isNotEmpty
                        ? '$recipient • $phone'
                        : recipient,
                    style: GoogleFonts.inter(
                      color: theme.textTheme.titleLarge?.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (fullAddress != null && fullAddress.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    fullAddress,
                    style: GoogleFonts.inter(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    location,
                    style: GoogleFonts.inter(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 9,
                    ),
                  ),
                ],
                if ((fullAddress == null || fullAddress.trim().isEmpty) &&
                    location.isEmpty)
                  Text(
                    'Alamat tidak tersedia.',
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

  Widget _orderItemCard(CustomerOrderItemModel item, bool isDark) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF9B5EFF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF9B5EFF),
              size: 19,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.quantity} × Rp ${_formatPrice(item.price)}',
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Text(
            'Rp ${_formatPrice(item.subtotal)}',
            style: GoogleFonts.poppins(
              color: const Color(0xFF9B5EFF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSection({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(children: children),
    );
  }

  Widget _detailRow({
    required String label,
    required String value,
    Color? valueColor,
    bool bold = false,
  }) {
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
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                color: valueColor ?? theme.textTheme.titleLarge?.color,
                fontSize: 11,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
          duration: const Duration(seconds: 3),
        ),
      );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm').format(date.toLocal());
  }

  String _orderStatusLabel(CustomerOrderModel order) {
    if (!order.isPaid && order.orderStatus != 'cancelled') {
      return 'Menunggu Bayar';
    }

    switch (order.orderStatus) {
      case 'pending_payment':
        return 'Menunggu Bayar';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'processing':
        return 'Diproses';
      case 'ready':
        return 'Siap';
      case 'assigned':
        return 'Driver Ditugaskan';
      case 'picked_up':
        return 'Diambil Driver';
      case 'on_delivery':
        return 'Sedang Dikirim';
      case 'delivered':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return order.orderStatus;
    }
  }

  Color _orderStatusColor(CustomerOrderModel order) {
    if (!order.isPaid && order.orderStatus != 'cancelled') {
      return const Color(0xFFFF9800);
    }

    switch (order.orderStatus) {
      case 'pending_payment':
        return const Color(0xFFFF9800);
      case 'confirmed':
        return const Color(0xFF2196F3);
      case 'processing':
        return const Color(0xFF9B5EFF);
      case 'ready':
        return const Color(0xFF00A6A6);
      case 'assigned':
      case 'picked_up':
      case 'on_delivery':
        return const Color(0xFF3F51B5);
      case 'delivered':
        return const Color(0xFF4CAF50);
      case 'cancelled':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _paymentStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Terbayar';
      case 'unpaid':
        return 'Belum Dibayar';
      case 'pending':
        return 'Menunggu';
      case 'failed':
        return 'Gagal';
      case 'expired':
        return 'Kedaluwarsa';
      case 'cancelled':
        return 'Dibatalkan';
      case 'refunded':
        return 'Dikembalikan';
      default:
        return status;
    }
  }

  String _paymentMethodLabel(String? method) {
    switch (method?.toLowerCase()) {
      case 'midtrans':
        return 'Midtrans';
      case 'cash':
        return 'Tunai';
      case 'bank_transfer':
        return 'Transfer Bank';
      case 'cod':
        return 'COD';
      default:
        return method == null || method.trim().isEmpty ? '-' : method;
    }
  }

  String _deliveryMethodLabel(String method) {
    switch (method.toLowerCase()) {
      case 'delivery':
        return 'Diantar ke Alamat';
      case 'pickup':
        return 'Ambil di Toko';
      default:
        return method;
    }
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

    return Scaffold(
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
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(
                horizontalPadding: horizontalPadding,
                isDark: isDark,
                isTablet: isTablet,
              ),
              _buildFilterChips(
                horizontalPadding: horizontalPadding,
                isDark: isDark,
              ),
              if (_filterStartDate != null || _filterEndDate != null)
                _buildDateFilterInfo(
                  horizontalPadding: horizontalPadding,
                  isDark: isDark,
                ),
              const SizedBox(height: 8),
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
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        14,
        horizontalPadding,
        12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13102A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
          ),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.maybePop(context);
            },
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xFF16162A)
                  : const Color(0xFFF5F5FA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pesanan Saya',
                  style: GoogleFonts.poppins(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: isTablet ? 24 : 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_filteredOrders.length} dari ${_orders.length} pesanan',
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Filter tanggal',
            onPressed: _showFilterDialog,
            style: IconButton.styleFrom(
              backgroundColor:
                  (_filterStartDate != null || _filterEndDate != null)
                  ? const Color(0xFF9B5EFF).withOpacity(0.14)
                  : isDark
                  ? const Color(0xFF16162A)
                  : const Color(0xFFF5F5FA),
              foregroundColor: const Color(0xFF9B5EFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.filter_alt_outlined),
          ),
          const SizedBox(width: 7),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _isLoading || _isRefreshing ? null : _refresh,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF9B5EFF).withOpacity(0.12),
              foregroundColor: const Color(0xFF9B5EFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      color: Color(0xFF9B5EFF),
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips({
    required double horizontalPadding,
    required bool isDark,
  }) {
    final theme = Theme.of(context);

    return Container(
      height: 53,
      color: isDark ? const Color(0xFF13102A) : Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 8,
        ),
        itemCount: _OrderFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final filter = _OrderFilter.values[index];
          final selected = _selectedFilter == filter;

          return ChoiceChip(
            selected: selected,
            onSelected: (_) {
              setState(() {
                _selectedFilter = filter;
              });
            },
            label: Text(
              filter.label,
              style: GoogleFonts.inter(
                color: selected
                    ? Colors.white
                    : theme.textTheme.bodyMedium?.color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            selectedColor: const Color(0xFF9B5EFF),
            backgroundColor: isDark
                ? const Color(0xFF16162A)
                : const Color(0xFFF7F7FB),
            side: BorderSide(
              color: selected
                  ? const Color(0xFF9B5EFF)
                  : isDark
                  ? const Color(0xFF1E1E35)
                  : const Color(0xFFE5E7EB),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildDateFilterInfo({
    required double horizontalPadding,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final startText = _filterStartDate == null
        ? null
        : DateFormat('dd/MM/yyyy').format(_filterStartDate!);
    final endText = _filterEndDate == null
        ? null
        : DateFormat('dd/MM/yyyy').format(_filterEndDate!);

    final text = startText != null && endText != null
        ? '$startText – $endText'
        : startText != null
        ? 'Mulai $startText'
        : 'Sampai $endText';

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF9B5EFF).withOpacity(0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9B5EFF).withOpacity(0.20)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.date_range_outlined,
            color: Color(0xFF9B5EFF),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _filterStartDate = null;
                _filterEndDate = null;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                color: Color(0xFF9B5EFF),
                size: 18,
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

    if (_errorMessage != null && _orders.isEmpty) {
      return _buildErrorState();
    }

    if (_filteredOrders.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF9B5EFF),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          10,
          horizontalPadding,
          28,
        ),
        itemCount: _filteredOrders.length + (_errorMessage == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (_errorMessage != null && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildInlineError(),
            );
          }

          final orderIndex = _errorMessage == null ? index : index - 1;

          return _buildOrderCard(
            order: _filteredOrders[orderIndex],
            isDark: isDark,
          );
        },
      ),
    );
  }

  Widget _buildOrderCard({
    required CustomerOrderModel order,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final statusColor = _orderStatusColor(order);
    final processing = _processingOrderId == order.id;
    final previewItems = order.items.take(2).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 9,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _orderStatusIcon(order),
                  color: statusColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDateTime(_orderDate(order)),
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(label: _orderStatusLabel(order), color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          ...previewItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantity}× ${item.productName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rp ${_formatPrice(item.subtotal)}',
                    style: GoogleFonts.inter(
                      color: theme.textTheme.titleLarge?.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (order.items.length > 2)
            Text(
              '+${order.items.length - 2} produk lainnya',
              style: GoogleFonts.inter(
                color: const Color(0xFF9B5EFF),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total',
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 9,
                      ),
                    ),
                    Text(
                      'Rp ${_formatPrice(order.grandTotal)}',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF9B5EFF),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (processing)
                const SizedBox(
                  width: 23,
                  height: 23,
                  child: CircularProgressIndicator(
                    color: Color(0xFF9B5EFF),
                    strokeWidth: 2,
                  ),
                )
              else
                _buildOrderActions(order: order, isDark: isDark),
            ],
          ),
          if (!order.isPickup) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1E35)
                    : const Color(0xFFF7F7FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: theme.textTheme.bodySmall?.color,
                    size: 16,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _addressPreview(order),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderActions({
    required CustomerOrderModel order,
    required bool isDark,
  }) {
    final actions = <Widget>[
      _smallActionButton(
        label: 'Detail',
        icon: Icons.visibility_outlined,
        color: const Color(0xFF9B5EFF),
        isDark: isDark,
        onTap: () {
          _showOrderDetail(order);
        },
      ),
    ];

    if (_canPay(order)) {
      actions.add(
        _smallActionButton(
          label: 'Bayar',
          icon: Icons.payment_rounded,
          color: Colors.orange.shade500,
          isDark: isDark,
          onTap: () {
            _continuePayment(order);
          },
        ),
      );
    }

    if (_canCancel(order)) {
      actions.add(
        _smallActionButton(
          label: 'Batal',
          icon: Icons.close_rounded,
          color: Colors.red.shade400,
          isDark: isDark,
          onTap: () {
            _cancelOrder(order);
          },
        ),
      );
    }

    if (order.orderStatus == 'delivered') {
      actions.add(
        _smallActionButton(
          label: 'Pesan Lagi',
          icon: Icons.replay_circle_filled_outlined,
          color: Colors.green.shade500,
          isDark: isDark,
          onTap: () {
            _reorder(order);
          },
        ),
      );
    }

    return Flexible(
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 6,
        runSpacing: 6,
        children: actions,
      ),
    );
  }

  Widget _smallActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  IconData _orderStatusIcon(CustomerOrderModel order) {
    if (!order.isPaid && order.orderStatus != 'cancelled') {
      return Icons.schedule_rounded;
    }

    switch (order.orderStatus) {
      case 'confirmed':
      case 'processing':
        return Icons.inventory_2_outlined;
      case 'ready':
        return Icons.task_alt_rounded;
      case 'assigned':
      case 'picked_up':
      case 'on_delivery':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.check_circle_outline_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  String _addressPreview(CustomerOrderModel order) {
    final address = order.addressSnapshot;

    if (address == null) {
      return 'Alamat tidak tersedia';
    }

    final fullAddress = address['full_address']?.toString();
    final city = address['city']?.toString();

    if (fullAddress != null && fullAddress.trim().isNotEmpty) {
      return city != null && city.trim().isNotEmpty
          ? '$fullAddress, $city'
          : fullAddress;
    }

    return city != null && city.trim().isNotEmpty
        ? city
        : 'Alamat tidak tersedia';
  }

  Widget _buildInlineError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.orange.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade500,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(
                color: Colors.orange.shade600,
                fontSize: 11,
              ),
            ),
          ),
          TextButton(onPressed: _refresh, child: const Text('Ulangi')),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF9B5EFF),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.70,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: Colors.red.shade300,
                      size: 64,
                    ),
                    const SizedBox(height: 17),
                    Text(
                      'Pesanan gagal dimuat',
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ??
                          'Terjadi kesalahan saat mengambil pesanan.',
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
                        _loadOrders();
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF9B5EFF),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.62,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.receipt_long_outlined,
                        color: theme.textTheme.bodySmall?.color,
                        size: 52,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _orders.isEmpty
                          ? 'Belum Ada Pesanan'
                          : 'Pesanan Tidak Ditemukan',
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _orders.isEmpty
                          ? 'Mulai belanja dan pesanan Anda akan muncul di sini.'
                          : 'Coba ubah status atau filter tanggal.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_orders.isEmpty)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.storefront_outlined),
                        label: const Text('Mulai Belanja'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9B5EFF),
                          foregroundColor: Colors.white,
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedFilter = _OrderFilter.all;
                            _filterStartDate = null;
                            _filterEndDate = null;
                          });
                        },
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Reset Filter'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _OrderFilter {
  all('Semua'),
  unpaid('Belum Bayar'),
  processing('Diproses'),
  shipping('Dikirim'),
  completed('Selesai'),
  cancelled('Dibatalkan');

  final String label;

  const _OrderFilter(this.label);
}

class _DateFilterResult {
  final DateTime? start;
  final DateTime? end;

  const _DateFilterResult({required this.start, required this.end});
}
