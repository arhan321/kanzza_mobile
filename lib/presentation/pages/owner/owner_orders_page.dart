import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/customer_order.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/customer_order_repository.dart';
import '../../../data/repositories/owner_repository.dart';

class OwnerOrdersPage extends StatefulWidget {
  const OwnerOrdersPage({
    super.key,
    this.canAssignDrivers = true,
    this.title = 'Operasional Pesanan',
  });

  final bool canAssignDrivers;
  final String title;

  @override
  State<OwnerOrdersPage> createState() => _OwnerOrdersPageState();
}

class _OwnerOrdersPageState extends State<OwnerOrdersPage> {
  final CustomerOrderRepository _orderRepository = CustomerOrderRepository();
  final OwnerRepository _ownerRepository = OwnerRepository();

  final List<CustomerOrderModel> _orders = [];
  final List<UserModel> _drivers = [];
  bool _isLoading = true;
  bool _showCompleted = false;
  int? _processingOrderId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        _orderRepository.getOrders(perPage: 100),
        if (widget.canAssignDrivers)
          _ownerRepository.getUsers(
            role: 'driver',
            status: 'active',
            perPage: 100,
          ),
      ]);

      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(results[0] as List<CustomerOrderModel>);
        _drivers.clear();
        if (widget.canAssignDrivers) {
          _drivers.addAll(results[1] as List<UserModel>);
        }
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.firstValidationError;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Pesanan operasional gagal dimuat: $error';
      });
    }
  }

  List<CustomerOrderModel> get _visibleOrders {
    return _orders
        .where((order) {
          final completed = const {
            'delivered',
            'cancelled',
          }.contains(order.orderStatus);
          return _showCompleted ? completed : !completed;
        })
        .toList(growable: false);
  }

  Future<void> _updateStatus(CustomerOrderModel order, String status) async {
    if (_processingOrderId != null) return;
    setState(() => _processingOrderId = order.id);

    try {
      await _orderRepository.updateOrderStatus(
        orderId: order.id,
        status: status,
      );
      if (!mounted) return;
      _showMessage('Status ${order.orderNumber} berhasil diperbarui.');
      await _loadData();
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.firstValidationError, isError: true);
    } catch (error) {
      if (mounted) {
        _showMessage('Status pesanan gagal diperbarui: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _processingOrderId = null);
    }
  }

  Future<void> _selectAndAssignDriver(CustomerOrderModel order) async {
    if (_drivers.isEmpty) {
      _showMessage(
        'Belum ada driver aktif. Aktifkan akun driver terlebih dahulu.',
        isError: true,
      );
      return;
    }

    final driver = await showModalBottomSheet<UserModel>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Pilih driver untuk ${order.orderNumber}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _drivers
                    .map(
                      (driver) => ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.delivery_dining_rounded),
                        ),
                        title: Text(driver.name),
                        subtitle: Text(driver.phone ?? driver.email),
                        onTap: () => Navigator.pop(context, driver),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );

    if (driver == null || !mounted || _processingOrderId != null) return;
    setState(() => _processingOrderId = order.id);

    try {
      await _orderRepository.assignDriver(
        orderId: order.id,
        driverId: driver.id,
      );
      if (!mounted) return;
      _showMessage('${driver.name} ditugaskan ke ${order.orderNumber}.');
      await _loadData();
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.firstValidationError, isError: true);
    } catch (error) {
      if (mounted) {
        _showMessage('Driver gagal ditugaskan: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _processingOrderId = null);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Colors.red.shade600
              : Colors.green.shade600,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadData,
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final orders = _visibleOrders;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Aktif'),
                icon: Icon(Icons.pending_actions_rounded),
              ),
              ButtonSegment(
                value: true,
                label: Text('Selesai'),
                icon: Icon(Icons.history_rounded),
              ),
            ],
            selected: {_showCompleted},
            onSelectionChanged: (value) {
              setState(() => _showCompleted = value.first);
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_errorMessage!),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (orders.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Text(
                  'Tidak ada pesanan pada kelompok ini.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...orders.map(_buildOrderCard),
        ],
      ),
    );
  }

  Widget _buildOrderCard(CustomerOrderModel order) {
    final isProcessing = _processingOrderId == order.id;
    final nextStatus = _nextStatus(order);
    final isReadyDelivery = order.orderStatus == 'ready' && !order.isPickup;
    final canAssign = isReadyDelivery && widget.canAssignDrivers;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusChip(
                  label: _statusLabel(order.orderStatus),
                  color: _statusColor(order.orderStatus),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(order.customer?.name ?? 'Customer'),
            const SizedBox(height: 3),
            Text(
              '${order.isCod ? 'COD' : 'Midtrans'} • '
              '${order.isPickup ? 'Ambil di toko' : 'Delivery'} • '
              '${_paymentLabel(order)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 3),
            Text(
              DateFormat(
                'dd MMM yyyy, HH:mm',
              ).format((order.createdAt ?? DateTime.now()).toLocal()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(order.grandTotal),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (isProcessing)
                  const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (canAssign)
                  FilledButton.icon(
                    onPressed: () => _selectAndAssignDriver(order),
                    icon: const Icon(Icons.delivery_dining_rounded),
                    label: const Text('Pilih Driver'),
                  )
                else if (nextStatus != null)
                  FilledButton(
                    onPressed: () => _updateStatus(order, nextStatus),
                    child: Text(_nextActionLabel(nextStatus)),
                  ),
              ],
            ),
            if (isReadyDelivery && !widget.canAssignDrivers) ...[
              const SizedBox(height: 8),
              Text(
                'Pesanan siap. Penugasan driver dilakukan oleh owner.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _nextStatus(CustomerOrderModel order) {
    switch (order.orderStatus) {
      case 'confirmed':
        return 'processing';
      case 'processing':
        return 'ready';
      case 'ready' when order.isPickup:
        return 'delivered';
      default:
        return null;
    }
  }

  String _nextActionLabel(String status) {
    switch (status) {
      case 'processing':
        return 'Mulai Proses';
      case 'ready':
        return 'Tandai Siap';
      case 'delivered':
        return 'Selesaikan';
      default:
        return 'Perbarui';
    }
  }

  String _paymentLabel(CustomerOrderModel order) {
    if (order.isPaid) return 'Lunas';
    if (order.isCod && order.orderStatus != 'cancelled') {
      return 'Bayar ke driver';
    }
    return order.paymentStatus == 'cancelled' ? 'Dibatalkan' : 'Belum dibayar';
  }

  String _statusLabel(String status) {
    switch (status) {
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
        return 'Dalam Perjalanan';
      case 'delivered':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.deepPurple;
      case 'ready':
        return Colors.teal;
      case 'assigned':
      case 'picked_up':
      case 'on_delivery':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
