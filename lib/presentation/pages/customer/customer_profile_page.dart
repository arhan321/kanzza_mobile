// lib/presentation/pages/customer/customer_profile_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/models/address.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/address_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../routes.dart';
import '../../providers/customer_cart_provider.dart';
import '../../providers/customer_notification_provider.dart';
import 'customer_addresses_page.dart';
import 'customer_cart_page.dart';
import 'customer_orders_page.dart';

class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({super.key});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  final UserRepository _userRepository = UserRepository();
  final AddressRepository _addressRepository = AddressRepository();

  UserModel? _user;
  List<AddressModel> _addresses = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoggingOut = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile({bool isRefresh = false}) async {
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
          _user = cachedUser;
        });
      }

      final results = await Future.wait<dynamic>([
        _userRepository.getProfile(),
        _addressRepository.getAddresses(),
      ]);

      final user = results[0] as UserModel;
      final addresses = results[1] as List<AddressModel>;

      if (!mounted) {
        return;
      }

      setState(() {
        _user = user;
        _addresses = addresses;
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
        return;
      }

      _handleError(error.firstValidationError);
    } catch (error) {
      debugPrint('LOAD CUSTOMER PROFILE ERROR: $error');

      _handleError('Profil gagal dimuat. Silakan coba kembali.');
    }
  }

  void _handleError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _isRefreshing = false;
      _errorMessage = message;
    });
  }

  Future<void> _handleUnauthorized() async {
    await _userRepository.clearLocalSession();

    if (!mounted) {
      return;
    }

    context.read<CustomerNotificationProvider>().clear();

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Future<void> _refresh() async {
    if (_isRefreshing) {
      return;
    }

    await _loadProfile(isRefresh: true);
  }

  Future<void> _openAddresses() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerAddressesPage()),
    );

    if (!mounted) {
      return;
    }

    await _refresh();
  }

  Future<void> _openOrders() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerOrdersPage()),
    );
  }

  Future<void> _openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomerCartPage()),
    );
  }

  Future<void> _showLogoutConfirmation() async {
    if (_isLoggingOut) {
      return;
    }

    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
            ),
          ),
          title: Text(
            'Konfirmasi Logout',
            style: GoogleFonts.poppins(
              color: theme.textTheme.titleLarge?.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar dari akun ini?',
            style: GoogleFonts.inter(
              color: theme.textTheme.bodyMedium?.color,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
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

    context.read<CustomerNotificationProvider>().clear();

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  AddressModel? get _defaultAddress {
    for (final address in _addresses) {
      if (address.isDefault) {
        return address;
      }
    }

    return _addresses.isNotEmpty ? _addresses.first : null;
  }

  String get _initials {
    final name = _user?.name.trim() ?? '';

    if (name.isEmpty) {
      return 'U';
    }

    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
            '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }

    return DateFormat('dd MMM yyyy').format(value.toLocal());
  }

  void _showUnsupportedFeature(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$feature belum tersedia karena backend belum menyediakan endpoint-nya.',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: Colors.orange.shade500,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final cartProvider = context.watch<CustomerCartProvider>();
    final isDark = themeProvider.isDarkMode;
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width * 0.04;
    final isTablet = width > 600;

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
        child: SafeArea(
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
                  cartItems: cartProvider.totalItems,
                ),
              ),
            ],
          ),
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
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        14,
        horizontalPadding,
        14,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13102A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
          ),
        ),
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
            child: Text(
              'Profil Saya',
              style: GoogleFonts.poppins(
                color: theme.textTheme.titleLarge?.color,
                fontSize: isTablet ? 24 : 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
                      color: Color(0xFF9B5EFF),
                      strokeWidth: 2,
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
    required int cartItems,
  }) {
    if (_isLoading && _user == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF9B5EFF)),
      );
    }

    if (_errorMessage != null && _user == null) {
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
          18,
          horizontalPadding,
          30,
        ),
        children: [
          _buildProfileHero(isDark),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _buildInlineError(),
          ],
          const SizedBox(height: 22),
          _sectionTitle('Informasi Akun'),
          const SizedBox(height: 10),
          _buildAccountInformation(isDark),
          const SizedBox(height: 22),
          _sectionTitle('Aktivitas Customer'),
          const SizedBox(height: 10),
          _buildActivityMenu(isDark: isDark, cartItems: cartItems),
          const SizedBox(height: 22),
          _sectionTitle('Pengaturan'),
          const SizedBox(height: 10),
          _buildSettings(isDark),
          const SizedBox(height: 22),
          _buildBackendNotice(isDark),
          const SizedBox(height: 18),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildProfileHero(bool isDark) {
    final user = _user;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9B5EFF), Color(0xFF6C3BD8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B5EFF).withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.34),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 31,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 13),
          Text(
            user?.name ?? 'Customer',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            user?.email ?? '-',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 7,
            runSpacing: 7,
            children: [
              _heroBadge(label: 'Customer', icon: Icons.person_outline_rounded),
              _heroBadge(
                label: user?.isActive == true
                    ? 'Akun Aktif'
                    : 'Akun ${user?.status ?? '-'}',
                icon: Icons.verified_user_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroBadge({required String label, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    final theme = Theme.of(context);

    return Text(
      title,
      style: GoogleFonts.poppins(
        color: theme.textTheme.titleLarge?.color,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildAccountInformation(bool isDark) {
    return _card(
      isDark: isDark,
      child: Column(
        children: [
          _informationRow(
            icon: Icons.person_outline,
            label: 'Nama lengkap',
            value: _user?.name ?? '-',
          ),
          _divider(isDark),
          _informationRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: _user?.email ?? '-',
          ),
          _divider(isDark),
          _informationRow(
            icon: Icons.phone_outlined,
            label: 'Nomor telepon',
            value: _user?.phone ?? 'Belum diisi',
          ),
          _divider(isDark),
          _informationRow(
            icon: Icons.calendar_month_outlined,
            label: 'Terdaftar sejak',
            value: _formatDate(_user?.createdAt),
          ),
          _divider(isDark),
          _informationRow(
            icon: Icons.login_rounded,
            label: 'Login terakhir',
            value: _formatDate(_user?.lastLoginAt),
          ),
        ],
      ),
    );
  }

  Widget _informationRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF9B5EFF).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF9B5EFF), size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityMenu({required bool isDark, required int cartItems}) {
    final defaultAddress = _defaultAddress;

    return _card(
      isDark: isDark,
      child: Column(
        children: [
          _menuItem(
            icon: Icons.receipt_long_outlined,
            title: 'Pesanan Saya',
            subtitle: 'Lihat status dan riwayat pesanan',
            trailingText: null,
            onTap: _openOrders,
          ),
          _divider(isDark),
          _menuItem(
            icon: Icons.shopping_cart_outlined,
            title: 'Keranjang Belanja',
            subtitle: 'Produk yang akan dibeli',
            trailingText: '$cartItems item',
            onTap: _openCart,
          ),
          _divider(isDark),
          _menuItem(
            icon: Icons.location_on_outlined,
            title: 'Alamat Saya',
            subtitle: defaultAddress == null
                ? 'Belum ada alamat tersimpan'
                : '${defaultAddress.label} • ${defaultAddress.fullAddress}',
            trailingText: '${_addresses.length}',
            onTap: _openAddresses,
          ),
        ],
      ),
    );
  }

  Widget _buildSettings(bool isDark) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return _card(
      isDark: isDark,
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            value: themeProvider.isDarkMode,
            activeThumbColor: const Color(0xFF9B5EFF),
            onChanged: (value) {
              themeProvider.setDarkMode(value);
            },
            secondary: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF9B5EFF).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                themeProvider.isDarkMode
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                color: const Color(0xFF9B5EFF),
              ),
            ),
            title: Text(
              'Mode Gelap',
              style: GoogleFonts.inter(
                color: Theme.of(context).textTheme.titleLarge?.color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Sesuaikan tampilan aplikasi',
              style: GoogleFonts.inter(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 10,
              ),
            ),
          ),
          _divider(isDark),
          _menuItem(
            icon: Icons.edit_outlined,
            title: 'Edit Profil',
            subtitle: 'Nama dan nomor telepon',
            trailingText: null,
            onTap: () {
              _showUnsupportedFeature('Edit profil');
            },
          ),
          _divider(isDark),
          _menuItem(
            icon: Icons.lock_outline_rounded,
            title: 'Ubah Password',
            subtitle: 'Perbarui keamanan akun',
            trailingText: null,
            onTap: () {
              _showUnsupportedFeature('Ubah password');
            },
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String? trailingText,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF9B5EFF).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF9B5EFF), size: 19),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: theme.textTheme.titleLarge?.color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          color: theme.textTheme.bodySmall?.color,
          fontSize: 10,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF9B5EFF).withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                trailingText,
                style: GoogleFonts.inter(
                  color: const Color(0xFF9B5EFF),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 5),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.textTheme.bodySmall?.color,
          ),
        ],
      ),
    );
  }

  Widget _buildBackendNotice(bool isDark) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.orange.shade500,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Data akun diambil langsung dari Laravel. '
              'Edit profil dan ubah password belum diaktifkan '
              'karena endpoint backend untuk kedua fitur tersebut belum tersedia.',
              style: GoogleFonts.inter(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoggingOut ? null : _showLogoutConfirmation,
        icon: _isLoggingOut
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.logout_rounded),
        label: Text(_isLoggingOut ? 'Sedang Logout...' : 'Logout'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade400,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _card({required bool isDark, required Widget child}) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 9,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: child,
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
      height: 1,
    );
  }

  Widget _buildInlineError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade500),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(
                color: Colors.orange.shade600,
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

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF9B5EFF),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.70,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: Colors.red.shade300,
                      size: 64,
                    ),
                    const SizedBox(height: 17),
                    Text(
                      'Profil gagal dimuat',
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ??
                          'Terjadi kesalahan saat mengambil profil.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () {
                        _loadProfile();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9B5EFF),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
