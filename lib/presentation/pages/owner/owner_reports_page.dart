// lib/features/owner/presentation/pages/owner_reports_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kanzza_sales_app_fe/core/theme/theme_provider.dart';
import 'package:kanzza_sales_app_fe/routes.dart';

class OwnerReportsPage extends StatefulWidget {
  const OwnerReportsPage({super.key});

  @override
  State<OwnerReportsPage> createState() => _OwnerReportsPageState();
}

class _OwnerReportsPageState extends State<OwnerReportsPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedFilter = "Semua";
  
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _generateDummyData();
  }

  void _generateDummyData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    _transactions = [
      {
        'id': 'TRX-${DateFormat('yyyyMMdd').format(today)}-001',
        'customer': 'Ahmad Fauzi',
        'products': [
          {'name': 'Keripik Singkong Original', 'qty': 2, 'price': 15000},
          {'name': 'Air Mineral 600ml', 'qty': 1, 'price': 4000},
        ],
        'total': 34000,
        'status': 'Selesai',
        'statusColor': const Color(0xFF4CAF50),
        'date': DateTime(today.year, today.month, today.day, 14, 30),
        'payment': 'COD',
        'type': 'Online',
        'items': 3,
      },
      {
        'id': 'TRX-${DateFormat('yyyyMMdd').format(today)}-002',
        'customer': 'Siti Rahma',
        'products': [
          {'name': 'Beras Premium 5kg', 'qty': 1, 'price': 65000},
          {'name': 'Es Krim Coklat', 'qty': 2, 'price': 12000},
          {'name': 'Teh Botol 350ml', 'qty': 2, 'price': 5000},
        ],
        'total': 99000,
        'status': 'Diproses',
        'statusColor': const Color(0xFFFF9B5EFF),
        'date': DateTime(today.year, today.month, today.day, 13, 15),
        'payment': 'Transfer',
        'type': 'Online',
        'items': 5,
      },
      {
        'id': 'OFF-${DateFormat('yyyyMMdd').format(today)}-001',
        'customer': 'Pelanggan Offline',
        'products': [
          {'name': 'Keripik Singkong Balado', 'qty': 1, 'price': 17000},
          {'name': 'Es Krim Vanila', 'qty': 2, 'price': 12000},
          {'name': 'Air Mineral 600ml', 'qty': 3, 'price': 4000},
        ],
        'total': 41000,
        'status': 'Selesai',
        'statusColor': const Color(0xFFFF9800),
        'date': DateTime(today.year, today.month, today.day, 12, 30),
        'payment': 'Cash',
        'type': 'Offline',
        'items': 6,
      },
      {
        'id': 'TRX-${DateFormat('yyyyMMdd').format(today)}-003',
        'customer': 'Budi Santoso',
        'products': [
          {'name': 'Mie Instan Goreng', 'qty': 4, 'price': 3500},
          {'name': 'Gula Pasir 1kg', 'qty': 2, 'price': 18000},
          {'name': 'Air Mineral 600ml', 'qty': 2, 'price': 4000},
          {'name': 'Keripik Singkong Original', 'qty': 1, 'price': 15000},
        ],
        'total': 68500,
        'status': 'Selesai',
        'statusColor': const Color(0xFF4CAF50),
        'date': DateTime(today.year, today.month, today.day, 11, 45),
        'payment': 'COD',
        'type': 'Online',
        'items': 9,
      },
      {
        'id': 'OFF-${DateFormat('yyyyMMdd').format(today)}-002',
        'customer': 'Warung Sembako',
        'products': [
          {'name': 'Beras Premium 5kg', 'qty': 2, 'price': 65000},
          {'name': 'Gula Pasir 1kg', 'qty': 3, 'price': 18000},
        ],
        'total': 184000,
        'status': 'Selesai',
        'statusColor': const Color(0xFFFF9800),
        'date': DateTime(today.year, today.month, today.day, 10, 20),
        'payment': 'Cash',
        'type': 'Offline',
        'items': 5,
      },
    ];
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    var filtered = _transactions;
    
    if (_selectedFilter != "Semua") {
      filtered = filtered.where((t) => t['type'] == _selectedFilter).toList();
    }
    
    filtered = filtered.where((t) {
      final date = t['date'] as DateTime;
      return date.isAfter(_startDate.subtract(const Duration(days: 1))) && 
             date.isBefore(_endDate.add(const Duration(days: 1)));
    }).toList();
    
    filtered.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    
    return filtered;
  }

  int get _totalTransactions => _filteredTransactions.length;
  int get _totalIncome => _filteredTransactions.fold(0, (sum, t) => sum + (t['total'] as int));

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final theme = Theme.of(context);
    final sw = MediaQuery.of(context).size.width;
    final hPad = sw * 0.04;
    final isTablet = sw > 600;

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
                ? [const Color(0xFF13102A), const Color(0xFF0D0D12)]
                : [const Color(0xFFF5F5FA), const Color(0xFFE8E8F0)],
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.only(
                left: hPad,
                right: hPad,
                top: MediaQuery.of(context).padding.top + 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13102A) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black12 : Colors.black12,
                    blurRadius: isDark ? 0 : 10,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isDark
                    ? const Border(bottom: BorderSide(color: Color(0xFF1E1E35)))
                    : null,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.ownerDashboard,
                        );
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF16162A)
                            : const Color(0xFFF5F5FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF1E1E35)
                              : const Color(0xFFE8E8F0),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark
                            ? const Color(0xFFF0EAFF)
                            : const Color(0xFF1F2937),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Laporan Penjualan",
                      style: GoogleFonts.poppins(
                        color: isDark
                            ? const Color(0xFFF0EAFF)
                            : const Color(0xFF1F2937),
                        fontSize: isTablet ? 26 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Tombol Download (simulasi)
                  GestureDetector(
                    onTap: () {
                      _showSnackBar("📊 Laporan berhasil diunduh! (Simulasi)", Colors.green);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9B5EFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.download_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Reset Filter
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = "Semua";
                        _startDate = DateTime.now().subtract(const Duration(days: 30));
                        _endDate = DateTime.now();
                      });
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF16162A)
                            : const Color(0xFFF5F5FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF1E1E35)
                              : const Color(0xFFE8E8F0),
                        ),
                      ),
                      child: Icon(
                        Icons.refresh,
                        color: isDark
                            ? const Color(0xFF9B97B8)
                            : const Color(0xFF6B7280),
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterSection(isDark),
                    const SizedBox(height: 16),
                    _buildSummaryCards(isDark),
                    const SizedBox(height: 16),
                    _buildTransactionList(isDark),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(bool isDark) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: const Color(0xFF1E1E35)) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Tipe:",
                style: GoogleFonts.inter(
                  color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              _buildFilterChip("Semua", isDark),
              _buildFilterChip("Online", isDark),
              _buildFilterChip("Offline", isDark),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  "Dari",
                  style: GoogleFonts.inter(
                    color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D0D12) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_startDate),
                          style: GoogleFonts.inter(
                            color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 55,
                child: Text(
                  "Sampai",
                  style: GoogleFonts.inter(
                    color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D0D12) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_endDate),
                          style: GoogleFonts.inter(
                            color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isDark) {
    final isSelected = _selectedFilter == label;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF9B5EFF)
              : isDark
                  ? const Color(0xFF16162A)
                  : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF9B5EFF)
                : isDark
                    ? const Color(0xFF1E1E35)
                    : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected
                ? Colors.white
                : isDark
                    ? const Color(0xFF9B97B8)
                    : const Color(0xFF6B7280),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: isDark ? Border.all(color: const Color(0xFF1E1E35)) : null,
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Total Transaksi",
                  style: GoogleFonts.inter(
                    color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _totalTransactions.toString(),
                  style: GoogleFonts.poppins(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: isDark ? Border.all(color: const Color(0xFF1E1E35)) : null,
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Total Pendapatan",
                  style: GoogleFonts.inter(
                    color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Rp ${_formatPrice(_totalIncome)}",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF9B5EFF),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(bool isDark) {
    final theme = Theme.of(context);
    final transactions = _filteredTransactions;

    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              Icons.receipt_long,
              color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              "Tidak ada transaksi",
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Coba ubah filter atau tanggal",
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
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
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final statusColor = transaction['statusColor'] as Color;
        final total = transaction['total'] as int;
        final isOffline = transaction['type'] == 'Offline';
        final date = transaction['date'] as DateTime;
        final id = transaction['id']?.toString() ?? '';
        final status = transaction['status']?.toString() ?? '';
        final customer = transaction['customer']?.toString() ?? '';
        final payment = transaction['payment']?.toString() ?? '';
        final type = transaction['type']?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: isDark ? Border.all(color: const Color(0xFF1E1E35)) : null,
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Icon + ID + Status + Type
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isOffline
                          ? const Color(0xFFFF9800).withOpacity(0.1)
                          : const Color(0xFF9B5EFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isOffline ? Icons.sync : Icons.wifi,
                      color: isOffline ? const Color(0xFFFF9800) : const Color(0xFF9B5EFF),
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          id,
                          style: GoogleFonts.inter(
                            color: theme.textTheme.titleLarge?.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: statusColor.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.inter(
                              color: statusColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isOffline
                                ? const Color(0xFFFF9800).withOpacity(0.1)
                                : const Color(0xFF9B5EFF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isOffline
                                  ? const Color(0xFFFF9800).withOpacity(0.2)
                                  : const Color(0xFF9B5EFF).withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            type,
                            style: GoogleFonts.inter(
                              color: isOffline ? const Color(0xFFFF9800) : const Color(0xFF9B5EFF),
                              fontSize: 7,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              // Row 2: Customer + Payment + Total + Date
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          color: theme.textTheme.bodySmall?.color,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            customer,
                            style: GoogleFonts.inter(
                              color: theme.textTheme.bodyMedium?.color,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E35)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                payment == 'Cash' || payment == 'COD'
                                    ? Icons.attach_money
                                    : Icons.account_balance_wallet,
                                color: theme.textTheme.bodySmall?.color,
                                size: 8,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                payment,
                                style: GoogleFonts.inter(
                                  color: theme.textTheme.bodySmall?.color,
                                  fontSize: 7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Rp ${_formatPrice(total)}",
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF9B5EFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM HH:mm').format(date),
                        style: GoogleFonts.inter(
                          color: theme.textTheme.bodySmall?.color,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}