// lib/presentation/pages/customer/customer_cart_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/models/cart_item.dart';
import '../../../data/repositories/product_repository.dart';
import '../../providers/customer_cart_provider.dart';
import 'customer_checkout_page.dart';

class CustomerCartPage extends StatefulWidget {
  const CustomerCartPage({super.key});

  @override
  State<CustomerCartPage> createState() => _CustomerCartPageState();
}

class _CustomerCartPageState extends State<CustomerCartPage> {
  final ProductRepository _productRepository = ProductRepository();

  bool _isRefreshing = false;
  String? _refreshError;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCart();
    });
  }

  Future<void> _initializeCart() async {
    final cartProvider = context.read<CustomerCartProvider>();

    await cartProvider.initialize(force: true);

    if (!mounted) {
      return;
    }

    await _refreshProducts();
  }

  Future<void> _refreshProducts() async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
      _refreshError = null;
    });

    try {
      final products = await _productRepository.getProducts(
        isActive: true,
        perPage: 100,
      );

      if (!mounted) {
        return;
      }

      await context.read<CustomerCartProvider>().synchronizeProducts(products);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _refreshError = error.firstValidationError;
      });
    } catch (error) {
      debugPrint('REFRESH CUSTOMER CART PRODUCTS ERROR: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _refreshError = 'Gagal memperbarui harga dan stok produk.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _updateQuantity(CartItem item, int quantity) async {
    final result = await context.read<CustomerCartProvider>().updateQuantity(
      productId: item.id,
      quantity: quantity,
    );

    if (!mounted || result.success) {
      return;
    }

    _showSnackBar(result.message, Colors.orange.shade500);
  }

  Future<void> _removeItem(CartItem item) async {
    await context.read<CustomerCartProvider>().removeItem(item.id);

    if (!mounted) {
      return;
    }

    _showSnackBar('${item.name} dihapus dari keranjang.', Colors.red.shade400);
  }

  Future<void> _checkout() async {
    final cartProvider = context.read<CustomerCartProvider>();

    if (cartProvider.items.isEmpty) {
      _showSnackBar('Keranjang Anda masih kosong.', Colors.orange.shade500);
      return;
    }

    if (cartProvider.hasInvalidItems) {
      _showSnackBar(
        'Terdapat produk yang tidak tersedia atau '
        'jumlahnya melebihi stok.',
        Colors.red.shade400,
      );
      return;
    }

    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerCheckoutPage(
          totalPrice: cartProvider.totalPrice,
          cartItems: cartProvider.checkoutSnapshot(),
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result == true) {
      await cartProvider.clear();
    }
  }

  Future<void> _showDeleteAllDialog() async {
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;
    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
            ),
          ),
          title: Text(
            'Hapus Semua Item?',
            style: GoogleFonts.poppins(
              color: theme.textTheme.titleLarge?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin mengosongkan '
            'keranjang belanja?',
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
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                'Hapus Semua',
                style: GoogleFonts.inter(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await context.read<CustomerCartProvider>().clear();

    if (!mounted) {
      return;
    }

    _showSnackBar('Keranjang berhasil dikosongkan.', Colors.red.shade400);
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final cartProvider = context.watch<CustomerCartProvider>();
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
              cartProvider: cartProvider,
              horizontalPadding: horizontalPadding,
              isDark: isDark,
              isTablet: isTablet,
            ),
            Expanded(
              child: _buildBody(
                cartProvider: cartProvider,
                horizontalPadding: horizontalPadding,
                isDark: isDark,
              ),
            ),
            if (!cartProvider.isLoading && cartProvider.items.isNotEmpty)
              _buildCheckoutSection(
                cartProvider: cartProvider,
                horizontalPadding: horizontalPadding,
                isDark: isDark,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({
    required CustomerCartProvider cartProvider,
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
                  'Keranjang Belanja',
                  style: GoogleFonts.poppins(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: isTablet ? 24 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${cartProvider.totalItems} item • '
                  'Rp ${_formatPrice(cartProvider.totalPrice)}',
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Perbarui harga dan stok',
            onPressed: _isRefreshing ? null : _refreshProducts,
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
          if (cartProvider.items.isNotEmpty) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Kosongkan keranjang',
              onPressed: _showDeleteAllDialog,
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.10),
                foregroundColor: Colors.red.shade400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody({
    required CustomerCartProvider cartProvider,
    required double horizontalPadding,
    required bool isDark,
  }) {
    if (cartProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF9B5EFF)),
      );
    }

    if (cartProvider.items.isEmpty) {
      return _buildEmptyCart(isDark);
    }

    return RefreshIndicator(
      onRefresh: _refreshProducts,
      color: const Color(0xFF9B5EFF),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          16,
          horizontalPadding,
          24,
        ),
        children: [
          if (_refreshError != null) ...[
            _buildWarningBanner(
              message: _refreshError!,
              color: Colors.orange.shade500,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 12),
          ],
          if (cartProvider.hasInvalidItems) ...[
            _buildWarningBanner(
              message:
                  'Beberapa produk tidak tersedia atau '
                  'stoknya berubah. Periksa kembali sebelum checkout.',
              color: Colors.red.shade400,
              icon: Icons.error_outline_rounded,
            ),
            const SizedBox(height: 12),
          ],
          ...cartProvider.items.map(
            (item) => _buildCartItem(item: item, isDark: isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner({
    required String message,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(color: color, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem({required CartItem item, required bool isDark}) {
    final theme = Theme.of(context);
    final unavailable = !item.isAvailable;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unavailable
              ? Colors.red.withValues(alpha: 0.34)
              : isDark
              ? const Color(0xFF1E1E35)
              : const Color(0xFFE5E7EB),
        ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProductImage(item: item, isDark: isDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rp ${_formatPrice(item.price)}',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF9B5EFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _buildItemBadge(
                      text: unavailable
                          ? 'Tidak tersedia'
                          : 'Stok ${item.stock} ${item.unit}',
                      color: unavailable
                          ? Colors.red.shade400
                          : item.stock <= 5
                          ? Colors.orange.shade500
                          : Colors.green.shade500,
                    ),
                    _buildItemBadge(
                      text: 'Subtotal Rp ${_formatPrice(item.subtotal)}',
                      color: const Color(0xFF9B5EFF),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildQuantityButton(
                      icon: Icons.remove_rounded,
                      onPressed: () {
                        _updateQuantity(item, item.quantity - 1);
                      },
                      isDark: isDark,
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 42),
                      alignment: Alignment.center,
                      child: Text(
                        '${item.quantity}',
                        style: GoogleFonts.poppins(
                          color: theme.textTheme.titleLarge?.color,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _buildQuantityButton(
                      icon: Icons.add_rounded,
                      onPressed: item.canIncrease
                          ? () {
                              _updateQuantity(item, item.quantity + 1);
                            }
                          : null,
                      isDark: isDark,
                      isPrimary: true,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Hapus',
                      onPressed: () {
                        _removeItem(item);
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.10),
                        foregroundColor: Colors.red.shade400,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage({required CartItem item, required bool isDark}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 76,
        height: 90,
        color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF1EDFF),
        child: item.imageUrl.trim().isEmpty
            ? Center(
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: const Color(0xFF9B5EFF).withValues(alpha: 0.50),
                  size: 32,
                ),
              )
            : Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: const Color(0xFF9B5EFF).withValues(alpha: 0.50),
                      size: 32,
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF9B5EFF),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildItemBadge({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
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

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isDark,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 31,
        height: 31,
        decoration: BoxDecoration(
          color: onPressed == null
              ? Theme.of(context).disabledColor.withValues(alpha: 0.08)
              : isPrimary
              ? const Color(0xFF9B5EFF).withValues(alpha: 0.16)
              : isDark
              ? const Color(0xFF1E1E35)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: onPressed == null
              ? Theme.of(context).disabledColor
              : isPrimary
              ? const Color(0xFF9B5EFF)
              : Theme.of(context).textTheme.bodyMedium?.color,
          size: 17,
        ),
      ),
    );
  }

  Widget _buildCheckoutSection({
    required CustomerCartProvider cartProvider,
    required double horizontalPadding,
    required bool isDark,
  }) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          14,
          horizontalPadding,
          14,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16162A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
            ),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total Belanja',
                    style: GoogleFonts.inter(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  'Rp ${_formatPrice(cartProvider.totalPrice)}',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF9B5EFF),
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${cartProvider.totalItems} item',
                    style: GoogleFonts.inter(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 10,
                    ),
                  ),
                ),
                Text(
                  'Ongkir dihitung saat checkout',
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: cartProvider.hasInvalidItems ? null : _checkout,
                icon: const Icon(Icons.shopping_cart_checkout, size: 19),
                label: const Text('Lanjutkan ke Checkout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B5EFF),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark
                      ? const Color(0xFF5C5878)
                      : const Color(0xFFD1D5DB),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart(bool isDark) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refreshProducts,
      color: const Color(0xFF9B5EFF),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.68,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF16162A)
                            : const Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shopping_cart_outlined,
                        size: 50,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Keranjang Kosong',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Produk yang ditambahkan dari halaman '
                      'customer akan muncul di sini.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.5,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    if (_refreshError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _refreshError!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.orange.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.maybePop(context);
                      },
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('Belanja Sekarang'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9B5EFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
    );
  }
}
