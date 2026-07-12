// lib/features/owner/presentation/pages/owner_manage_role_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:kanzza_sales_app_fe/core/theme/theme_provider.dart';
import 'package:kanzza_sales_app_fe/routes.dart';

class OwnerManageRolePage extends StatefulWidget {
  const OwnerManageRolePage({super.key});

  @override
  State<OwnerManageRolePage> createState() => _OwnerManageRolePageState();
}

class _OwnerManageRolePageState extends State<OwnerManageRolePage> {
  // ==================== DATA DUMMY ====================
  List<Map<String, dynamic>> _users = [
    {'id': 1, 'name': 'Ahmad Fauzi', 'email': 'ahmad@kanzza.com', 'role': 'Owner', 'status': 'Aktif', 'joinDate': '01 Jan 2025'},
    {'id': 2, 'name': 'Siti Rahma', 'email': 'siti@kanzza.com', 'role': 'Kasir', 'status': 'Aktif', 'joinDate': '15 Feb 2025'},
    {'id': 3, 'name': 'Budi Santoso', 'email': 'budi@kanzza.com', 'role': 'Driver', 'status': 'Aktif', 'joinDate': '10 Mar 2025'},
    {'id': 4, 'name': 'Dewi Lestari', 'email': 'dewi@kanzza.com', 'role': 'Kasir', 'status': 'Nonaktif', 'joinDate': '20 Apr 2025'},
    {'id': 5, 'name': 'Rina Setiawan', 'email': 'rina@kanzza.com', 'role': 'Driver', 'status': 'Aktif', 'joinDate': '05 Mei 2025'},
  ];

  final List<String> _roles = ['Owner', 'Kasir', 'Driver'];
  final List<String> _statusOptions = ['Aktif', 'Nonaktif'];

  // ==================== STATE ====================
  String _filterRole = 'Semua';
  String _filterStatus = 'Semua';
  String _searchQuery = '';

  // ==================== FORM CONTROLLERS ====================
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedRole = 'Kasir';
  String _selectedStatus = 'Aktif';
  bool _isLoading = false;

  // ==================== GETTER ====================
  List<Map<String, dynamic>> get _filteredUsers {
    var filtered = List<Map<String, dynamic>>.from(_users);
    if (_filterRole != 'Semua') {
      filtered = filtered.where((u) => u['role'] == _filterRole).toList();
    }
    if (_filterStatus != 'Semua') {
      filtered = filtered.where((u) => u['status'] == _filterStatus).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((u) =>
          u['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u['email'].toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    return filtered;
  }

  int get _totalUsers => _users.length;
  int get _activeUsers => _users.where((u) => u['status'] == 'Aktif').length;
  int get _inactiveUsers => _users.where((u) => u['status'] == 'Nonaktif').length;

  // ==================== FUNGSI ====================
  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _filterRole = 'Semua';
      _filterStatus = 'Semua';
      _searchQuery = '';
    });
  }

  void _resetForm() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _selectedRole = 'Kasir';
    _selectedStatus = 'Aktif';
  }

  void _saveUser() {
    // Validasi
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar("Nama harus diisi!", Colors.orange);
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar("Email harus diisi!", Colors.orange);
      return;
    }
    if (_passwordController.text.trim().isEmpty) {
      _showSnackBar("Password harus diisi!", Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulasi simpan data
    Future.delayed(const Duration(milliseconds: 500), () {
      final newUser = {
        'id': _users.length + 1,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'status': _selectedStatus,
        'joinDate': DateTime.now().toString().substring(0, 10),
      };

      setState(() {
        _users.insert(0, newUser);
        _isLoading = false;
      });

      _resetForm();
      Navigator.pop(context);
      _showSnackBar("✅ User berhasil ditambahkan!", Colors.green);
    });
  }

  void _showAddUserDialog() {
    _resetForm();
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF16162A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
            ),
          ),
          title: Text(
            "Tambah User",
            style: GoogleFonts.poppins(
              color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
              return SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nama
                    TextField(
                      controller: _nameController,
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        labelText: "Nama Lengkap",
                        labelStyle: GoogleFonts.inter(
                          color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                        ),
                        hintText: "Masukkan nama lengkap",
                        hintStyle: GoogleFonts.inter(
                          color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
                        ),
                        prefixIcon: Icon(Icons.person_outline,
                          color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0D0D12) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF9B5EFF), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Email
                    TextField(
                      controller: _emailController,
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                        fontSize: 14,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Email",
                        labelStyle: GoogleFonts.inter(
                          color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                        ),
                        hintText: "Masukkan email",
                        hintStyle: GoogleFonts.inter(
                          color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
                        ),
                        prefixIcon: Icon(Icons.email_outlined,
                          color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0D0D12) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF9B5EFF), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Password
                    TextField(
                      controller: _passwordController,
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                        fontSize: 14,
                      ),
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Password",
                        labelStyle: GoogleFonts.inter(
                          color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                        ),
                        hintText: "Masukkan password",
                        hintStyle: GoogleFonts.inter(
                          color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
                        ),
                        prefixIcon: Icon(Icons.lock_outline,
                          color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0D0D12) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF9B5EFF), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Role & Status
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedRole,
                            dropdownColor: isDark ? const Color(0xFF1E1E35) : Colors.white,
                            style: GoogleFonts.inter(
                              color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              labelText: "Role",
                              labelStyle: GoogleFonts.inter(
                                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                              ),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0D0D12) : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF9B5EFF), width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            items: _roles.map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Text(role),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setStateDialog(() {
                                  _selectedRole = value;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            dropdownColor: isDark ? const Color(0xFF1E1E35) : Colors.white,
                            style: GoogleFonts.inter(
                              color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              labelText: "Status",
                              labelStyle: GoogleFonts.inter(
                                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                              ),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0D0D12) : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF9B5EFF), width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            items: _statusOptions.map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setStateDialog(() {
                                  _selectedStatus = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                _resetForm();
                Navigator.pop(context);
              },
              child: Text(
                "Batal",
                style: GoogleFonts.inter(
                  color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B5EFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      "Simpan",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
          actionsPadding: const EdgeInsets.all(16),
        );
      },
    );
  }

  // ==================== BUILD ====================
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
            // HEADER
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
                      "Manajemen User",
                      style: GoogleFonts.poppins(
                        color: isDark
                            ? const Color(0xFFF0EAFF)
                            : const Color(0xFF1F2937),
                        fontSize: isTablet ? 26 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Tombol Tambah User
                  GestureDetector(
                    onTap: _showAddUserDialog,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9B5EFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // CONTENT
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Cards
                    _buildSummaryCards(isDark),
                    const SizedBox(height: 16),

                    // Filter & Search
                    _buildFilterSection(isDark),
                    const SizedBox(height: 16),

                    // User List
                    _buildUserList(isDark),
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

  // ==================== SUMMARY CARDS ====================
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
                  "Total User",
                  style: GoogleFonts.inter(
                    color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _totalUsers.toString(),
                  style: GoogleFonts.poppins(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: 20,
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
                  "Aktif",
                  style: GoogleFonts.inter(
                    color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _activeUsers.toString(),
                  style: GoogleFonts.poppins(
                    color: Colors.green.shade400,
                    fontSize: 20,
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
                  "Nonaktif",
                  style: GoogleFonts.inter(
                    color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _inactiveUsers.toString(),
                  style: GoogleFonts.poppins(
                    color: Colors.red.shade400,
                    fontSize: 20,
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

  // ==================== FILTER SECTION ====================
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
          // Search Bar
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: GoogleFonts.inter(
              color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: "Cari user...",
              hintStyle: GoogleFonts.inter(
                color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: Icon(
                        Icons.close,
                        color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                        size: 20,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF16162A) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF9B5EFF), width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),

          // Filter Role & Status
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  label: "Role",
                  value: _filterRole,
                  items: ['Semua', 'Owner', 'Kasir', 'Driver'],
                  onChanged: (value) {
                    setState(() {
                      _filterRole = value!;
                    });
                  },
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFilterDropdown(
                  label: "Status",
                  value: _filterStatus,
                  items: ['Semua', 'Aktif', 'Nonaktif'],
                  onChanged: (value) {
                    setState(() {
                      _filterStatus = value!;
                    });
                  },
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _resetFilters,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF16162A) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Icon(
                    Icons.refresh,
                    color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16162A) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: isDark ? const Color(0xFF1E1E35) : Colors.white,
          style: GoogleFonts.inter(
            color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          icon: Icon(
            Icons.arrow_drop_down,
            color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
          ),
          isExpanded: true,
          hint: Text(
            label,
            style: GoogleFonts.inter(
              color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
              fontSize: 13,
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ==================== USER LIST ====================
  Widget _buildUserList(bool isDark) {
    final theme = Theme.of(context);
    final users = _filteredUsers;

    if (users.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              "Tidak ada user",
              style: GoogleFonts.inter(
                color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Klik + untuk menambahkan user",
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
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isActive = user['status'] == 'Aktif';
        final roleColor = user['role'] == 'Owner'
            ? const Color(0xFF9B5EFF)
            : user['role'] == 'Kasir'
                ? const Color(0xFF4CAF50)
                : const Color(0xFFFF9800);

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
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    user['name'][0].toUpperCase(),
                    style: GoogleFonts.inter(
                      color: roleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['name'],
                      style: GoogleFonts.inter(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          user['email'],
                          style: GoogleFonts.inter(
                            color: theme.textTheme.bodySmall?.color,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: roleColor.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            user['role'],
                            style: GoogleFonts.inter(
                              color: roleColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Bergabung: ${user['joinDate']}",
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.withOpacity(0.15)
                      : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isActive
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  user['status'],
                  style: GoogleFonts.inter(
                    color: isActive ? Colors.green.shade400 : Colors.red.shade400,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}