// lib/presentation/pages/driver/driver_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../data/models/driver_delivery.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/driver_delivery_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../routes.dart';

class DriverDashboardPage extends StatefulWidget {
  const DriverDashboardPage({super.key});

  @override
  State<DriverDashboardPage> createState() =>
      _DriverDashboardPageState();
}

class _DriverDashboardPageState
    extends State<DriverDashboardPage> {
  final DriverDeliveryRepository _deliveryRepository =
      DriverDeliveryRepository();
  final UserRepository _userRepository =
      UserRepository();

  final List<DriverDeliveryModel> _deliveries = [];

  UserModel? _driver;
  String _selectedFilter = 'all';

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoggingOut = false;
  int? _processingDeliveryId;
  String? _errorMessage;

  static const List<_DriverFilter> _filters = [
    _DriverFilter(
      value: 'all',
      label: 'Semua',
    ),
    _DriverFilter(
      value: 'assigned',
      label: 'Ditugaskan',
    ),
    _DriverFilter(
      value: 'picked_up',
      label: 'Diambil',
    ),
    _DriverFilter(
      value: 'on_delivery',
      label: 'Dikirim',
    ),
    _DriverFilter(
      value: 'delivered',
      label: 'Selesai',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard({
    bool isRefresh = false,
  }) async {
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
      final cachedUser =
          await _userRepository.getCachedUser();

      if (mounted && cachedUser != null) {
        setState(() {
          _driver = cachedUser;
        });
      }

      final results = await Future.wait<dynamic>([
        _userRepository.getProfile(),
        _deliveryRepository.getDeliveries(
          perPage: 100,
        ),
      ]);

      final driver = results[0] as UserModel;
      final deliveries =
          results[1] as List<DriverDeliveryModel>;

      if (!mounted) {
        return;
      }

      setState(() {
        _driver = driver;
        _deliveries
          ..clear()
          ..addAll(deliveries);

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
      debugPrint(
        'LOAD DRIVER DASHBOARD ERROR: $error',
      );

      _handleLoadError(
        'Data pengiriman gagal dimuat. Silakan coba kembali.',
      );
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

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _refresh() async {
    if (_isRefreshing) {
      return;
    }

    await _loadDashboard(isRefresh: true);
  }

  List<DriverDeliveryModel> get _filteredDeliveries {
    if (_selectedFilter == 'all') {
      return List<DriverDeliveryModel>.from(
        _deliveries,
      );
    }

    return _deliveries
        .where(
          (delivery) =>
              delivery.status == _selectedFilter,
        )
        .toList();
  }

  int get _assignedCount {
    return _deliveries
        .where((delivery) => delivery.isAssigned)
        .length;
  }

  int get _pickedUpCount {
    return _deliveries
        .where((delivery) => delivery.isPickedUp)
        .length;
  }

  int get _onDeliveryCount {
    return _deliveries
        .where((delivery) => delivery.isOnDelivery)
        .length;
  }

  int get _deliveredCount {
    return _deliveries
        .where((delivery) => delivery.isDelivered)
        .length;
  }

  int get _activeCount {
    return _deliveries
        .where((delivery) => delivery.isActive)
        .length;
  }

  int get _todayAssignedCount {
    final now = DateTime.now();

    return _deliveries.where((delivery) {
      final date = delivery.assignedAt?.toLocal();

      if (date == null) {
        return false;
      }

      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).length;
  }

  Future<void> _showLogoutConfirmation() async {
    if (_isLoggingOut) {
      return;
    }

    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
            side: BorderSide(
              color: isDark
                  ? const Color(0xFF1E1E35)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          title: Text(
            'Konfirmasi Logout',
            style: GoogleFonts.poppins(
              color:
                  theme.textTheme.titleLarge?.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar dari akun driver?',
            style: GoogleFonts.inter(
              color:
                  theme.textTheme.bodyMedium?.color,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.red.shade400,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _userRepository.logout();
    } finally {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    }
  }

  Future<void> _openDeliveryDetail(
    DriverDeliveryModel delivery,
  ) async {
    DriverDeliveryModel selectedDelivery = delivery;

    try {
      selectedDelivery =
          await _deliveryRepository.getDeliveryDetail(
        delivery.id,
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
        return;
      }

      if (mounted) {
        _showSnackBar(
          error.firstValidationError,
          Colors.orange.shade500,
        );
      }
    } catch (error) {
      debugPrint(
        'GET DRIVER DELIVERY DETAIL ERROR: $error',
      );
    }

    if (!mounted) {
      return;
    }

    await _showDeliveryDetailSheet(
      selectedDelivery,
    );
  }

  Future<void> _showDeliveryDetailSheet(
    DriverDeliveryModel delivery,
  ) {
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final theme =
            Theme.of(bottomSheetContext);
        final order = delivery.order;

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF16162A)
                    : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.fromLTRB(
                      20,
                      12,
                      12,
                      12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? const Color(
                                  0xFF1E1E35,
                                )
                              : const Color(
                                  0xFFE5E7EB,
                                ),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Detail Pengiriman',
                            style:
                                GoogleFonts.poppins(
                              color: theme
                                  .textTheme
                                  .titleLarge
                                  ?.color,
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(
                              bottomSheetContext,
                            );
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child:
                        SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(
                        20,
                        18,
                        20,
                        28,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration:
                                    BoxDecoration(
                                  color:
                                      _statusColor(
                                    delivery.status,
                                  ).withOpacity(0.12),
                                  borderRadius:
                                      BorderRadius
                                          .circular(14),
                                ),
                                child: Icon(
                                  _statusIcon(
                                    delivery.status,
                                  ),
                                  color:
                                      _statusColor(
                                    delivery.status,
                                  ),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      delivery
                                          .orderNumber,
                                      style: GoogleFonts
                                          .poppins(
                                        color: theme
                                            .textTheme
                                            .titleLarge
                                            ?.color,
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight
                                                .w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _formatDateTime(
                                        delivery
                                            .sortDate,
                                      ),
                                      style:
                                          GoogleFonts.inter(
                                        color: theme
                                            .textTheme
                                            .bodySmall
                                            ?.color,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _statusBadge(
                                label:
                                    _statusLabel(
                                  delivery.status,
                                ),
                                color:
                                    _statusColor(
                                  delivery.status,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _detailSection(
                            isDark: isDark,
                            children: [
                              _detailRow(
                                label: 'Customer',
                                value:
                                    order?.customerName ??
                                    'Customer',
                              ),
                              _detailRow(
                                label:
                                    'Nomor telepon',
                                value:
                                    order?.customerPhone ??
                                    '-',
                              ),
                              _detailRow(
                                label:
                                    'Status pembayaran',
                                value:
                                    _paymentStatusLabel(
                                  order
                                          ?.paymentStatus ??
                                      '-',
                                ),
                                valueColor:
                                    order?.paymentStatus ==
                                            'paid'
                                        ? Colors
                                            .green
                                            .shade500
                                        : Colors
                                            .orange
                                            .shade500,
                              ),
                              _detailRow(
                                label:
                                    'Metode pembayaran',
                                value:
                                    _paymentMethodLabel(
                                  order
                                      ?.paymentMethod,
                                ),
                              ),
                              _detailRow(
                                label:
                                    'Jumlah produk',
                                value:
                                    '${order?.totalQuantity ?? 0} item',
                              ),
                              _detailRow(
                                label: 'Total',
                                value:
                                    'Rp ${_formatPrice(order?.grandTotal ?? 0)}',
                                valueColor:
                                    const Color(
                                  0xFF9B5EFF,
                                ),
                                bold: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Alamat Pengiriman',
                            style:
                                GoogleFonts.poppins(
                              color: theme
                                  .textTheme
                                  .titleLarge
                                  ?.color,
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildAddressCard(
                            order,
                            isDark,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Rincian Produk',
                            style:
                                GoogleFonts.poppins(
                              color: theme
                                  .textTheme
                                  .titleLarge
                                  ?.color,
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (order == null ||
                              order.items.isEmpty)
                            _emptyItems(isDark)
                          else
                            ...order.items.map(
                              (item) =>
                                  _buildItemCard(
                                item,
                                isDark,
                              ),
                            ),
                          if (order?.notes != null &&
                              order!.notes!
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Catatan Pesanan',
                              style:
                                  GoogleFonts.poppins(
                                color: theme
                                    .textTheme
                                    .titleLarge
                                    ?.color,
                                fontSize: 14,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _noteCard(
                              order.notes!,
                              isDark,
                            ),
                          ],
                          if (delivery.notes != null &&
                              delivery.notes!
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Catatan Driver',
                              style:
                                  GoogleFonts.poppins(
                                color: theme
                                    .textTheme
                                    .titleLarge
                                    ?.color,
                                fontSize: 14,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _noteCard(
                              delivery.notes!,
                              isDark,
                            ),
                          ],
                          const SizedBox(height: 18),
                          _buildTimeline(
                            delivery,
                            isDark,
                          ),
                          if (delivery.nextStatus !=
                              null) ...[
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child:
                                  ElevatedButton.icon(
                                onPressed:
                                    _processingDeliveryId ==
                                            delivery.id
                                        ? null
                                        : () async {
                                            Navigator.pop(
                                              bottomSheetContext,
                                            );
                                            await _confirmStatusUpdate(
                                              delivery,
                                            );
                                          },
                                icon: Icon(
                                  _nextActionIcon(
                                    delivery.status,
                                  ),
                                ),
                                label: Text(
                                  _nextActionLabel(
                                    delivery.status,
                                  ),
                                ),
                                style:
                                    ElevatedButton
                                        .styleFrom(
                                  backgroundColor:
                                      const Color(
                                    0xFF9B5EFF,
                                  ),
                                  foregroundColor:
                                      Colors.white,
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    vertical: 14,
                                  ),
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      13,
                                    ),
                                  ),
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

  Widget _buildAddressCard(
    DriverDeliveryOrderModel? order,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E35)
            : const Color(0xFFF7F7FB),
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2A2A42)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: Color(0xFF9B5EFF),
            size: 22,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  order?.fullAddress ??
                      'Alamat tidak tersedia',
                  style: GoogleFonts.inter(
                    color: theme
                        .textTheme
                        .titleLarge
                        ?.color,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                if (order != null &&
                    order.locationSummary
                        .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    order.locationSummary,
                    style: GoogleFonts.inter(
                      color: theme
                          .textTheme
                          .bodySmall
                          ?.color,
                      fontSize: 9,
                    ),
                  ),
                ],
                if (order?.latitude != null &&
                    order?.longitude != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Koordinat: '
                    '${order!.latitude!.toStringAsFixed(6)}, '
                    '${order.longitude!.toStringAsFixed(6)}',
                    style: GoogleFonts.inter(
                      color:
                          const Color(0xFF9B5EFF),
                      fontSize: 9,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(
    DriverDeliveryItemModel item,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E35)
            : const Color(0xFFF7F7FB),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color:
                  const Color(0xFF9B5EFF)
                      .withOpacity(0.12),
              borderRadius:
                  BorderRadius.circular(10),
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
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: theme
                        .textTheme
                        .titleLarge
                        ?.color,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.quantity} × Rp ${_formatPrice(item.price)}',
                  style: GoogleFonts.inter(
                    color: theme
                        .textTheme
                        .bodySmall
                        ?.color,
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
              color:
                  const Color(0xFF9B5EFF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyItems(bool isDark) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E35)
            : const Color(0xFFF7F7FB),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Text(
        'Rincian produk tidak tersedia.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color:
              theme.textTheme.bodySmall?.color,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _noteCard(
    String note,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E35)
            : const Color(0xFFF7F7FB),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Text(
        note,
        style: GoogleFonts.inter(
          color:
              theme.textTheme.bodyMedium?.color,
          fontSize: 11,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildTimeline(
    DriverDeliveryModel delivery,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Perjalanan Pengiriman',
          style: GoogleFonts.poppins(
            color: Theme.of(context)
                .textTheme
                .titleLarge
                ?.color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        _timelineItem(
          title: 'Driver ditugaskan',
          date: delivery.assignedAt,
          completed:
              delivery.assignedAt != null,
          isLast: false,
          isDark: isDark,
        ),
        _timelineItem(
          title: 'Pesanan diambil',
          date: delivery.pickedUpAt,
          completed:
              delivery.pickedUpAt != null,
          isLast: false,
          isDark: isDark,
        ),
        _timelineItem(
          title: 'Sedang dikirim',
          date: delivery.isOnDelivery ||
                  delivery.isDelivered
              ? delivery.updatedAt
              : null,
          completed: delivery.isOnDelivery ||
              delivery.isDelivered,
          isLast: false,
          isDark: isDark,
        ),
        _timelineItem(
          title: 'Pesanan selesai',
          date: delivery.deliveredAt,
          completed:
              delivery.deliveredAt != null,
          isLast: true,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _timelineItem({
    required String title,
    required DateTime? date,
    required bool completed,
    required bool isLast,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final color = completed
        ? const Color(0xFF4CAF50)
        : theme.textTheme.bodySmall?.color ??
            const Color(0xFF9CA3AF);

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: completed
                      ? color
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color,
                    width: 2,
                  ),
                ),
                child: completed
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 12,
                      )
                    : null,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 38,
                  color: completed
                      ? color.withOpacity(0.45)
                      : isDark
                          ? const Color(0xFF2A2A42)
                          : const Color(0xFFE5E7EB),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: theme
                        .textTheme
                        .titleLarge
                        ?.color,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date == null
                      ? 'Belum dilakukan'
                      : _formatDateTime(date),
                  style: GoogleFonts.inter(
                    color: theme
                        .textTheme
                        .bodySmall
                        ?.color,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailSection({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E35)
            : const Color(0xFFF7F7FB),
        borderRadius:
            BorderRadius.circular(13),
      ),
      child: Column(
        children: children,
      ),
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
      padding:
          const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color:
                    theme.textTheme.bodySmall?.color,
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
                color: valueColor ??
                    theme
                        .textTheme
                        .titleLarge
                        ?.color,
                fontSize: 11,
                fontWeight: bold
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmStatusUpdate(
    DriverDeliveryModel delivery,
  ) async {
    final nextStatus = delivery.nextStatus;

    if (nextStatus == null ||
        _processingDeliveryId != null) {
      return;
    }

    final result =
        await _showStatusUpdateDialog(
      delivery: delivery,
      nextStatus: nextStatus,
    );

    if (result == null || !mounted) {
      return;
    }

    await _updateDeliveryStatus(
      delivery: delivery,
      nextStatus: nextStatus,
      notes: result.notes,
    );
  }

  Future<_StatusUpdateResult?>
      _showStatusUpdateDialog({
    required DriverDeliveryModel delivery,
    required String nextStatus,
  }) {
    final notesController =
        TextEditingController(
      text: delivery.notes ?? '',
    );
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    return showDialog<_StatusUpdateResult>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
            side: BorderSide(
              color: isDark
                  ? const Color(0xFF1E1E35)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          title: Text(
            _nextActionLabel(delivery.status),
            style: GoogleFonts.poppins(
              color:
                  theme.textTheme.titleLarge?.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Status ${delivery.orderNumber} akan diubah menjadi '
                  '${_statusLabel(nextStatus)}.',
                  style: GoogleFonts.inter(
                    color: theme
                        .textTheme
                        .bodyMedium
                        ?.color,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 13),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  maxLength: 1000,
                  style: GoogleFonts.inter(
                    color: theme
                        .textTheme
                        .titleLarge
                        ?.color,
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        'Catatan driver (opsional)',
                    hintText:
                        'Contoh: pesanan diterima oleh customer',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E1E35)
                        : const Color(0xFFF7F7FB),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    focusedBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(
                        color:
                            Color(0xFF9B5EFF),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                if (nextStatus == 'delivered') ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.orange
                          .withOpacity(0.09),
                      borderRadius:
                          BorderRadius.circular(11),
                    ),
                    child: Text(
                      'Backend saat ini hanya menerima proof_image_path '
                      'berupa teks dan belum menyediakan endpoint upload foto. '
                      'Karena itu bukti foto belum dikirim dari halaman ini.',
                      style: GoogleFonts.inter(
                        color:
                            Colors.orange.shade700,
                        fontSize: 10,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  _StatusUpdateResult(
                    notes:
                        notesController.text.trim(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF9B5EFF),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Konfirmasi',
              ),
            ),
          ],
        );
      },
    ).whenComplete(notesController.dispose);
  }

  Future<void> _updateDeliveryStatus({
    required DriverDeliveryModel delivery,
    required String nextStatus,
    required String notes,
  }) async {
    setState(() {
      _processingDeliveryId = delivery.id;
    });

    try {
      final updated =
          await _deliveryRepository
              .updateDeliveryStatus(
        deliveryId: delivery.id,
        status: nextStatus,
        notes: notes,
      );

      if (!mounted) {
        return;
      }

      final index = _deliveries.indexWhere(
        (item) => item.id == updated.id,
      );

      setState(() {
        if (index >= 0) {
          _deliveries[index] = updated;
        } else {
          _deliveries.insert(0, updated);
        }
      });

      HapticFeedback.mediumImpact();

      _showSnackBar(
        'Status ${updated.orderNumber} berhasil diubah menjadi '
        '${_statusLabel(updated.status)}.',
        Colors.green.shade500,
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
        return;
      }

      if (!mounted) {
        return;
      }

      _showSnackBar(
        error.firstValidationError,
        Colors.red.shade400,
      );
    } catch (error) {
      debugPrint(
        'UPDATE DRIVER DELIVERY STATUS ERROR: $error',
      );

      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Status pengiriman gagal diperbarui.',
        Colors.red.shade400,
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingDeliveryId = null;
        });
      }
    }
  }

  void _showSnackBar(
    String message,
    Color color,
  ) {
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
            borderRadius:
                BorderRadius.circular(13),
          ),
          duration:
              const Duration(seconds: 3),
        ),
      );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(
        r'(\d{1,3})(?=(\d{3})+(?!\d))',
      ),
      (match) => '${match[1]}.',
    );
  }

  String _formatDateTime(DateTime value) {
    return DateFormat('dd/MM/yyyy HH:mm')
        .format(value.toLocal());
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'Ditugaskan';
      case 'picked_up':
        return 'Sudah Diambil';
      case 'on_delivery':
        return 'Sedang Dikirim';
      case 'delivered':
        return 'Selesai';
      case 'unassigned':
        return 'Belum Ditugaskan';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'assigned':
        return const Color(0xFFFF9800);
      case 'picked_up':
        return const Color(0xFF2196F3);
      case 'on_delivery':
        return const Color(0xFF3F51B5);
      case 'delivered':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'assigned':
        return Icons.assignment_ind_outlined;
      case 'picked_up':
        return Icons.inventory_2_outlined;
      case 'on_delivery':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.delivery_dining_outlined;
    }
  }

  String _nextActionLabel(String currentStatus) {
    switch (currentStatus) {
      case 'assigned':
        return 'Ambil Pesanan';
      case 'picked_up':
        return 'Mulai Pengiriman';
      case 'on_delivery':
        return 'Selesaikan Pengiriman';
      default:
        return 'Perbarui Status';
    }
  }

  IconData _nextActionIcon(String currentStatus) {
    switch (currentStatus) {
      case 'assigned':
        return Icons.inventory_2_outlined;
      case 'picked_up':
        return Icons.local_shipping_outlined;
      case 'on_delivery':
        return Icons.task_alt_rounded;
      default:
        return Icons.sync_rounded;
    }
  }

  String _paymentStatusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Terbayar';
      case 'unpaid':
        return 'Belum Dibayar';
      case 'pending':
        return 'Menunggu';
      case 'cancelled':
        return 'Dibatalkan';
      case 'failed':
        return 'Gagal';
      case 'expired':
        return 'Kedaluwarsa';
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
        return method == null ||
                method.trim().isEmpty
            ? '-'
            : method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider =
        Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final theme = Theme.of(context);
    final width =
        MediaQuery.of(context).size.width;
    final horizontalPadding = width * 0.04;
    final isTablet = width > 600;

    SystemChrome.setSystemUIOverlayStyle(
      isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF13102A),
                    Color(0xFF0D0D12),
                  ]
                : const [
                    Color(0xFFF5F5FA),
                    Color(0xFFE8E8F0),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(
                horizontalPadding:
                    horizontalPadding,
                isDark: isDark,
                isTablet: isTablet,
              ),
              Expanded(
                child: _buildBody(
                  horizontalPadding:
                      horizontalPadding,
                  isDark: isDark,
                  isTablet: isTablet,
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
        14,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF13102A)
            : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? const Color(0xFF1E1E35)
                : const Color(0xFFE5E7EB),
          ),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color:
                      Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard Driver',
                  style: GoogleFonts.poppins(
                    color: theme
                        .textTheme
                        .titleLarge
                        ?.color,
                    fontSize: isTablet ? 25 : 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _driver?.name ?? 'Driver Kanzza',
                  style: GoogleFonts.inter(
                    color: theme
                        .textTheme
                        .bodySmall
                        ?.color,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed:
                _isLoading || _isRefreshing
                ? null
                : _refresh,
            style: IconButton.styleFrom(
              backgroundColor:
                  const Color(0xFF9B5EFF)
                      .withOpacity(0.12),
              foregroundColor:
                  const Color(0xFF9B5EFF),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
            ),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child:
                        CircularProgressIndicator(
                      color: Color(0xFF9B5EFF),
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                  ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Logout',
            onPressed: _isLoggingOut
                ? null
                : _showLogoutConfirmation,
            style: IconButton.styleFrom(
              backgroundColor:
                  Colors.red.withOpacity(0.10),
              foregroundColor:
                  Colors.red.shade400,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
            ),
            icon: _isLoggingOut
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child:
                        CircularProgressIndicator(
                      color: Colors.red,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.logout_rounded,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required double horizontalPadding,
    required bool isDark,
    required bool isTablet,
  }) {
    if (_isLoading && _deliveries.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF9B5EFF),
        ),
      );
    }

    if (_errorMessage != null &&
        _deliveries.isEmpty) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF9B5EFF),
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          16,
          horizontalPadding,
          30,
        ),
        children: [
          _buildWelcomeCard(isTablet),
          const SizedBox(height: 16),
          _buildStatsGrid(
            isDark: isDark,
            isTablet: isTablet,
          ),
          const SizedBox(height: 18),
          _buildFilterChips(isDark),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _buildInlineError(),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_filteredDeliveries.length} pengiriman ditemukan',
                  style: GoogleFonts.inter(
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color,
                    fontSize: 10,
                  ),
                ),
              ),
              Text(
                _filterLabel(_selectedFilter),
                style: GoogleFonts.inter(
                  color:
                      const Color(0xFF9B5EFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _buildDeliveryList(isDark),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(
        isTablet ? 22 : 16,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF9B5EFF),
            Color(0xFF6C3BD8),
          ],
        ),
        borderRadius:
            BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFF9B5EFF)
                    .withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat Bekerja, '
                  '${_driver?.name ?? 'Driver'}!',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize:
                        isTablet ? 21 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_activeCount pengiriman aktif • '
                  '$_todayAssignedCount tugas ditugaskan hari ini',
                  style: GoogleFonts.inter(
                    color:
                        Colors.white.withOpacity(0.88),
                    fontSize:
                        isTablet ? 14 : 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: isTablet ? 58 : 46,
            height: isTablet ? 58 : 46,
            decoration: BoxDecoration(
              color:
                  Colors.white.withOpacity(0.18),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.delivery_dining_rounded,
              color: Colors.white,
              size: isTablet ? 31 : 25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid({
    required bool isDark,
    required bool isTablet,
  }) {
    final stats = [
      _DriverStat(
        title: 'Ditugaskan',
        value: _assignedCount.toString(),
        icon:
            Icons.assignment_ind_outlined,
        color: const Color(0xFFFF9800),
      ),
      _DriverStat(
        title: 'Sudah Diambil',
        value: _pickedUpCount.toString(),
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF2196F3),
      ),
      _DriverStat(
        title: 'Sedang Dikirim',
        value: _onDeliveryCount.toString(),
        icon:
            Icons.local_shipping_outlined,
        color: const Color(0xFF3F51B5),
      ),
      _DriverStat(
        title: 'Selesai',
        value: _deliveredCount.toString(),
        icon:
            Icons.check_circle_outline_rounded,
        color: const Color(0xFF4CAF50),
      ),
    ];

    final theme = Theme.of(context);

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 4 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio:
            isTablet ? 1.45 : 1.35,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];

        return Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius:
                BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF1E1E35)
                  : const Color(0xFFE5E7EB),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(0.05),
                      blurRadius: 9,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      stat.color.withOpacity(0.11),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Icon(
                  stat.icon,
                  color: stat.color,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                stat.title,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: theme
                      .textTheme
                      .bodySmall
                      ?.color,
                  fontSize: 10,
                ),
              ),
              Text(
                stat.value,
                style: GoogleFonts.poppins(
                  color: theme
                      .textTheme
                      .titleLarge
                      ?.color,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics:
            const BouncingScrollPhysics(),
        itemCount: _filters.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final selected =
              _selectedFilter == filter.value;

          return ChoiceChip(
            selected: selected,
            onSelected: (_) {
              setState(() {
                _selectedFilter =
                    filter.value;
              });
            },
            label: Text(
              filter.label,
              style: GoogleFonts.inter(
                color: selected
                    ? Colors.white
                    : theme
                        .textTheme
                        .bodyMedium
                        ?.color,
                fontSize: 10,
                fontWeight: selected
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
            selectedColor:
                const Color(0xFF9B5EFF),
            backgroundColor: isDark
                ? const Color(0xFF16162A)
                : Colors.white,
            side: BorderSide(
              color: selected
                  ? const Color(0xFF9B5EFF)
                  : isDark
                      ? const Color(0xFF1E1E35)
                      : const Color(0xFFE5E7EB),
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(11),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildDeliveryList(bool isDark) {
    final deliveries = _filteredDeliveries;

    if (deliveries.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        return _buildDeliveryCard(
          delivery: deliveries[index],
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildDeliveryCard({
    required DriverDeliveryModel delivery,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final order = delivery.order;
    final color =
        _statusColor(delivery.status);
    final processing =
        _processingDeliveryId == delivery.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: processing
            ? null
            : () {
                _openDeliveryDetail(delivery);
              },
        borderRadius:
            BorderRadius.circular(15),
        child: Container(
          margin: const EdgeInsets.only(bottom: 11),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius:
                BorderRadius.circular(15),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF1E1E35)
                  : const Color(0xFFE5E7EB),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black
                          .withOpacity(0.05),
                      blurRadius: 9,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color:
                          color.withOpacity(0.11),
                      borderRadius:
                          BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _statusIcon(
                        delivery.status,
                      ),
                      color: color,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          delivery.orderNumber,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: theme
                                .textTheme
                                .titleLarge
                                ?.color,
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          order?.customerName ??
                              'Customer',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: theme
                                .textTheme
                                .bodyMedium
                                ?.color,
                            fontSize: 10,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (processing)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        color:
                            Color(0xFF9B5EFF),
                        strokeWidth: 2,
                      ),
                    )
                  else
                    _statusBadge(
                      label: _statusLabel(
                        delivery.status,
                      ),
                      color: color,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: theme
                        .textTheme
                        .bodySmall
                        ?.color,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order?.fullAddress ??
                          'Alamat tidak tersedia',
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: theme
                            .textTheme
                            .bodySmall
                            ?.color,
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  _smallInfo(
                    icon:
                        Icons.inventory_2_outlined,
                    text:
                        '${order?.totalQuantity ?? 0} item',
                    isDark: isDark,
                  ),
                  const SizedBox(width: 7),
                  _smallInfo(
                    icon: Icons.payment_outlined,
                    text:
                        _paymentStatusLabel(
                      order?.paymentStatus ??
                          '-',
                    ),
                    isDark: isDark,
                  ),
                  const Spacer(),
                  Text(
                    'Rp ${_formatPrice(order?.grandTotal ?? 0)}',
                    style: GoogleFonts.poppins(
                      color:
                          const Color(0xFF9B5EFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ditugaskan '
                      '${_formatDateTime(delivery.sortDate)}',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: theme
                            .textTheme
                            .bodySmall
                            ?.color,
                        fontSize: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Lihat Detail',
                    style: GoogleFonts.inter(
                      color:
                          const Color(0xFF9B5EFF),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF9B5EFF),
                    size: 17,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallInfo({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E35)
            : const Color(0xFFF7F7FB),
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color:
                theme.textTheme.bodySmall?.color,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              color:
                  theme.textTheme.bodySmall?.color,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.22),
        ),
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

  String _filterLabel(String value) {
    for (final filter in _filters) {
      if (filter.value == value) {
        return filter.label;
      }
    }

    return 'Semua';
  }

  Widget _buildInlineError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            Colors.orange.withOpacity(0.10),
        borderRadius:
            BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade500,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(
                color:
                    Colors.orange.shade600,
                fontSize: 11,
              ),
            ),
          ),
          TextButton(
            onPressed: _refresh,
            child: const Text('Ulangi'),
          ),
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
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context)
                    .size
                    .height *
                0.72,
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color:
                          Colors.red.shade300,
                      size: 64,
                    ),
                    const SizedBox(height: 17),
                    Text(
                      'Pengiriman gagal dimuat',
                      style:
                          GoogleFonts.poppins(
                        color: theme
                            .textTheme
                            .titleLarge
                            ?.color,
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ??
                          'Terjadi kesalahan saat mengambil pengiriman.',
                      textAlign:
                          TextAlign.center,
                      style: GoogleFonts.inter(
                        color: theme
                            .textTheme
                            .bodySmall
                            ?.color,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () {
                        _loadDashboard();
                      },
                      icon: const Icon(
                        Icons.refresh_rounded,
                      ),
                      label: const Text(
                        'Coba Lagi',
                      ),
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(
                          0xFF9B5EFF,
                        ),
                        foregroundColor:
                            Colors.white,
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

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 46,
        horizontal: 24,
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            color:
                theme.textTheme.bodySmall?.color,
            size: 62,
          ),
          const SizedBox(height: 15),
          Text(
            _deliveries.isEmpty
                ? 'Belum Ada Pengiriman'
                : 'Pengiriman Tidak Ditemukan',
            style: GoogleFonts.poppins(
              color:
                  theme.textTheme.titleLarge?.color,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _deliveries.isEmpty
                ? 'Tugas yang diberikan cashier atau owner akan muncul di sini.'
                : 'Coba pilih filter status yang lain.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color:
                  theme.textTheme.bodySmall?.color,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (_deliveries.isNotEmpty) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedFilter = 'all';
                });
              },
              icon: const Icon(
                Icons.restart_alt_rounded,
              ),
              label: const Text(
                'Reset Filter',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DriverFilter {
  final String value;
  final String label;

  const _DriverFilter({
    required this.value,
    required this.label,
  });
}

class _DriverStat {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _DriverStat({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _StatusUpdateResult {
  final String notes;

  const _StatusUpdateResult({
    required this.notes,
  });
}
