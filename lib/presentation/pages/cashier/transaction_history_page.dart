// lib/presentation/pages/cashier/transaction_history_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/models/cashier_transaction.dart';
import '../../../data/repositories/cashier_transaction_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../routes.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  final CashierTransactionRepository _transactionRepository =
      CashierTransactionRepository();
  final UserRepository _userRepository = UserRepository();
  final TextEditingController _searchController = TextEditingController();

  final List<CashierTransactionModel> _transactions = [];

  String _selectedPeriod = '30 Hari';
  DateTime _customStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customEndDate = DateTime.now();

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  static const List<String> _periodOptions = [
    'Semua',
    'Hari Ini',
    '7 Hari',
    '30 Hari',
    'Rentang',
  ];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions({bool isRefresh = false}) async {
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
      final transactions = await _transactionRepository.getTransactions(
        perPage: 100,
      );

      transactions.sort(
        (a, b) => _transactionDate(b).compareTo(_transactionDate(a)),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _transactions
          ..clear()
          ..addAll(transactions);

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
      debugPrint('LOAD CASHIER TRANSACTION HISTORY ERROR: $error');

      _handleLoadError('Riwayat transaksi gagal dimuat. Silakan coba kembali.');
    }
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

  Future<void> _refresh() async {
    if (_isRefreshing) {
      return;
    }

    await _loadTransactions(isRefresh: true);
  }

  List<CashierTransactionModel> get _filteredTransactions {
    final search = _searchController.text.trim().toLowerCase();

    final filtered = _transactions.where((transaction) {
      if (!_matchesPeriod(transaction)) {
        return false;
      }

      if (search.isEmpty) {
        return true;
      }

      final orderNumber = transaction.orderNumber.toLowerCase();
      final customerName = transaction.displayCustomerName.toLowerCase();
      final notes = transaction.notes?.toLowerCase() ?? '';
      final products = transaction.items
          .map((item) => item.productName.toLowerCase())
          .join(' ');

      return orderNumber.contains(search) ||
          customerName.contains(search) ||
          notes.contains(search) ||
          products.contains(search);
    }).toList();

    filtered.sort((a, b) => _transactionDate(b).compareTo(_transactionDate(a)));

    return filtered;
  }

  bool _matchesPeriod(CashierTransactionModel transaction) {
    final transactionDate = _transactionDate(transaction).toLocal();
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'Hari Ini':
        return _isSameDate(transactionDate, now);

      case '7 Hari':
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));

        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

        return !transactionDate.isBefore(start) &&
            !transactionDate.isAfter(end);

      case '30 Hari':
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 29));

        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

        return !transactionDate.isBefore(start) &&
            !transactionDate.isAfter(end);

      case 'Rentang':
        final start = DateTime(
          _customStartDate.year,
          _customStartDate.month,
          _customStartDate.day,
        );

        final end = DateTime(
          _customEndDate.year,
          _customEndDate.month,
          _customEndDate.day,
          23,
          59,
          59,
          999,
        );

        return !transactionDate.isBefore(start) &&
            !transactionDate.isAfter(end);

      case 'Semua':
      default:
        return true;
    }
  }

  DateTime _transactionDate(CashierTransactionModel transaction) {
    return transaction.createdAt ??
        transaction.paidAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  int get _totalTransactions {
    return _filteredTransactions.length;
  }

  int get _totalIncome {
    return _filteredTransactions
        .where((transaction) => transaction.isPaid)
        .fold<int>(0, (total, transaction) => total + transaction.grandTotal);
  }

  int get _totalItems {
    return _filteredTransactions.fold<int>(
      0,
      (total, transaction) => total + transaction.totalQuantity,
    );
  }

  int get _averageTransaction {
    final paidTransactions = _filteredTransactions
        .where((transaction) => transaction.isPaid)
        .toList();

    if (paidTransactions.isEmpty) {
      return 0;
    }

    final total = paidTransactions.fold<int>(
      0,
      (sum, transaction) => sum + transaction.grandTotal,
    );

    return total ~/ paidTransactions.length;
  }

  Future<void> _selectStartDate() async {
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    final picked = await showDatePicker(
      context: context,
      initialDate: _customStartDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
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
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _customStartDate = picked;

      if (_customStartDate.isAfter(_customEndDate)) {
        _customEndDate = _customStartDate;
      }

      _selectedPeriod = 'Rentang';
    });
  }

  Future<void> _selectEndDate() async {
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    final picked = await showDatePicker(
      context: context,
      initialDate: _customEndDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
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
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _customEndDate = picked;

      if (_customEndDate.isBefore(_customStartDate)) {
        _customStartDate = _customEndDate;
      }

      _selectedPeriod = 'Rentang';
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedPeriod = '30 Hari';
      _customStartDate = DateTime.now().subtract(const Duration(days: 30));
      _customEndDate = DateTime.now();
      _searchController.clear();
    });
  }

  void _showTransactionDetail(CashierTransactionModel transaction) {
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
            heightFactor: 0.88,
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
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 14),
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
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: theme.dividerColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const Spacer(),
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
                                    0xFFFF9800,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.point_of_sale_rounded,
                                  color: Color(0xFFFF9800),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      transaction.orderNumber,
                                      style: GoogleFonts.poppins(
                                        color:
                                            theme.textTheme.titleLarge?.color,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _formatDateTime(
                                        _transactionDate(transaction),
                                      ),
                                      style: GoogleFonts.inter(
                                        color: theme.textTheme.bodySmall?.color,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusBadge(
                                text: _statusLabel(transaction),
                                color: _statusColor(transaction),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildDetailCard(
                            children: [
                              _buildDetailRow(
                                label: 'Pelanggan',
                                value: transaction.displayCustomerName,
                              ),
                              _buildDetailRow(
                                label: 'Kasir',
                                value: transaction.cashierName ?? '-',
                              ),
                              _buildDetailRow(
                                label: 'Metode pembayaran',
                                value: _paymentMethodLabel(
                                  transaction.paymentMethod,
                                ),
                              ),
                              _buildDetailRow(
                                label: 'Status pembayaran',
                                value: _paymentStatusLabel(
                                  transaction.paymentStatus,
                                ),
                                valueColor: transaction.isPaid
                                    ? Colors.green.shade500
                                    : Colors.orange.shade500,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Rincian Produk',
                            style: GoogleFonts.poppins(
                              color: theme.textTheme.titleLarge?.color,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (transaction.items.isEmpty)
                            _buildEmptyItems()
                          else
                            ...transaction.items.map(
                              (item) => _buildItemCard(item),
                            ),
                          const SizedBox(height: 18),
                          _buildDetailCard(
                            children: [
                              _buildDetailRow(
                                label: 'Subtotal',
                                value:
                                    'Rp ${_formatPrice(transaction.subtotal)}',
                              ),
                              if (transaction.discount > 0)
                                _buildDetailRow(
                                  label: 'Diskon',
                                  value:
                                      '- Rp ${_formatPrice(transaction.discount)}',
                                  valueColor: Colors.green.shade500,
                                ),
                              _buildDetailRow(
                                label: 'Total',
                                value:
                                    'Rp ${_formatPrice(transaction.grandTotal)}',
                                valueColor: const Color(0xFF9B5EFF),
                                isBold: true,
                              ),
                              _buildDetailRow(
                                label: 'Uang diterima',
                                value:
                                    'Rp ${_formatPrice(transaction.paymentAmount)}',
                              ),
                              _buildDetailRow(
                                label: 'Kembalian',
                                value:
                                    'Rp ${_formatPrice(transaction.changeAmount)}',
                                valueColor: Colors.green.shade500,
                              ),
                            ],
                          ),
                          if (transaction.notes != null &&
                              transaction.notes!.trim().isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Text(
                              'Catatan',
                              style: GoogleFonts.poppins(
                                color: theme.textTheme.titleLarge?.color,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E1E35)
                                    : const Color(0xFFF5F5FA),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Text(
                                transaction.notes!,
                                style: GoogleFonts.inter(
                                  color: theme.textTheme.bodyMedium?.color,
                                  fontSize: 12,
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

  Widget _buildDetailCard({required List<Widget> children}) {
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A42) : const Color(0xFFE8E8F0),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                color: valueColor ?? theme.textTheme.titleLarge?.color,
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(CashierTransactionItemModel item) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
              color: const Color(0xFF9B5EFF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF9B5EFF),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.quantity} × Rp ${_formatPrice(item.price)}',
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Rp ${_formatPrice(item.subtotal)}',
            style: GoogleFonts.poppins(
              color: const Color(0xFF9B5EFF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyItems() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Rincian item tidak tersedia.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: theme.textTheme.bodySmall?.color,
          fontSize: 12,
        ),
      ),
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
        top: MediaQuery.of(context).padding.top + 14,
        bottom: 14,
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
                  'Riwayat Transaksi Kasir',
                  style: GoogleFonts.poppins(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: isTablet ? 24 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Data langsung dari Laravel',
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Reset filter',
            onPressed: _resetFilters,
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xFF16162A)
                  : const Color(0xFFF5F5FA),
              foregroundColor: theme.textTheme.bodyMedium?.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.filter_alt_off_rounded),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _isLoading || _isRefreshing ? null : _refresh,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF9B5EFF).withValues(alpha: 0.12),
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
                      strokeWidth: 2,
                      color: Color(0xFF9B5EFF),
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF9B5EFF)),
      );
    }

    if (_errorMessage != null && _transactions.isEmpty) {
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
          30,
        ),
        children: [
          _buildSummaryCards(isDark: isDark, isTablet: isTablet),
          const SizedBox(height: 16),
          _buildSearchAndFilter(isDark),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _buildInlineError(),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_filteredTransactions.length} transaksi ditemukan',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                _selectedPeriod,
                style: GoogleFonts.inter(
                  color: const Color(0xFF9B5EFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTransactionList(isDark),
        ],
      ),
    );
  }

  Widget _buildSummaryCards({required bool isDark, required bool isTablet}) {
    final stats = [
      _HistoryStat(
        title: 'Total Transaksi',
        value: _totalTransactions.toString(),
        subtitle: 'Transaksi pada filter',
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFF9B5EFF),
      ),
      _HistoryStat(
        title: 'Pendapatan',
        value: 'Rp ${_formatCompactPrice(_totalIncome)}',
        subtitle: 'Transaksi terbayar',
        icon: Icons.payments_outlined,
        color: const Color(0xFF4CAF50),
      ),
      _HistoryStat(
        title: 'Jumlah Item',
        value: _totalItems.toString(),
        subtitle: 'Produk terjual',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFFFF9800),
      ),
      _HistoryStat(
        title: 'Rata-rata',
        value: 'Rp ${_formatCompactPrice(_averageTransaction)}',
        subtitle: 'Nilai per transaksi',
        icon: Icons.analytics_outlined,
        color: const Color(0xFF2196F3),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 4 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: isTablet ? 1.45 : 1.35,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        final theme = Theme.of(context);

        return Container(
          padding: const EdgeInsets.all(13),
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
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: stat.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(stat.icon, color: stat.color, size: 19),
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
                  fontSize:
                      stat.title == 'Pendapatan' || stat.title == 'Rata-rata'
                      ? 14
                      : 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                stat.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: theme.textTheme.bodySmall?.color,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilter(bool isDark) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        border: isDark ? Border.all(color: const Color(0xFF1E1E35)) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 9,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) {
              setState(() {});
            },
            style: GoogleFonts.inter(
              color: theme.textTheme.titleLarge?.color,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: 'Cari nomor transaksi, produk, atau pelanggan...',
              hintStyle: GoogleFonts.inter(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 11,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF9B5EFF),
              ),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
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
          const SizedBox(height: 13),
          SizedBox(
            height: 39,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _periodOptions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final period = _periodOptions[index];
                final selected = _selectedPeriod == period;

                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedPeriod = period;
                    });
                  },
                  label: Text(
                    period,
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
                      : Colors.white,
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF9B5EFF)
                        : isDark
                        ? const Color(0xFF1E1E35)
                        : const Color(0xFFE5E7EB),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          if (_selectedPeriod == 'Rentang') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDateButton(
                    label: 'Dari',
                    date: _customStartDate,
                    onTap: _selectStartDate,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDateButton(
                    label: 'Sampai',
                    date: _customEndDate,
                    onTap: _selectEndDate,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D0D12) : const Color(0xFFF7F7FB),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: Color(0xFF9B5EFF),
                size: 16,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 8,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(date),
                      style: GoogleFonts.inter(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 11,
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

  Widget _buildTransactionList(bool isDark) {
    final transactions = _filteredTransactions;

    if (transactions.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        return _buildTransactionCard(
          transaction: transactions[index],
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildTransactionCard({
    required CashierTransactionModel transaction,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(transaction);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _showTransactionDetail(transaction);
        },
        borderRadius: BorderRadius.circular(13),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(13),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.point_of_sale_rounded,
                  color: Color(0xFFFF9800),
                  size: 20,
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
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _buildStatusBadge(
                          text: _statusLabel(transaction),
                          color: statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      transaction.displayCustomerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${transaction.totalQuantity} item • '
                      '${_paymentMethodLabel(transaction.paymentMethod)}',
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
                width: 108,
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
                      _formatDateTime(_transactionDate(transaction)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.textTheme.bodySmall?.color,
                      size: 17,
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

  Widget _buildStatusBadge({required String text, required Color color}) {
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

  Widget _buildInlineError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
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

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, color: Colors.red.shade300, size: 64),
            const SizedBox(height: 17),
            Text(
              'Riwayat gagal dimuat',
              style: GoogleFonts.poppins(
                color: theme.textTheme.titleLarge?.color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  'Terjadi kesalahan saat mengambil riwayat transaksi.',
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
                _loadTransactions();
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
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      child: Column(
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            color: theme.textTheme.bodySmall?.color,
            size: 58,
          ),
          const SizedBox(height: 14),
          Text(
            'Transaksi tidak ditemukan',
            style: GoogleFonts.poppins(
              color: theme.textTheme.titleLarge?.color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Coba ubah pencarian atau periode transaksi.',
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

  String _statusLabel(CashierTransactionModel transaction) {
    if (transaction.paymentStatus == 'paid') {
      return 'Selesai';
    }

    switch (transaction.paymentStatus) {
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
        return transaction.paymentStatus;
    }
  }

  Color _statusColor(CashierTransactionModel transaction) {
    switch (transaction.paymentStatus) {
      case 'paid':
        return const Color(0xFF4CAF50);
      case 'unpaid':
      case 'pending':
        return const Color(0xFFFF9800);
      case 'failed':
      case 'cancelled':
      case 'expired':
        return const Color(0xFFF44336);
      case 'refunded':
        return const Color(0xFF2196F3);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _paymentMethodLabel(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Tunai';
      case 'midtrans':
        return 'Midtrans';
      case 'bank_transfer':
        return 'Transfer Bank';
      case 'cod':
        return 'COD';
      default:
        return method.isEmpty ? '-' : method;
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

  String _formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  String _formatCompactPrice(int price) {
    if (price >= 1000000000) {
      return '${_trimDecimal(price / 1000000000)} M';
    }

    if (price >= 1000000) {
      return '${_trimDecimal(price / 1000000)} jt';
    }

    if (price >= 1000) {
      return '${_trimDecimal(price / 1000)} rb';
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

class _HistoryStat {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _HistoryStat({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
