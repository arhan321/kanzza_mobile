import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/customer_order.dart';
import '../../../data/repositories/customer_order_repository.dart';

class OwnerReportsPage extends StatefulWidget {
  const OwnerReportsPage({super.key});

  @override
  State<OwnerReportsPage> createState() => _OwnerReportsPageState();
}

class _OwnerReportsPageState extends State<OwnerReportsPage> {
  final CustomerOrderRepository _repository = CustomerOrderRepository();
  final List<CustomerOrderModel> _orders = [];

  bool _isLoading = true;
  String? _errorMessage;
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  String? _channelFilter;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await _repository.getOrders(perPage: 100);
      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(orders);
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
        _errorMessage = 'Laporan gagal dimuat: $error';
      });
    }
  }

  List<CustomerOrderModel> get _filteredOrders {
    final start = DateTime(
      _range.start.year,
      _range.start.month,
      _range.start.day,
    );
    final end = DateTime(
      _range.end.year,
      _range.end.month,
      _range.end.day,
      23,
      59,
      59,
    );
    return _orders
        .where((order) {
          final date = order.paidAt ?? order.createdAt;
          if (date == null || date.isBefore(start) || date.isAfter(end)) {
            return false;
          }
          if (_channelFilter != null && order.channel != _channelFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<CustomerOrderModel> get _paidOrders =>
      _filteredOrders.where((order) => order.isPaid).toList(growable: false);

  int get _revenue =>
      _paidOrders.fold(0, (total, order) => total + order.grandTotal);
  int get _itemsSold =>
      _paidOrders.fold(0, (total, order) => total + order.totalQuantity);

  Future<void> _selectRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (selected != null && mounted) setState(() => _range = selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _isLoading ? null : _loadOrders,
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
                onPressed: _loadOrders,
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final orders = _filteredOrders;
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.date_range_rounded),
                    title: const Text('Periode laporan'),
                    subtitle: Text(
                      '${DateFormat('dd MMM yyyy').format(_range.start)} - '
                      '${DateFormat('dd MMM yyyy').format(_range.end)}',
                    ),
                    trailing: TextButton(
                      onPressed: _selectRange,
                      child: const Text('Ubah'),
                    ),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: _channelFilter,
                    decoration: const InputDecoration(
                      labelText: 'Kanal transaksi',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'online', child: Text('Online')),
                      DropdownMenuItem(value: 'cashier', child: Text('Kasir')),
                    ],
                    onChanged: (value) =>
                        setState(() => _channelFilter = value),
                  ),
                  if (_channelFilter != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _channelFilter = null),
                        child: const Text('Tampilkan semua kanal'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              _ReportMetric(
                label: 'Pendapatan',
                value: _rupiah(_revenue),
                icon: Icons.payments_outlined,
              ),
              _ReportMetric(
                label: 'Transaksi lunas',
                value: '${_paidOrders.length}',
                icon: Icons.receipt_long_outlined,
              ),
              _ReportMetric(
                label: 'Item terjual',
                value: '$_itemsSold',
                icon: Icons.shopping_bag_outlined,
              ),
              _ReportMetric(
                label: 'Rata-rata order',
                value: _rupiah(
                  _paidOrders.isEmpty
                      ? 0
                      : (_revenue / _paidOrders.length).round(),
                ),
                icon: Icons.analytics_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Transaksi (${orders.length})',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (orders.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Tidak ada transaksi pada periode ini.'),
              ),
            )
          else
            ...orders.map(
              (order) => Card(
                child: ListTile(
                  leading: Icon(
                    order.channel == 'cashier'
                        ? Icons.storefront_outlined
                        : Icons.phone_android_rounded,
                  ),
                  title: Text(order.orderNumber),
                  subtitle: Text(
                    '${order.channel == 'cashier' ? 'Kasir' : 'Online'} • '
                    '${order.paymentStatus}\n'
                    '${DateFormat('dd MMM yyyy HH:mm').format(order.paidAt ?? order.createdAt ?? DateTime.now())}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    _rupiah(order.grandTotal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Laporan menggunakan maksimal 100 transaksi terbaru yang tersedia dari API.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _rupiah(int value) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(value);
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
