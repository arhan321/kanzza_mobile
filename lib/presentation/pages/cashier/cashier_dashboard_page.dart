// lib/presentation/pages/cashier/cashier_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../data/models/user.dart';
import '../../../data/models/customer_order.dart';
import '../../../data/repositories/customer_order_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../routes.dart';

class CashierDashboardPage extends StatefulWidget {
  const CashierDashboardPage({super.key});

  @override
  State<CashierDashboardPage> createState() => _CashierDashboardPageState();
}

class _CashierDashboardPageState extends State<CashierDashboardPage> {
  final UserRepository _userRepository = UserRepository();
  final CustomerOrderRepository _orderRepository = CustomerOrderRepository();

  UserModel? _currentUser;
  List<_DashboardTransaction> _transactions = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoggingOut = false;
  String? _errorMessage;

  final List<_CashierMenuItem> _menuItems = const [
    _CashierMenuItem(
      title: 'Transaksi Kasir',
      subtitle: 'Catat penjualan langsung',
      icon: Icons.point_of_sale_rounded,
      color: Color(0xFFFF9800),
      route: AppRoutes.offlineTransaction,
    ),
    _CashierMenuItem(
      title: 'Daftar Produk',
      subtitle: 'Lihat harga dan stok',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF4CAF50),
      route: AppRoutes.cashierProducts,
    ),
    _CashierMenuItem(
      title: 'Riwayat',
      subtitle: 'Lihat transaksi kasir',
      icon: Icons.history_rounded,
      color: Color(0xFF9B5EFF),
      route: AppRoutes.transactionHistory,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard({bool isRefresh = false}) async {
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
      final cachedUser = await _userRepository.getCachedUser();

      if (mounted && cachedUser != null) {
        setState(() {
          _currentUser = cachedUser;
        });
      }

      final results = await Future.wait<dynamic>([
        _userRepository.getProfile(),
        _orderRepository.getOrders(perPage: 100),
      ]);

      final user = results[0] as UserModel;
      final orders = results[1] as List<CustomerOrderModel>;

      final transactions = orders
              .map(_DashboardTransaction.fromModel)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUser = user;
        _transactions = transactions;
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _userRepository.clearLocalSession();

        if (!mounted) {
          return;
        }

        _goToLogin();
        return;
      }

      _handleLoadError(error.firstValidationError);
    } catch (error) {
      debugPrint('CASHIER DASHBOARD ERROR: $error');

      _handleLoadError('Dashboard kasir gagal dimuat. Silakan coba kembali.');
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

  Future<void> _refreshDashboard() async {
    if (_isRefreshing) {
      return;
    }

    await _loadDashboard(isRefresh: true);
  }

  Future<void> _showLogoutConfirmation() async {
    if (_isLoggingOut) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final isDark = Provider.of<ThemeProvider>(
          dialogContext,
          listen: false,
        ).isDarkMode;

        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
            ),
          ),
          title: Text(
            'Konfirmasi Logout',
            style: GoogleFonts.poppins(
              color: theme.textTheme.titleLarge?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar dari akun kasir?',
            style: GoogleFonts.inter(color: theme.textTheme.bodyMedium?.color),
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
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Logout',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
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

    await _userRepository.logout();

    if (!mounted) {
      return;
    }

    _goToLogin();
  }

  void _goToLogin() {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  List<_DashboardTransaction> get _onlineTransactions {
    return _transactions
        .where((transaction) => transaction.channel == 'online')
        .toList();
  }

  List<_DashboardTransaction> get _cashierTransactions {
    return _transactions
        .where((transaction) => transaction.channel == 'cashier')
        .toList();
  }

  List<_DashboardTransaction> get _todayTransactions {
    final now = DateTime.now();

    return _transactions.where((transaction) {
      final date = transaction.createdAt.toLocal();

      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();
  }

  List<_DashboardTransaction> get _paidTransactions {
    return _transactions
        .where((transaction) => transaction.paymentStatus == 'paid')
        .toList();
  }

  List<_DashboardTransaction> get _activeOnlineOrders {
    const activeStatuses = {
      'confirmed',
      'processing',
      'ready',
      'assigned',
      'picked_up',
      'on_delivery',
    };

    return _onlineTransactions.where((transaction) {
      return transaction.paymentStatus == 'paid' &&
          activeStatuses.contains(transaction.orderStatus);
    }).toList();
  }

  int _sumTotal(Iterable<_DashboardTransaction> transactions) {
    return transactions.fold<int>(
      0,
      (total, transaction) => total + transaction.grandTotal,
    );
  }

  List<_DashboardStat> get _dashboardStats {
    final onlinePaid = _onlineTransactions.where(
      (transaction) => transaction.paymentStatus == 'paid',
    );

    final cashierPaid = _cashierTransactions.where(
      (transaction) => transaction.paymentStatus == 'paid',
    );

    final todayOnline = _todayTransactions.where(
      (transaction) => transaction.channel == 'online',
    );

    final todayCashier = _todayTransactions.where(
      (transaction) => transaction.channel == 'cashier',
    );

    final todayPaid = _todayTransactions.where(
      (transaction) => transaction.paymentStatus == 'paid',
    );

    return [
      _DashboardStat(
        title: 'Pesanan Online',
        value: _onlineTransactions.length.toString(),
        subValue: 'Rp ${_formatPrice(_sumTotal(onlinePaid))}',
        badge: '+${todayOnline.length} hari ini',
        icon: Icons.shopping_bag_outlined,
        color: const Color(0xFF9B5EFF),
      ),
      _DashboardStat(
        title: 'Transaksi Kasir',
        value: _cashierTransactions.length.toString(),
        subValue: 'Rp ${_formatPrice(_sumTotal(cashierPaid))}',
        badge: '+${todayCashier.length} hari ini',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFFFF9800),
      ),
      _DashboardStat(
        title: 'Pendapatan',
        value: 'Rp ${_formatCompactPrice(_sumTotal(_paidTransactions))}',
        subValue: '${_paidTransactions.length} transaksi terbayar',
        badge: '+${todayPaid.length} hari ini',
        icon: Icons.payments_outlined,
        color: const Color(0xFF4CAF50),
      ),
      _DashboardStat(
        title: 'Perlu Diproses',
        value: _activeOnlineOrders.length.toString(),
        subValue: 'Pesanan online aktif',
        badge: 'Periksa pesanan',
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFF2196F3),
      ),
    ];
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
                isTablet: isTablet,
              ),
            ),
          ],
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
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13102A) : Colors.white,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
        border: isDark
            ? const Border(bottom: BorderSide(color: Color(0xFF1E1E35)))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Dashboard Kasir',
              style: GoogleFonts.poppins(
                color: theme.textTheme.titleLarge?.color,
                fontSize: isTablet ? 26 : 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 8),
          _buildHeaderButton(
            isDark: isDark,
            icon: Icons.refresh_rounded,
            iconColor: const Color(0xFF9B5EFF),
            backgroundColor: const Color(0xFF9B5EFF).withValues(alpha: 0.12),
            borderColor: const Color(0xFF9B5EFF).withValues(alpha: 0.20),
            onPressed: _isLoading || _isRefreshing ? null : _refreshDashboard,
            child: _isRefreshing
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      color: Color(0xFF9B5EFF),
                      strokeWidth: 2,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          _buildHeaderButton(
            isDark: isDark,
            icon: Icons.logout_rounded,
            iconColor: Colors.red.shade400,
            backgroundColor: isDark
                ? Colors.red.shade400.withValues(alpha: 0.15)
                : Colors.red.shade50,
            borderColor: isDark
                ? Colors.red.shade400.withValues(alpha: 0.30)
                : Colors.red.shade200,
            onPressed: _isLoggingOut ? null : _showLogoutConfirmation,
            child: _isLoggingOut
                ? SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      color: Colors.red.shade400,
                      strokeWidth: 2,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
    required VoidCallback? onPressed,
    Widget? child,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: child ?? Icon(icon, color: iconColor, size: 22),
      ),
    );
  }

  Widget _buildBody({
    required double horizontalPadding,
    required bool isDark,
    required bool isTablet,
  }) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF9B5EFF)),
      );
    }

    if (_errorMessage != null && _transactions.isEmpty) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      color: const Color(0xFF9B5EFF),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(isTablet),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              _buildInlineError(),
            ],
            const SizedBox(height: 24),
            _buildStatsCards(isTablet: isTablet, isDark: isDark),
            const SizedBox(height: 24),
            _buildSectionTitle('Aksi Cepat'),
            const SizedBox(height: 12),
            _buildMenuGrid(isTablet: isTablet, isDark: isDark),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildSectionTitle('Transaksi Terbaru')),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.transactionHistory);
                  },
                  child: Text(
                    'Lihat semua',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9B5EFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildRecentTransactions(isDark),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(bool isTablet) {
    final cashierName = _currentUser?.name.trim().isNotEmpty == true
        ? _currentUser!.name
        : 'Kasir';

    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9B5EFF), Color(0xFF6C3BD8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B5EFF).withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat bekerja, $cashierName! 👋',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: isTablet ? 22 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total aktivitas hari ini: '
                  '${_todayTransactions.length} transaksi',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.90),
                    fontSize: isTablet ? 16 : 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Data dashboard diambil langsung dari Laravel API.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: isTablet ? 60 : 48,
            height: isTablet ? 60 : 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.point_of_sale_rounded,
              color: Colors.white,
              size: isTablet ? 32 : 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade400,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(
                color: Colors.red.shade400,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(onPressed: _refreshDashboard, child: const Text('Ulangi')),
        ],
      ),
    );
  }

  Widget _buildStatsCards({required bool isTablet, required bool isDark}) {
    final theme = Theme.of(context);
    final stats = _dashboardStats;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 4 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: isTablet ? 1.45 : 1.30,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: isDark ? Border.all(color: const Color(0xFF1E1E35)) : null,
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: stat.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(stat.icon, color: stat.color, size: 18),
                  ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: stat.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: stat.color.withValues(alpha: 0.20)),
                      ),
                      child: Text(
                        stat.badge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: stat.color,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                stat.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: theme.textTheme.bodySmall?.color,
                  fontSize: 10,
                ),
              ),
              Text(
                stat.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: theme.textTheme.titleLarge?.color,
                  fontSize: stat.title == 'Pendapatan' ? 15 : 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                stat.subValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: theme.textTheme.bodySmall?.color,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);

    return Text(
      title,
      style: GoogleFonts.poppins(
        color: theme.textTheme.titleLarge?.color,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildMenuGrid({required bool isTablet, required bool isDark}) {
    final theme = Theme.of(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 3 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: isTablet ? 1.45 : 1.15,
      ),
      itemCount: _menuItems.length,
      itemBuilder: (context, index) {
        final item = _menuItems[index];

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(context, item.route).then((_) {
                _refreshDashboard();
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: isDark
                    ? Border.all(color: const Color(0xFF1E1E35))
                    : null,
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.color, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: theme.textTheme.titleLarge?.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 9,
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

  Widget _buildRecentTransactions(bool isDark) {
    final theme = Theme.of(context);
    final recentTransactions = _transactions.take(5).toList();

    if (recentTransactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: isDark ? Border.all(color: const Color(0xFF1E1E35)) : null,
        ),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              color: theme.textTheme.bodySmall?.color,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada transaksi',
              style: GoogleFonts.poppins(
                color: theme.textTheme.titleLarge?.color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Transaksi terbaru akan muncul di sini.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentTransactions.length,
      itemBuilder: (context, index) {
        final transaction = recentTransactions[index];

        return _buildTransactionCard(transaction: transaction, isDark: isDark);
      },
    );
  }

  Widget _buildTransactionCard({
    required _DashboardTransaction transaction,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final statusColor = transaction.statusColor;
    final isCashier = transaction.channel == 'cashier';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: const Color(0xFF1E1E35)) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: transaction.channelColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCashier
                  ? Icons.point_of_sale_rounded
                  : Icons.shopping_bag_outlined,
              color: transaction.channelColor,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      transaction.orderNumber,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _buildTransactionBadge(
                      text: transaction.displayStatus,
                      color: statusColor,
                    ),
                    _buildTransactionBadge(
                      text: transaction.displayChannel,
                      color: transaction.channelColor,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  transaction.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodyMedium?.color,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${transaction.itemCount} item • '
                  '${transaction.displayPaymentMethod}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 105,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rp ${_formatPrice(transaction.grandTotal)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF9B5EFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  DateFormat(
                    'dd MMM yyyy, HH:mm',
                  ).format(transaction.createdAt.toLocal()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionBadge({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, color: Colors.red.shade300, size: 64),
            const SizedBox(height: 18),
            Text(
              'Dashboard gagal dimuat',
              style: GoogleFonts.poppins(
                color: theme.textTheme.titleLarge?.color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Terjadi kesalahan saat mengambil data.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                _loadDashboard();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B5EFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  String _formatCompactPrice(int price) {
    if (price >= 1000000000) {
      final value = price / 1000000000;
      return '${_trimDecimal(value)} M';
    }

    if (price >= 1000000) {
      final value = price / 1000000;
      return '${_trimDecimal(value)} jt';
    }

    if (price >= 1000) {
      final value = price / 1000;
      return '${_trimDecimal(value)} rb';
    }

    return _formatPrice(price);
  }

  String _trimDecimal(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1).replaceAll('.', ',');
  }
}

class _CashierMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  const _CashierMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class _DashboardStat {
  final String title;
  final String value;
  final String subValue;
  final String badge;
  final IconData icon;
  final Color color;

  const _DashboardStat({
    required this.title,
    required this.value,
    required this.subValue,
    required this.badge,
    required this.icon,
    required this.color,
  });
}

class _DashboardTransaction {
  final int id;
  final String orderNumber;
  final String customerName;
  final String channel;
  final String orderStatus;
  final String paymentStatus;
  final String paymentMethod;
  final int grandTotal;
  final int itemCount;
  final DateTime createdAt;

  const _DashboardTransaction({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.channel,
    required this.orderStatus,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.grandTotal,
    required this.itemCount,
    required this.createdAt,
  });

  factory _DashboardTransaction.fromModel(CustomerOrderModel order) {
    final parsedCustomerName = order.customer?.name.trim();
    return _DashboardTransaction(
      id: order.id,
      orderNumber: order.orderNumber,
      customerName: parsedCustomerName == null || parsedCustomerName.isEmpty
          ? 'Pelanggan langsung'
          : parsedCustomerName,
      channel: order.channel,
      orderStatus: order.orderStatus,
      paymentStatus: order.paymentStatus,
      paymentMethod: order.paymentMethod ?? '-',
      grandTotal: order.grandTotal,
      itemCount: order.totalQuantity,
      createdAt: order.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  String get displayChannel {
    switch (channel) {
      case 'cashier':
        return 'Kasir';
      case 'online':
        return 'Online';
      default:
        return channel;
    }
  }

  String get displayPaymentMethod {
    switch (paymentMethod) {
      case 'cash':
        return 'Tunai';
      case 'midtrans':
        return 'Midtrans';
      case 'bank_transfer':
        return 'Transfer Bank';
      case 'cod':
        return 'COD';
      default:
        return paymentMethod == '-' ? '-' : paymentMethod;
    }
  }

  String get displayStatus {
    if (channel == 'cashier' && paymentStatus == 'paid') {
      return 'Selesai';
    }

    switch (orderStatus) {
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
        return 'Dikirim';
      case 'delivered':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return orderStatus;
    }
  }

  Color get channelColor {
    return channel == 'cashier'
        ? const Color(0xFFFF9800)
        : const Color(0xFF9B5EFF);
  }

  Color get statusColor {
    if (channel == 'cashier' && paymentStatus == 'paid') {
      return const Color(0xFF4CAF50);
    }

    switch (orderStatus) {
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
}
