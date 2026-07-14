import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/owner_dashboard.dart';
import '../../../data/repositories/owner_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../routes.dart';
import 'owner_manage_role_page.dart';
import 'owner_products_page.dart';
import 'owner_reports_page.dart';

class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({super.key});

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  final OwnerRepository _ownerRepository = OwnerRepository();
  final UserRepository _userRepository = UserRepository();

  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isLoggingOut = false;
  String? _errorMessage;
  OwnerDashboardModel? _dashboard;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final dashboard = await _ownerRepository.getDashboard();

      if (!mounted) return;

      setState(() {
        _dashboard = dashboard;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _redirectToLogin();
        return;
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.firstValidationError;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Dashboard owner gagal dimuat: $error';
      });
    }
  }

  Future<void> _redirectToLogin() async {
    await _userRepository.clearLocalSession();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari aplikasi?'),
        content: const Text('Sesi owner pada perangkat ini akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    await _userRepository.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _buildDashboard(),
      const OwnerProductsPage(),
      const OwnerReportsPage(),
      const OwnerManageRolePage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 0) _loadDashboard();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Produk',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment_rounded),
            label: 'Laporan',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'User',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Owner'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _isLoading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: _isLoggingOut ? null : _logout,
            icon: _isLoggingOut
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _buildDashboardBody(),
    );
  }

  Widget _buildDashboardBody() {
    if (_isLoading && _dashboard == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _dashboard == null) {
      return _ErrorState(message: _errorMessage!, onRetry: _loadDashboard);
    }

    final dashboard = _dashboard;
    if (dashboard == null) {
      return _ErrorState(
        message: 'Data dashboard belum tersedia.',
        onRetry: _loadDashboard,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text(
            'Ringkasan hari ini',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            MaterialBanner(
              content: Text(_errorMessage!),
              actions: [
                TextButton(
                  onPressed: _loadDashboard,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _MetricCard(
                label: 'Pendapatan',
                value: _rupiah(dashboard.todayRevenue),
                icon: Icons.payments_outlined,
                color: Colors.green,
              ),
              _MetricCard(
                label: 'Transaksi',
                value: '${dashboard.todayTransactions}',
                icon: Icons.receipt_long_outlined,
                color: Colors.blue,
              ),
              _MetricCard(
                label: 'Pesanan diproses',
                value: '${dashboard.pendingOrders}',
                icon: Icons.pending_actions_outlined,
                color: Colors.orange,
              ),
              _MetricCard(
                label: 'Stok menipis',
                value: '${dashboard.lowStockProducts}',
                icon: Icons.inventory_outlined,
                color: Colors.red,
              ),
              _MetricCard(
                label: 'Customer aktif',
                value: '${dashboard.activeCustomers}',
                icon: Icons.people_outline,
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Produk terlaris',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (dashboard.topProducts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Belum ada transaksi produk yang sudah dibayar.'),
              ),
            )
          else
            ...dashboard.topProducts.asMap().entries.map(
              (entry) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${entry.key + 1}')),
                  title: Text(entry.value.name),
                  subtitle: Text('${entry.value.totalQuantity} item terjual'),
                  trailing: Text(
                    _rupiah(entry.value.totalSales),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _rupiah(int value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
