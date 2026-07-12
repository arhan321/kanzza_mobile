// lib/features/owner/presentation/pages/owner_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:kanzza_sales_app_fe/core/theme/theme_provider.dart';
import 'package:kanzza_sales_app_fe/core/widgets/theme_toggle_button.dart';
import 'package:kanzza_sales_app_fe/routes.dart';

// ⬇️ IMPORT HALAMAN ⬇️
import 'owner_products_page.dart';
import 'owner_reports_page.dart';
import 'owner_manage_role_page.dart';

class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({super.key});

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  int _selectedPeriod = 0;
  int _selectedChartTab = 0;
  
  // ==================== DATA DUMMY ====================
  final List<double> _weeklySales = [2.5, 3.8, 4.2, 6.1, 5.5, 8.0, 7.2];
  final List<String> _weekDays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  
  final List<Map<String, dynamic>> _topCategories = [
    {'name': 'Snack', 'value': 35, 'color': const Color(0xFF9B5EFF)},
    {'name': 'Minuman', 'value': 25, 'color': const Color(0xFF4CAF50)},
    {'name': 'Frozen', 'value': 20, 'color': const Color(0xFFFF9800)},
    {'name': 'Sembako', 'value': 12, 'color': const Color(0xFF2196F3)},
    {'name': 'Instan', 'value': 8, 'color': const Color(0xFFFF5252)},
  ];
  
  final List<Map<String, dynamic>> _topProducts = [
    {'name': 'Keripik Singkong', 'sales': 145, 'revenue': 2175000.0, 'trend': '+12%'},
    {'name': 'Air Mineral 600ml', 'sales': 120, 'revenue': 480000.0, 'trend': '+8%'},
    {'name': 'Beras Premium 5kg', 'sales': 45, 'revenue': 2925000.0, 'trend': '+15%'},
    {'name': 'Es Krim Coklat', 'sales': 30, 'revenue': 360000.0, 'trend': '-3%'},
    {'name': 'Mie Instan Goreng', 'sales': 25, 'revenue': 87500.0, 'trend': '+5%'},
  ];
  
  final List<Map<String, dynamic>> _lowStockProducts = [
    {'name': 'Beras Premium 5kg', 'stock': 3, 'threshold': 10},
    {'name': 'Es Krim Vanila', 'stock': 5, 'threshold': 10},
    {'name': 'Keripik Singkong Balado', 'stock': 8, 'threshold': 15},
  ];
  
  final List<Map<String, dynamic>> _recentOrders = [
    {
      'id': 'INV-2025-001',
      'customer': 'Ahmad Fauzi',
      'total': 34000,
      'status': 'Diproses',
      'statusColor': const Color(0xFFFF9B5EFF),
      'date': '15 Jun 2025',
    },
    {
      'id': 'INV-2025-002',
      'customer': 'Siti Rahma',
      'total': 75500,
      'status': 'Dikirim',
      'statusColor': const Color(0xFF4CAF50),
      'date': '14 Jun 2025',
    },
    {
      'id': 'INV-2025-003',
      'customer': 'Budi Santoso',
      'total': 34000,
      'status': 'Selesai',
      'statusColor': const Color(0xFF2196F3),
      'date': '13 Jun 2025',
    },
  ];

  final List<Map<String, dynamic>> _menuItems = [
    {
      'title': 'Kelola Produk',
      'subtitle': 'Tambah, edit, hapus produk',
      'icon': Icons.inventory_2_outlined,
      'color': const Color(0xFF9B5EFF),
      'page': const OwnerProductsPage(),
    },
    {
      'title': 'Laporan Penjualan',
      'subtitle': 'Lihat laporan & analisis',
      'icon': Icons.assessment_outlined,
      'color': const Color(0xFF4CAF50),
      'page': const OwnerReportsPage(),
    },
    {
      'title': 'Manajemen User',
      'subtitle': 'Kelola akses karyawan',
      'icon': Icons.people_outline,
      'color': const Color(0xFF2196F3),
      'page': const OwnerManageRolePage(),
    },
  ];

  Map<String, dynamic> get _kpiData {
    return {
      'totalRevenue': 1234500.0,
      'totalOrders': 45,
      'totalCustomers': 128,
      'totalProducts': 67,
      'averageOrderValue': 1234500.0 / 45,
      'retentionRate': 0.78,
      'inventoryTurnover': 4.5,
    };
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
        
        return AlertDialog(
          backgroundColor: theme.cardTheme.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
            ),
          ),
          title: Text(
            "Konfirmasi Logout",
            style: GoogleFonts.poppins(
              color: theme.textTheme.titleLarge?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            "Apakah Anda yakin ingin keluar?",
            style: GoogleFonts.inter(
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Batal",
                style: GoogleFonts.inter(
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (route) => false,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Berhasil logout",
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                    backgroundColor: Colors.green.shade400,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    duration: const Duration(seconds: 2),
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
                "Logout",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatPrice(num price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return 'Rp ${(value / 1000000).toStringAsFixed(1)}Jt';
    } else if (value >= 1000) {
      return 'Rp ${(value / 1000).toStringAsFixed(0)}Rb';
    }
    return 'Rp ${_formatPrice(value)}';
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
            _buildHeader(isDark, isTablet, hPad),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeSection(isTablet, isDark),
                    const SizedBox(height: 20),
                    _buildPeriodSelector(isDark),
                    const SizedBox(height: 16),
                    _buildKPICards(isTablet, isDark),
                    const SizedBox(height: 24),
                    _buildSectionTitle("Analisis Data Penjualan", isDark),
                    const SizedBox(height: 12),
                    _buildChartTabs(isDark),
                    const SizedBox(height: 12),
                    _buildChartContent(isDark),
                    const SizedBox(height: 24),
                    _buildSectionTitle("Top 5 Produk Terlaris", isDark),
                    const SizedBox(height: 12),
                    _buildTopProducts(isDark),
                    const SizedBox(height: 24),
                    _buildSectionTitle("⚠️ Alert Stok Menipis", isDark),
                    const SizedBox(height: 12),
                    _buildLowStockAlert(isDark),
                    const SizedBox(height: 24),
                    _buildSectionTitle("Menu Manajemen", isDark),
                    const SizedBox(height: 12),
                    _buildMenuGrid(isTablet, isDark),
                    const SizedBox(height: 24),
                    _buildSectionTitle("Pesanan Terbaru", isDark),
                    const SizedBox(height: 12),
                    _buildRecentOrders(isDark),
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

  Widget _buildHeader(bool isDark, bool isTablet, double hPad) {
    return Container(
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
          Expanded(
            child: Text(
              "Dashboard Owner",
              style: GoogleFonts.poppins(
                color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                fontSize: isTablet ? 26 : 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Row(
            children: [
              const ThemeToggleButton(),
              const SizedBox(width: 8),
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
                child: Stack(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: Icon(
                        Icons.notifications_outlined,
                        color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF4B5563),
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF5252),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.red.shade400.withOpacity(0.15)
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.red.shade400.withOpacity(0.3)
                        : Colors.red.shade200,
                  ),
                ),
                child: IconButton(
                  onPressed: _logout,
                  icon: Icon(
                    Icons.logout,
                    color: isDark ? Colors.red.shade400 : Colors.red.shade400,
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(bool isTablet, bool isDark) {
    final kpi = _kpiData;
    
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
            color: const Color(0xFF9B5EFF).withOpacity(0.3),
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
                  "Selamat Pagi, Owner! 👋",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: isTablet ? 22 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Total pendapatan hari ini: ${_formatCurrency(kpi['totalRevenue'])}",
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: isTablet ? 16 : 13,
                  ),
                ),
                if (isTablet) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildWelcomeBadge(
                        Icons.trending_up,
                        "Naik 12.5%",
                        Colors.green,
                      ),
                      const SizedBox(width: 12),
                      _buildWelcomeBadge(
                        Icons.people,
                        "${kpi['totalCustomers']} pelanggan",
                        Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _buildWelcomeBadge(
                        Icons.shopping_bag,
                        "${kpi['totalOrders']} pesanan",
                        Colors.orange,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: isTablet ? 60 : 44,
            height: isTablet ? 60 : 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.analytics,
              color: Colors.white,
              size: isTablet ? 32 : 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    final periods = ["Hari Ini", "Minggu Ini", "Bulan Ini"];
    return Row(
      children: periods.asMap().entries.map((entry) {
        final index = entry.key;
        final label = entry.value;
        final isSelected = _selectedPeriod == index;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedPeriod = index),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF9B5EFF)
                    : isDark
                        ? const Color(0xFF16162A)
                        : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF9B5EFF)
                      : isDark
                          ? const Color(0xFF1E1E35)
                          : const Color(0xFFE5E7EB),
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: isSelected
                        ? Colors.white
                        : isDark
                            ? const Color(0xFF9B97B8)
                            : const Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKPICards(bool isTablet, bool isDark) {
    final theme = Theme.of(context);
    final kpi = _kpiData;
    
    final kpiCards = [
      {
        'title': 'Total Pendapatan',
        'value': _formatCurrency(kpi['totalRevenue']),
        'icon': Icons.attach_money,
        'color': const Color(0xFF4CAF50),
        'subtitle': '${kpi['totalOrders']} pesanan',
      },
      {
        'title': 'Rata-rata Pesanan',
        'value': _formatCurrency(kpi['averageOrderValue']),
        'icon': Icons.shopping_cart_outlined,
        'color': const Color(0xFF9B5EFF),
        'subtitle': 'Rp ${_formatPrice(kpi['averageOrderValue'])}',
      },
      {
        'title': 'Retensi Pelanggan',
        'value': '${(kpi['retentionRate'] * 100).toInt()}%',
        'icon': Icons.people_outline,
        'color': const Color(0xFF2196F3),
        'subtitle': '${kpi['totalCustomers']} pelanggan',
      },
      {
        'title': 'Perputaran Stok',
        'value': kpi['inventoryTurnover'].toStringAsFixed(1),
        'icon': Icons.inventory_2_outlined,
        'color': const Color(0xFFFF9800),
        'subtitle': '${kpi['totalProducts']} produk',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 4 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.3,
      ),
      itemCount: kpiCards.length,
      itemBuilder: (context, index) {
        final card = kpiCards[index];
        final color = card['color'] as Color;
        
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(14),
            border: isDark ? Border.all(color: const Color(0xFF1E1E35)) : null,
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
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
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(card['icon'] as IconData, color: color, size: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: index % 2 == 0
                          ? Colors.green.withOpacity(0.15)
                          : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      index % 2 == 0 ? '📈 +${12 - index * 3}%' : '📊 ${index * 2}x',
                      style: GoogleFonts.inter(
                        color: index % 2 == 0
                            ? Colors.green.shade400
                            : Colors.orange.shade400,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card['title'] as String,
                    style: GoogleFonts.inter(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    card['value'] as String,
                    style: GoogleFonts.poppins(
                      color: theme.textTheme.titleLarge?.color,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    card['subtitle'] as String,
                    style: GoogleFonts.inter(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartTabs(bool isDark) {
    final tabs = ['Penjualan', 'Kategori', 'Pelanggan'];
    
    return Row(
      children: tabs.asMap().entries.map((entry) {
        final index = entry.key;
        final label = entry.value;
        final isSelected = _selectedChartTab == index;
        
        return GestureDetector(
          onTap: () => setState(() => _selectedChartTab = index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF9B5EFF)
                  : isDark
                      ? const Color(0xFF16162A)
                      : Colors.white,
              borderRadius: BorderRadius.circular(20),
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
                color: isSelected ? Colors.white : (isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280)),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChartContent(bool isDark) {
    switch (_selectedChartTab) {
      case 0:
        return _buildSalesChart(isDark);
      case 1:
        return _buildCategoryChart(isDark);
      case 2:
        return _buildCustomerChart(isDark);
      default:
        return _buildSalesChart(isDark);
    }
  }

  Widget _buildSalesChart(bool isDark) {
    final theme = Theme.of(context);
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "💰 Tren Penjualan (Rp Juta)",
                style: GoogleFonts.inter(
                  color: theme.textTheme.bodySmall?.color,
                  fontSize: 11,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "📈 +12.5%",
                  style: GoogleFonts.inter(
                    color: Colors.green.shade400,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < _weekDays.length) {
                          return Text(
                            _weekDays[value.toInt()],
                            style: GoogleFonts.inter(
                              color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                              fontSize: 10,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: GoogleFonts.inter(
                            color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _weeklySales.asMap().entries.map((e) => 
                      FlSpot(e.key.toDouble(), e.value)
                    ).toList(),
                    isCurved: true,
                    color: const Color(0xFF9B5EFF),
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF9B5EFF).withOpacity(0.15),
                    ),
                  ),
                ],
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart(bool isDark) {
    final theme = Theme.of(context);
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
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
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: PieChart(
              PieChartData(
                sections: _topCategories.map((category) {
                  return PieChartSectionData(
                    color: category['color'] as Color,
                    value: (category['value'] as int).toDouble(),
                    title: '',
                    radius: 60,
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _topCategories.map((category) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: category['color'] as Color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          category['name'] as String,
                          style: GoogleFonts.inter(
                            color: theme.textTheme.bodyMedium?.color,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Text(
                        '${category['value']}%',
                        style: GoogleFonts.inter(
                          color: theme.textTheme.titleLarge?.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerChart(bool isDark) {
    final theme = Theme.of(context);
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "👥 Pelanggan Baru (7 Hari Terakhir)",
                style: GoogleFonts.inter(
                  color: theme.textTheme.bodySmall?.color,
                  fontSize: 11,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "📊 +5.2%",
                  style: GoogleFonts.inter(
                    color: Colors.blue.shade400,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < _weekDays.length) {
                          return Text(
                            _weekDays[value.toInt()],
                            style: GoogleFonts.inter(
                              color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                              fontSize: 10,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: GoogleFonts.inter(
                            color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _weeklySales.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value * 0.5,
                        color: const Color(0xFF9B5EFF),
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducts(bool isDark) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
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
        children: _topProducts.asMap().entries.map((entry) {
          final index = entry.key;
          final product = entry.value;
          final isFirst = index == 0;
          
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF3F4F6),
                  width: index < _topProducts.length - 1 ? 1 : 0,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isFirst
                        ? const Color(0xFFFFD700).withOpacity(0.2)
                        : isDark
                            ? const Color(0xFF1E1E35)
                            : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.inter(
                        color: isFirst
                            ? const Color(0xFFFFD700)
                            : theme.textTheme.bodySmall?.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'] as String,
                        style: GoogleFonts.inter(
                          color: theme.textTheme.titleLarge?.color,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${product['sales']} terjual',
                            style: GoogleFonts.inter(
                              color: theme.textTheme.bodySmall?.color,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: (product['trend'] as String).startsWith('+')
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product['trend'] as String,
                              style: GoogleFonts.inter(
                                color: (product['trend'] as String).startsWith('+')
                                    ? Colors.green.shade400
                                    : Colors.red.shade400,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatCurrency(product['revenue'] as double),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF9B5EFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLowStockAlert(bool isDark) {
    final theme = Theme.of(context);
    
    if (_lowStockProducts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.green.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 12),
            Text(
              "✅ Semua stok aman!",
              style: GoogleFonts.inter(
                color: Colors.green,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: _lowStockProducts.map((product) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF3F4F6),
                  width: product != _lowStockProducts.last ? 1 : 0,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning_amber,
                    color: Colors.red,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    product['name'] as String,
                    style: GoogleFonts.inter(
                      color: theme.textTheme.titleLarge?.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Sisa ${product['stock']} unit',
                    style: GoogleFonts.inter(
                      color: Colors.red.shade400,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _showSnackBar("📦 Restock ${product['name']} segera!", Colors.orange);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B5EFF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "Restock",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
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

  Widget _buildMenuGrid(bool isTablet, bool isDark) {
    final theme = Theme.of(context);
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 3 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: _menuItems.length,
      itemBuilder: (context, index) {
        final item = _menuItems[index];
        final color = item['color'] as Color;
        final icon = item['icon'] as IconData;
        final title = item['title'] as String;
        final subtitle = item['subtitle'] as String;
        final page = item['page'] as Widget;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => page),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(14),
              border: isDark ? Border.all(color: const Color(0xFF1E1E35)) : null,
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 9,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentOrders(bool isDark) {
    final theme = Theme.of(context);
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentOrders.length,
      itemBuilder: (context, index) {
        final order = _recentOrders[index];
        final statusColor = order['statusColor'] as Color;
        final total = order['total'] as int;
        
        final String id = order['id']?.toString() ?? '';
        final String status = order['status']?.toString() ?? '';
        final String customer = order['customer']?.toString() ?? '';
        final String date = order['date']?.toString() ?? '';
        
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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          id,
                          style: GoogleFonts.inter(
                            color: theme.textTheme.titleLarge?.color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: statusColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.inter(
                              color: statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Rp ${_formatPrice(total)}",
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF9B5EFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    date,
                    style: GoogleFonts.inter(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 10,
                    ),
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