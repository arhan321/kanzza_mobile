// lib/features/customer/presentation/pages/customer_orders_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kanzza_sales_app_fe/core/theme/theme_provider.dart';

class CustomerOrdersPage extends StatefulWidget {
  const CustomerOrdersPage({super.key});

  @override
  State<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends State<CustomerOrdersPage> {
  int _selectedTab = 0;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  bool _showFilter = false;

  final List<Map<String, dynamic>> _orders = [
    {
      'id': 'INV-2025-001',
      'date': DateTime(2025, 6, 15),
      'dateStr': '15 Juni 2025',
      'status': 'Diproses',
      'statusColor': const Color(0xFFFF9B5EFF),
      'items': [
        {'name': 'Keripik Singkong Original', 'qty': 2, 'price': 15000},
        {'name': 'Air Mineral 600ml', 'qty': 1, 'price': 4000},
      ],
      'total': 34000,
      'paymentMethod': 'COD',
      'deliveryMethod': 'Di Antar',
      'address': 'Jl. Raya PLP Curug No. 124, Legok, Tangerang',
    },
    {
      'id': 'INV-2025-002',
      'date': DateTime(2025, 6, 14),
      'dateStr': '14 Juni 2025',
      'status': 'Dikirim',
      'statusColor': const Color(0xFF4CAF50),
      'items': [
        {'name': 'Beras Premium 5kg', 'qty': 1, 'price': 65000},
        {'name': 'Mie Instan Goreng', 'qty': 3, 'price': 3500},
      ],
      'total': 75500,
      'paymentMethod': 'Transfer Bank',
      'deliveryMethod': 'Di Antar',
      'address': 'Jl. Citra Raya No. 45, Panongan, Tangerang',
    },
    {
      'id': 'INV-2025-003',
      'date': DateTime(2025, 6, 13),
      'dateStr': '13 Juni 2025',
      'status': 'Selesai',
      'statusColor': const Color(0xFF2196F3),
      'items': [
        {'name': 'Es Krim Coklat', 'qty': 2, 'price': 12000},
        {'name': 'Teh Botol 350ml', 'qty': 2, 'price': 5000},
      ],
      'total': 34000,
      'paymentMethod': 'COD',
      'deliveryMethod': 'Ambil di Toko',
      'address': 'Ambil di Toko',
    },
    {
      'id': 'INV-2025-004',
      'date': DateTime(2025, 6, 12),
      'dateStr': '12 Juni 2025',
      'status': 'Dibatalkan',
      'statusColor': const Color(0xFFFF5252),
      'items': [
        {'name': 'Keripik Singkong Original', 'qty': 1, 'price': 15000},
      ],
      'total': 15000,
      'paymentMethod': 'COD',
      'deliveryMethod': 'Di Antar',
      'address': 'Jl. Alam Sutera No. 12, Tangerang',
    },
  ];

  List<Map<String, dynamic>> get _filteredOrders {
    var filtered = _orders;

    // Filter by status tab
    if (_selectedTab > 0) {
      final statusMap = {
        1: 'Diproses',
        2: 'Dikirim',
        3: 'Selesai',
      };
      final filterStatus = statusMap[_selectedTab];
      if (filterStatus != null) {
        filtered = filtered.where((order) => order['status'] == filterStatus).toList();
      }
    }

    // Filter by date range
    if (_filterStartDate != null) {
      filtered = filtered.where((order) {
        final orderDate = order['date'] as DateTime;
        return orderDate.isAfter(_filterStartDate!.subtract(const Duration(days: 1)));
      }).toList();
    }

    if (_filterEndDate != null) {
      filtered = filtered.where((order) {
        final orderDate = order['date'] as DateTime;
        return orderDate.isBefore(_filterEndDate!.add(const Duration(days: 1)));
      }).toList();
    }

    // Sort by date (newest first)
    filtered.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    return filtered;
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  void _showFilterDialog() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
          ),
        ),
        title: Text(
          "Filter Tanggal",
          style: GoogleFonts.poppins(
            color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Start Date
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Dari:",
                        style: GoogleFonts.inter(
                          color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _filterStartDate ?? DateTime.now(),
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
                                  dialogBackgroundColor: isDark ? const Color(0xFF16162A) : Colors.white,
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              _filterStartDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0D0D12) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _filterStartDate != null
                                      ? DateFormat('dd/MM/yyyy').format(_filterStartDate!)
                                      : "Pilih tanggal",
                                  style: GoogleFonts.inter(
                                    color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                                    fontSize: 13,
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
                const SizedBox(height: 12),
                // End Date
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Sampai:",
                        style: GoogleFonts.inter(
                          color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _filterEndDate ?? DateTime.now(),
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
                                  dialogBackgroundColor: isDark ? const Color(0xFF16162A) : Colors.white,
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              _filterEndDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0D0D12) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _filterEndDate != null
                                      ? DateFormat('dd/MM/yyyy').format(_filterEndDate!)
                                      : "Pilih tanggal",
                                  style: GoogleFonts.inter(
                                    color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                                    fontSize: 13,
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
                const SizedBox(height: 16),
                // Reset & Apply Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          setStateDialog(() {
                            _filterStartDate = null;
                            _filterEndDate = null;
                          });
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF3F4F6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          "Reset",
                          style: GoogleFonts.inter(
                            color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showFilter = true;
                          });
                          Navigator.pop(context);
                          _showSnackBar("Filter tanggal diterapkan", Colors.green);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9B5EFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          "Terapkan Filter",
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
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
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF16162A) : const Color(0xFFF5F5FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Pesanan Saya",
                        style: GoogleFonts.poppins(
                          color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // Filter Button with indicator
                    Stack(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF16162A) : const Color(0xFFF5F5FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
                            ),
                          ),
                          child: IconButton(
                            onPressed: _showFilterDialog,
                            icon: Icon(
                              Icons.filter_list,
                              color: (_filterStartDate != null || _filterEndDate != null)
                                  ? const Color(0xFF9B5EFF)
                                  : (isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280)),
                              size: 22,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        if (_filterStartDate != null || _filterEndDate != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF9B5EFF),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Filter Info
              if (_filterStartDate != null || _filterEndDate != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _filterStartDate != null && _filterEndDate != null
                              ? "📅 ${DateFormat('dd/MM/yyyy').format(_filterStartDate!)} - ${DateFormat('dd/MM/yyyy').format(_filterEndDate!)}"
                              : _filterStartDate != null
                                  ? "📅 Dari ${DateFormat('dd/MM/yyyy').format(_filterStartDate!)}"
                                  : "📅 Sampai ${DateFormat('dd/MM/yyyy').format(_filterEndDate!)}",
                          style: GoogleFonts.inter(
                            color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _filterStartDate = null;
                            _filterEndDate = null;
                          });
                          _showSnackBar("Filter dihapus", Colors.orange);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            "Hapus Filter",
                            style: GoogleFonts.inter(
                              color: Colors.red.shade400,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // Tabs
              Container(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Row(
                  children: [
                    _buildTabButton("Semua", 0, isDark),
                    _buildTabButton("Diproses", 1, isDark),
                    _buildTabButton("Dikirim", 2, isDark),
                    _buildTabButton("Selesai", 3, isDark),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Order List
              Expanded(
                child: _filteredOrders.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: hPad),
                        itemCount: _filteredOrders.length,
                        itemBuilder: (context, index) {
                          final order = _filteredOrders[index];
                          return _buildOrderCard(order, isDark);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index, bool isDark) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF9B5EFF) : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: isSelected
                  ? (isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937))
                  : (isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280)),
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, bool isDark) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
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
          // Header Order
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        order['id'],
                        style: GoogleFonts.inter(
                          color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (order['statusColor'] as Color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (order['statusColor'] as Color).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        order['status'],
                        style: GoogleFonts.inter(
                          color: order['statusColor'] as Color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                order['dateStr'],
                style: GoogleFonts.inter(
                  color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Items
          ...order['items'].map<Widget>((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "${item['qty']}x ${item['name']}",
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    "Rp ${_formatPrice(item['price'] * item['qty'])}",
                    style: GoogleFonts.inter(
                      color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          Divider(
            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
            height: 16,
          ),

          // Total & Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total Belanja",
                    style: GoogleFonts.inter(
                      color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    "Rp ${_formatPrice(order['total'])}",
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF9B5EFF),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (order['status'] != 'Dibatalkan')
                    TextButton(
                      onPressed: () {
                        _showOrderDetailDialog(order, isDark);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF3F4F6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: Text(
                        "Detail",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9B5EFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (order['status'] == 'Diproses') ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _showCancelOrderDialog(order, isDark);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.red.withOpacity(0.3)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: Text(
                        "Batalkan",
                        style: GoogleFonts.inter(
                          color: Colors.red.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (order['status'] == 'Selesai')
                    TextButton(
                      onPressed: () {
                        _showReorderDialog(order, isDark);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF9B5EFF).withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: const Color(0xFF9B5EFF).withOpacity(0.3)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: Text(
                        "Pesan Lagi",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9B5EFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Delivery Info
          if (order['deliveryMethod'] == 'Di Antar')
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order['address'],
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16162A) : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long,
              color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
              size: 60,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Belum Ada Pesanan",
            style: GoogleFonts.poppins(
              color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Mulai belanja sekarang dan\nlihat pesanan Anda di sini",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B5EFF),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Mulai Belanja",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetailDialog(Map<String, dynamic> order, bool isDark) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
          ),
        ),
        title: Text(
          "Detail Pesanan",
          style: GoogleFonts.poppins(
            color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ID & Date
                Row(
                  children: [
                    Text(
                      "ID: ",
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        order['id'],
                        style: GoogleFonts.inter(
                          color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      "Tanggal: ",
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        order['dateStr'],
                        style: GoogleFonts.inter(
                          color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Items
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Item Pesanan:",
                        style: GoogleFonts.inter(
                          color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...order['items'].map<Widget>((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  "${item['qty']}x ${item['name']}",
                                  style: GoogleFonts.inter(
                                    color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              Text(
                                "Rp ${_formatPrice(item['price'] * item['qty'])}",
                                style: GoogleFonts.inter(
                                  color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total Belanja",
                      style: GoogleFonts.poppins(
                        color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "Rp ${_formatPrice(order['total'])}",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF9B5EFF),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Payment & Delivery
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Pembayaran",
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        order['paymentMethod'],
                        style: GoogleFonts.inter(
                          color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Pengiriman",
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        order['deliveryMethod'],
                        style: GoogleFonts.inter(
                          color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                if (order['deliveryMethod'] == 'Di Antar') ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Alamat: ",
                        style: GoogleFonts.inter(
                          color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          order['address'],
                          style: GoogleFonts.inter(
                            color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Tutup",
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelOrderDialog(Map<String, dynamic> order, bool isDark) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
          ),
        ),
        title: Text(
          "Batalkan Pesanan",
          style: GoogleFonts.poppins(
            color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          "Apakah Anda yakin ingin membatalkan pesanan ${order['id']}?",
          style: GoogleFonts.inter(
            color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Batal",
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Pesanan ${order['id']} berhasil dibatalkan",
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                  backgroundColor: Colors.red.shade400,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Ya, Batalkan",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReorderDialog(Map<String, dynamic> order, bool isDark) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
          ),
        ),
        title: Text(
          "Pesan Lagi",
          style: GoogleFonts.poppins(
            color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          "Tambahkan semua item dari pesanan ${order['id']} ke keranjang?",
          style: GoogleFonts.inter(
            color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Batal",
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Item ditambahkan ke keranjang!",
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFF9B5EFF),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B5EFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Tambahkan",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}