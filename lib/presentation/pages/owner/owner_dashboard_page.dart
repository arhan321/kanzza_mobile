import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../data/models/owner_dashboard.dart';
import '../../../data/repositories/owner_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../routes.dart';
import 'owner_manage_role_page.dart';
import 'owner_orders_page.dart';
import 'owner_products_page.dart';
import 'owner_reports_page.dart';

class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({super.key});

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  static const _primary = Color(0xFF9B5EFF);
  final OwnerRepository _repository = OwnerRepository();
  final UserRepository _userRepository = UserRepository();
  OwnerDashboardModel? _dashboard;
  String _period = 'today';
  int _analysisTab = 0;
  bool _isLoading = true;
  bool _isLoggingOut = false;
  String? _errorMessage;

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
      final dashboard = await _repository.getDashboard(period: _period);
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
        _errorMessage = 'Dashboard owner belum dapat dimuat: $error';
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isLoggingOut = true);
    await _userRepository.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await _loadDashboard();
  }

  void _showAttention() {
    final data = _dashboard;
    if (data == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .68),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Perlu Perhatian', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
                Text('${data.attentionCount} hal perlu ditindaklanjuti', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (data.pendingOrders > 0)
                        ListTile(
                          tileColor: const Color(0xFF3C9FE8).withValues(alpha: .08),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          leading: const Icon(Icons.pending_actions_rounded, color: Color(0xFF3C9FE8)),
                          title: Text('${data.pendingOrders} pesanan perlu diproses'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.pop(context);
                            _push(const OwnerOrdersPage());
                          },
                        ),
                      if (data.pendingOrders > 0 && data.lowStockProducts.isNotEmpty) const SizedBox(height: 8),
                      ...data.lowStockProducts.map((product) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          tileColor: const Color(0xFFEF5350).withValues(alpha: .08),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF5350)),
                          title: Text(product.name),
                          subtitle: Text('Sisa ${product.stock} ${product.unit} • minimum ${product.minimumStock}'),
                          trailing: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _push(const OwnerProductsPage());
                            },
                            child: const Text('Restock'),
                          ),
                        ),
                      )),
                      if (data.attentionCount == 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 34),
                          child: Center(child: Text('Semua aman. Tidak ada perhatian baru.')),
                        ),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080817) : const Color(0xFFF5F4FA),
      body: SafeArea(
        child: Column(
          children: [
            _header(isDark),
            Expanded(child: _body(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _header(bool isDark) {
    final count = _dashboard?.attentionCount ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        Expanded(child: Text('Dashboard Owner', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700))),
        const ThemeToggleButton(size: 48),
        const SizedBox(width: 8),
        _HeaderAction(
          icon: Icons.notifications_none_rounded,
          isDark: isDark,
          badge: count,
          onTap: _showAttention,
        ),
        const SizedBox(width: 8),
        _HeaderAction(
          icon: Icons.logout_rounded,
          isDark: isDark,
          danger: true,
          loading: _isLoggingOut,
          onTap: _logout,
        ),
      ]),
    );
  }

  Widget _body(bool isDark) {
    if (_isLoading && _dashboard == null) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_errorMessage != null && _dashboard == null) {
      return _ErrorView(message: _errorMessage!, onRetry: _loadDashboard);
    }
    final data = _dashboard;
    if (data == null) return _ErrorView(message: 'Data dashboard belum tersedia.', onRetry: _loadDashboard);
    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
        children: [
          _welcome(data),
          const SizedBox(height: 18),
          _periodSelector(),
          const SizedBox(height: 20),
          _metrics(data, isDark),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: Color(0xFFEF5350))),
          ],
          const SizedBox(height: 30),
          _sectionTitle('Analisis Data Penjualan'),
          const SizedBox(height: 12),
          _analysisTabs(),
          const SizedBox(height: 12),
          _analysis(data, isDark),
          const SizedBox(height: 28),
          _sectionTitle('Top 5 Produk Terlaris'),
          const SizedBox(height: 12),
          _topProducts(data, isDark),
          const SizedBox(height: 28),
          _lowStock(data, isDark),
          const SizedBox(height: 28),
          _sectionTitle('Menu Manajemen'),
          const SizedBox(height: 12),
          _managementMenu(isDark),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(child: _sectionTitle('Pesanan Terbaru')),
            TextButton(onPressed: () => _push(const OwnerOrdersPage()), child: const Text('Lihat semua')),
          ]),
          const SizedBox(height: 8),
          _recentOrders(data, isDark),
        ],
      ),
    );
  }

  Widget _welcome(OwnerDashboardModel data) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFA85BFF), Color(0xFF7034E8)]),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: _primary.withValues(alpha: .3), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Selamat bekerja, Owner! 👋', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text('Total pendapatan periode ini: ${_compactRupiah(data.revenue)}', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: .88))),
          ])),
          Container(width: 54, height: 54, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .17), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 30)),
        ]),
      );

  Widget _periodSelector() => Row(children: [
        Expanded(child: _PeriodButton(label: 'Hari Ini', selected: _period == 'today', onTap: () => _changePeriod('today'))),
        const SizedBox(width: 10),
        Expanded(child: _PeriodButton(label: 'Minggu Ini', selected: _period == 'week', onTap: () => _changePeriod('week'))),
        const SizedBox(width: 10),
        Expanded(child: _PeriodButton(label: 'Bulan Ini', selected: _period == 'month', onTap: () => _changePeriod('month'))),
      ]);

  void _changePeriod(String value) {
    if (_period == value) return;
    setState(() => _period = value);
    _loadDashboard();
  }

  Widget _metrics(OwnerDashboardModel data, bool isDark) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.28,
        children: [
          _MetricCard(label: 'Total Pendapatan', value: _compactRupiah(data.revenue), helper: '${data.transactions} pesanan', icon: Icons.attach_money_rounded, color: const Color(0xFF3EAE68), badge: _growth(data.revenueGrowthPercent), isDark: isDark),
          _MetricCard(label: 'Rata-rata Pesanan', value: _compactRupiah(data.averageOrder), helper: '${data.itemsSold} item terjual', icon: Icons.shopping_cart_outlined, color: _primary, badge: '${data.transactions}x', isDark: isDark),
          _MetricCard(label: 'Retensi Pelanggan', value: '${data.customerRetentionPercent.toStringAsFixed(1)}%', helper: '${data.activeCustomers} pelanggan aktif', icon: Icons.people_outline_rounded, color: const Color(0xFF3C9FE8), badge: '${data.repeatCustomers} repeat', isDark: isDark),
          _MetricCard(label: 'Perputaran Stok', value: data.stockTurnover.toStringAsFixed(2), helper: '${data.totalProducts} produk', icon: Icons.inventory_2_outlined, color: const Color(0xFFF4A62A), badge: '${data.itemsSold} item', isDark: isDark),
        ],
      );

  Widget _analysisTabs() => Row(children: [
        Expanded(child: _TabButton(label: 'Penjualan', selected: _analysisTab == 0, onTap: () => setState(() => _analysisTab = 0))),
        const SizedBox(width: 9),
        Expanded(child: _TabButton(label: 'Kategori', selected: _analysisTab == 1, onTap: () => setState(() => _analysisTab = 1))),
        const SizedBox(width: 9),
        Expanded(child: _TabButton(label: 'Pelanggan', selected: _analysisTab == 2, onTap: () => setState(() => _analysisTab = 2))),
      ]);

  Widget _analysis(OwnerDashboardModel data, bool isDark) {
    if (_analysisTab == 1) return _categoryAnalysis(data, isDark);
    if (_analysisTab == 2) return _customerAnalysis(data, isDark);
    return _Surface(
      isDark: isDark,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('💰'),
          const SizedBox(width: 7),
          Expanded(child: Text('Tren Penjualan', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
          _Badge(label: _growth(data.revenueGrowthPercent), color: data.revenueGrowthPercent >= 0 ? const Color(0xFF3EAE68) : const Color(0xFFEF5350)),
        ]),
        const SizedBox(height: 18),
        SizedBox(height: 190, child: _SalesChart(points: data.salesTrend, isDark: isDark)),
      ]),
    );
  }

  Widget _categoryAnalysis(OwnerDashboardModel data, bool isDark) {
    if (data.categorySales.isEmpty) return _emptyAnalysis('Belum ada penjualan kategori.', isDark);
    final maxValue = data.categorySales
        .map((item) => item.totalSales)
        .fold<int>(0, (current, value) => math.max(current, value));
    return _Surface(
      isDark: isDark,
      child: Column(children: data.categorySales.map((item) {
        final ratio = maxValue == 0 ? 0.0 : item.totalSales / maxValue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(children: [
            Row(children: [Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600))), Text(_compactRupiah(item.totalSales), style: const TextStyle(color: _primary, fontWeight: FontWeight.w700))]),
            const SizedBox(height: 7),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: ratio, minHeight: 8, backgroundColor: _primary.withValues(alpha: .1), color: _primary)),
          ]),
        );
      }).toList(growable: false)),
    );
  }

  Widget _customerAnalysis(OwnerDashboardModel data, bool isDark) => _Surface(
        isDark: isDark,
        child: Column(children: [
          _CustomerRow(icon: Icons.people_alt_outlined, label: 'Pelanggan aktif', value: '${data.activeCustomers}', color: const Color(0xFF3C9FE8)),
          const Divider(height: 24),
          _CustomerRow(icon: Icons.replay_rounded, label: 'Pelanggan berulang', value: '${data.repeatCustomers}', color: const Color(0xFF3EAE68)),
          const Divider(height: 24),
          _CustomerRow(icon: Icons.person_add_alt_rounded, label: 'Pelanggan baru', value: '${data.newCustomers}', color: _primary),
          const Divider(height: 24),
          _CustomerRow(icon: Icons.favorite_outline_rounded, label: 'Tingkat retensi', value: '${data.customerRetentionPercent.toStringAsFixed(1)}%', color: const Color(0xFFEF5350)),
        ]),
      );

  Widget _emptyAnalysis(String message, bool isDark) => _Surface(isDark: isDark, child: Padding(padding: const EdgeInsets.symmetric(vertical: 34), child: Center(child: Text(message))));

  Widget _topProducts(OwnerDashboardModel data, bool isDark) {
    if (data.topProducts.isEmpty) return _emptyAnalysis('Belum ada produk terjual pada periode ini.', isDark);
    return _Surface(
      isDark: isDark,
      child: Column(children: data.topProducts.asMap().entries.map((entry) {
        final item = entry.value;
        return Column(children: [
          if (entry.key > 0) const Divider(height: 22),
          Row(children: [
            Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: entry.key == 0 ? const Color(0xFFFFD95A).withValues(alpha: .25) : Colors.grey.withValues(alpha: .1), borderRadius: BorderRadius.circular(11)), child: Text('${entry.key + 1}', style: TextStyle(color: entry.key == 0 ? const Color(0xFFD99B00) : null, fontWeight: FontWeight.w700))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)), Text('${item.totalQuantity} terjual', style: Theme.of(context).textTheme.bodySmall)])),
            Text(_compactRupiah(item.totalSales), style: GoogleFonts.poppins(color: _primary, fontWeight: FontWeight.w700)),
          ]),
        ]);
      }).toList(growable: false)),
    );
  }

  Widget _lowStock(OwnerDashboardModel data, bool isDark) {
    if (data.lowStockProducts.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('⚠️ Alert Stok Menipis'),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFEF5350).withValues(alpha: isDark ? .1 : .055), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFEF5350).withValues(alpha: .25))),
        child: Column(children: data.lowStockProducts.take(5).map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFEF5350).withValues(alpha: .11), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF5350))),
            const SizedBox(width: 11),
            Expanded(child: Text(item.name, maxLines: 2, style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
            _Badge(label: 'Sisa ${item.stock} ${item.unit}', color: const Color(0xFFEF5350)),
            const SizedBox(width: 7),
            FilledButton(onPressed: () => _push(const OwnerProductsPage()), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)), child: const Text('Restock')),
          ]),
        )).toList(growable: false)),
      ),
    ]);
  }

  Widget _managementMenu(bool isDark) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.03,
        children: [
          _MenuCard(title: 'Kelola Produk', subtitle: 'Tambah, edit, hapus produk', icon: Icons.inventory_2_outlined, color: _primary, isDark: isDark, onTap: () => _push(const OwnerProductsPage())),
          _MenuCard(title: 'Laporan Penjualan', subtitle: 'Lihat laporan & analisis', icon: Icons.analytics_outlined, color: const Color(0xFF3EAE68), isDark: isDark, onTap: () => _push(const OwnerReportsPage())),
          _MenuCard(title: 'Manajemen User', subtitle: 'Kelola akses karyawan', icon: Icons.people_outline_rounded, color: const Color(0xFF3C9FE8), isDark: isDark, onTap: () => _push(const OwnerManageRolePage())),
          _MenuCard(title: 'Pesanan Online', subtitle: 'Proses operasional order', icon: Icons.receipt_long_outlined, color: const Color(0xFFF4A62A), isDark: isDark, onTap: () => _push(const OwnerOrdersPage())),
        ],
      );

  Widget _recentOrders(OwnerDashboardModel data, bool isDark) {
    if (data.recentOrders.isEmpty) return _emptyAnalysis('Belum ada pesanan terbaru.', isDark);
    return Column(children: data.recentOrders.map((order) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Surface(
        isDark: isDark,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Flexible(child: Text(order.orderNumber, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontWeight: FontWeight.w600))), const SizedBox(width: 7), _Badge(label: _status(order.orderStatus), color: _statusColor(order.orderStatus))]),
            const SizedBox(height: 4),
            Text(order.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_compactRupiah(order.grandTotal), style: GoogleFonts.poppins(color: _primary, fontWeight: FontWeight.w700)),
            Text(order.createdAt == null ? '-' : DateFormat('dd MMM yyyy').format(order.createdAt!.toLocal()), style: Theme.of(context).textTheme.bodySmall),
          ]),
        ]),
      ),
    )).toList(growable: false));
  }

  Widget _sectionTitle(String value) => Text(value, style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700));
  String _growth(double value) => '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%';
  String _compactRupiah(int value) => NumberFormat.compactCurrency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: value >= 1000000 ? 1 : 0).format(value);
  static String _status(String value) => value.split('_').map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
  static Color _statusColor(String status) => switch (status) {
    'delivered' => const Color(0xFF3EAE68),
    'cancelled' => const Color(0xFFEF5350),
    'processing' || 'confirmed' => _primary,
    _ => const Color(0xFF3C9FE8),
  };
}

class _Surface extends StatelessWidget {
  const _Surface({required this.isDark, required this.child, this.padding = const EdgeInsets.all(18)});
  final bool isDark;
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16162A) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isDark ? null : [BoxShadow(color: const Color(0xFF251354).withValues(alpha: .05), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: child,
      );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.isDark, required this.onTap, this.badge = 0, this.danger = false, this.loading = false});
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final int badge;
  final bool danger;
  final bool loading;
  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        Material(
          color: danger ? const Color(0xFFEF5350).withValues(alpha: .1) : (isDark ? const Color(0xFF16162A) : const Color(0xFFF7F6FB)),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: loading ? null : onTap,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(width: 48, height: 48, child: Center(child: loading ? const SizedBox.square(dimension: 19, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon, color: danger ? const Color(0xFFEF5350) : null))),
          ),
        ),
        if (badge > 0)
          Positioned(right: -2, top: -3, child: Container(padding: const EdgeInsets.all(4), constraints: const BoxConstraints(minWidth: 18, minHeight: 18), decoration: const BoxDecoration(color: Color(0xFFEF5350), shape: BoxShape.circle), child: Text(badge > 99 ? '99+' : '$badge', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)))),
      ]);
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: selected ? _OwnerDashboardPageState._primary : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Padding(padding: const EdgeInsets.symmetric(vertical: 13), child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: selected ? Colors.white : null, fontWeight: FontWeight.w600)))),
      );
}

class _TabButton extends _PeriodButton {
  const _TabButton({required super.label, required super.selected, required super.onTap});
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.helper, required this.icon, required this.color, required this.badge, required this.isDark});
  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color color;
  final String badge;
  final bool isDark;
  @override
  Widget build(BuildContext context) => _Surface(
        isDark: isDark,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)), Flexible(child: _Badge(label: badge, color: color))]),
          const Spacer(),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700)),
          Text(helper, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(7)), child: Text(label, maxLines: 1, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)));
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)), const SizedBox(width: 12), Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))), Text(value, style: GoogleFonts.poppins(color: color, fontSize: 18, fontWeight: FontWeight.w700))]);
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.isDark, required this.onTap});
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _Surface(
        isDark: isDark,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 54, height: 54, decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color, size: 28)),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(subtitle, textAlign: TextAlign.center, maxLines: 2, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}

class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.points, required this.isDark});
  final List<OwnerTrendPointModel> points;
  final bool isDark;
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const Center(child: Text('Belum ada data tren.'));
    return Column(children: [
      Expanded(child: CustomPaint(painter: _SalesChartPainter(values: points.map((item) => item.value.toDouble()).toList(), isDark: isDark), child: const SizedBox.expand())),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: points.map((item) => Flexible(child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall))).toList(growable: false)),
    ]);
  }
}

class _SalesChartPainter extends CustomPainter {
  const _SalesChartPainter({required this.values, required this.isDark});
  final List<double> values;
  final bool isDark;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = (isDark ? Colors.white : Colors.black).withValues(alpha: .08)..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final maxValue = values.fold<double>(
      0,
      (current, value) => math.max(current, value),
    );
    final path = Path();
    final fill = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : size.width * i / (values.length - 1);
      final y = maxValue == 0 ? size.height * .72 : size.height - (values[i] / maxValue * size.height * .82) - 5;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4.5, Paint()..color = _OwnerDashboardPageState._primary);
    }
    fill.lineTo(size.width, size.height);
    fill.close();
    canvas.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_OwnerDashboardPageState._primary.withValues(alpha: .28), _OwnerDashboardPageState._primary.withValues(alpha: .02)]).createShader(Offset.zero & size));
    canvas.drawPath(path, Paint()..color = _OwnerDashboardPageState._primary..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }
  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) => oldDelegate.values != values || oldDelegate.isDark != isDark;
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_rounded, size: 52), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center), const SizedBox(height: 15), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Coba lagi'))])));
}
