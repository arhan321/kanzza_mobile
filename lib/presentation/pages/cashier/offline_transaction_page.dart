// Nama file dan class tetap dipertahankan agar route lama tidak rusak.
// Halaman ini sekarang merupakan transaksi kasir online ke Laravel,
// bukan penyimpanan transaksi offline di memori perangkat.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/models/cashier_transaction.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/cashier_transaction_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../routes.dart';

class OfflineTransactionPage extends StatefulWidget {
  const OfflineTransactionPage({super.key});

  @override
  State<OfflineTransactionPage> createState() => _OfflineTransactionPageState();
}

class _OfflineTransactionPageState extends State<OfflineTransactionPage> {
  final ProductRepository _productRepository = ProductRepository();
  final CashierTransactionRepository _cashierTransactionRepository =
      CashierTransactionRepository();
  final UserRepository _userRepository = UserRepository();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _cashReceivedController = TextEditingController();

  final List<CategoryModel> _categories = [];
  final List<ProductModel> _products = [];
  final List<_CashierCartItem> _cartItems = [];

  Timer? _searchDebounce;
  int? _selectedCategoryId;
  bool _isLoadingProducts = true;
  bool _isRefreshing = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _notesController.dispose();
    _cashReceivedController.dispose();
    super.dispose();
  }

  int get _estimatedTotal {
    return _cartItems.fold<int>(0, (total, item) => total + item.subtotal);
  }

  int get _cashReceived {
    final rawValue = _cashReceivedController.text
        .replaceAll('.', '')
        .replaceAll(',', '')
        .trim();

    return int.tryParse(rawValue) ?? 0;
  }

  int get _estimatedChange {
    final change = _cashReceived - _estimatedTotal;
    return change > 0 ? change : 0;
  }

  int get _totalCartQuantity {
    return _cartItems.fold<int>(0, (total, item) => total + item.quantity);
  }

  String? get _normalizedSearch {
    final search = _searchController.text.trim();
    return search.isEmpty ? null : search;
  }

  Future<void> _loadInitialData({bool isRefresh = false}) async {
    if (mounted) {
      setState(() {
        if (isRefresh) {
          _isRefreshing = true;
        } else {
          _isLoadingProducts = true;
        }

        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        _productRepository.getCategories(),
        _productRepository.getProducts(
          search: _normalizedSearch,
          categoryId: _selectedCategoryId,
          isActive: true,
          perPage: 100,
        ),
      ]);

      final categories = results[0] as List<CategoryModel>;
      final products = results[1] as List<ProductModel>;

      if (!mounted) {
        return;
      }

      setState(() {
        _categories
          ..clear()
          ..addAll(categories);

        _products
          ..clear()
          ..addAll(products);

        _synchronizeCartWithProducts();

        _isLoadingProducts = false;
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
      debugPrint('LOAD CASHIER PRODUCTS ERROR: $error');

      _handleLoadError('Produk gagal dimuat. Silakan coba kembali.');
    }
  }

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }

    try {
      final products = await _productRepository.getProducts(
        search: _normalizedSearch,
        categoryId: _selectedCategoryId,
        isActive: true,
        perPage: 100,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _products
          ..clear()
          ..addAll(products);

        _synchronizeCartWithProducts();
      });
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
        return;
      }

      _showSnackBar(error.firstValidationError, Colors.red.shade400);
    } catch (error) {
      debugPrint('FILTER CASHIER PRODUCTS ERROR: $error');

      _showSnackBar('Produk gagal dimuat.', Colors.red.shade400);
    }
  }

  void _synchronizeCartWithProducts() {
    for (final cartItem in _cartItems) {
      final productIndex = _products.indexWhere(
        (product) => product.id == cartItem.product.id,
      );

      if (productIndex == -1) {
        continue;
      }

      cartItem.product = _products[productIndex];

      if (cartItem.quantity > cartItem.product.stock) {
        cartItem.quantity = cartItem.product.stock;
      }
    }

    _cartItems.removeWhere(
      (item) => item.product.isOutOfStock || item.quantity <= 0,
    );
  }

  void _handleLoadError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingProducts = false;
      _isRefreshing = false;
      _errorMessage = message;
    });
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

  Future<void> _refresh() async {
    if (_isRefreshing) {
      return;
    }

    await _loadInitialData(isRefresh: true);
  }

  void _onSearchChanged(String value) {
    setState(() {});

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), _loadProducts);
  }

  void _selectCategory(int? categoryId) {
    if (_selectedCategoryId == categoryId) {
      return;
    }

    setState(() {
      _selectedCategoryId = categoryId;
    });

    _loadProducts();
  }

  void _addToCart(ProductModel product) {
    if (!product.canBeSold) {
      _showSnackBar(
        'Produk ${product.name} sedang tidak tersedia.',
        Colors.orange.shade500,
      );
      return;
    }

    final index = _cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (index >= 0) {
      final currentItem = _cartItems[index];

      if (currentItem.quantity >= product.stock) {
        _showSnackBar(
          'Jumlah tidak boleh melebihi stok ${product.stock} ${product.unit}.',
          Colors.orange.shade500,
        );
        return;
      }

      setState(() {
        currentItem.quantity++;
      });
    } else {
      setState(() {
        _cartItems.add(_CashierCartItem(product: product, quantity: 1));
      });
    }
  }

  void _decreaseQuantity(_CashierCartItem cartItem) {
    final index = _cartItems.indexOf(cartItem);

    if (index < 0) {
      return;
    }

    setState(() {
      if (cartItem.quantity <= 1) {
        _cartItems.removeAt(index);
      } else {
        cartItem.quantity--;
      }
    });
  }

  void _clearCart() {
    setState(() {
      _cartItems.clear();
      _cashReceivedController.clear();
      _notesController.clear();
    });
  }

  void _setExactCash() {
    final formatted = _formatPrice(_estimatedTotal);

    _cashReceivedController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );

    setState(() {});
  }

  void _onCashChanged(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      _cashReceivedController.clear();
      setState(() {});
      return;
    }

    final parsed = int.tryParse(digits) ?? 0;
    final formatted = _formatPrice(parsed);

    if (_cashReceivedController.text != formatted) {
      _cashReceivedController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    setState(() {});
  }

  Future<void> _submitTransaction() async {
    FocusScope.of(context).unfocus();

    if (_isSubmitting) {
      return;
    }

    if (_cartItems.isEmpty) {
      _showSnackBar(
        'Tambahkan produk terlebih dahulu.',
        Colors.orange.shade500,
      );
      return;
    }

    if (_cashReceived <= 0) {
      _showSnackBar(
        'Masukkan nominal uang yang diterima.',
        Colors.orange.shade500,
      );
      return;
    }

    if (_cashReceived < _estimatedTotal) {
      _showSnackBar(
        'Uang yang diterima kurang dari total transaksi.',
        Colors.red.shade400,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final transaction = await _cashierTransactionRepository.createTransaction(
        items: _cartItems
            .map(
              (item) => <String, int>{
                'product_id': item.product.id,
                'quantity': item.quantity,
              },
            )
            .toList(),
        paymentAmount: _cashReceived,
        notes: _notesController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      _clearCart();

      await _showSuccessDialog(transaction);

      if (!mounted) {
        return;
      }

      await _loadInitialData(isRefresh: true);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _handleUnauthorized();
        return;
      }

      if (!mounted) {
        return;
      }

      _showSnackBar(error.firstValidationError, Colors.red.shade400);
    } catch (error) {
      debugPrint('CREATE CASHIER TRANSACTION ERROR: $error');

      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Transaksi gagal disimpan. Silakan coba kembali.',
        Colors.red.shade400,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showSuccessDialog(CashierTransactionModel transaction) {
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16162A) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Transaksi Berhasil',
                    style: GoogleFonts.poppins(
                      color: isDark
                          ? const Color(0xFFF0EAFF)
                          : const Color(0xFF1F2937),
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    transaction.orderNumber,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9B5EFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0D0D12)
                          : const Color(0xFFF5F5FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1E1E35)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildSuccessRow(
                          label: 'Total',
                          value: 'Rp ${_formatPrice(transaction.grandTotal)}',
                          isDark: isDark,
                          valueColor: const Color(0xFF9B5EFF),
                        ),
                        const SizedBox(height: 10),
                        _buildSuccessRow(
                          label: 'Uang diterima',
                          value:
                              'Rp ${_formatPrice(transaction.paymentAmount)}',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _buildSuccessRow(
                          label: 'Kembalian',
                          value: 'Rp ${_formatPrice(transaction.changeAmount)}',
                          isDark: isDark,
                          valueColor: Colors.green.shade500,
                        ),
                        const SizedBox(height: 10),
                        _buildSuccessRow(
                          label: 'Jumlah item',
                          value: '${transaction.totalQuantity} item',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9B5EFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Selesai',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
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

  Widget _buildSuccessRow({
    required String label,
    required String value,
    required bool isDark,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color:
                valueColor ??
                (isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937)),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
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
            borderRadius: BorderRadius.circular(14),
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
    final isTablet = screenWidth > 700;

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
              child: isTablet
                  ? Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildProductSection(
                            horizontalPadding: horizontalPadding,
                            isDark: isDark,
                            isTablet: true,
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: isDark
                              ? const Color(0xFF1E1E35)
                              : const Color(0xFFE5E7EB),
                        ),
                        Expanded(
                          flex: 2,
                          child: _buildCartPanel(
                            isDark: isDark,
                            embedded: true,
                          ),
                        ),
                      ],
                    )
                  : _buildProductSection(
                      horizontalPadding: horizontalPadding,
                      isDark: isDark,
                      isTablet: false,
                    ),
            ),
            if (!isTablet)
              _buildMobileCartBar(
                horizontalPadding: horizontalPadding,
                isDark: isDark,
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
                  'Transaksi Kasir',
                  style: GoogleFonts.poppins(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: isTablet ? 24 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Pembayaran tunai dan tersimpan ke Laravel',
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Muat ulang produk',
            onPressed: _isLoadingProducts || _isRefreshing ? null : _refresh,
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
          if (_cartItems.isNotEmpty) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Kosongkan keranjang',
              onPressed: _isSubmitting ? null : _clearCart,
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

  Widget _buildProductSection({
    required double horizontalPadding,
    required bool isDark,
    required bool isTablet,
  }) {
    if (_isLoadingProducts) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF9B5EFF)),
      );
    }

    if (_errorMessage != null && _products.isEmpty) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF9B5EFF),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              14,
              horizontalPadding,
              0,
            ),
            sliver: SliverToBoxAdapter(child: _buildSearchField(isDark)),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              0,
            ),
            sliver: SliverToBoxAdapter(child: _buildCategoryFilter(isDark)),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              14,
              horizontalPadding,
              8,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(
                '${_products.length} produk ditemukan',
                style: GoogleFonts.inter(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          if (_products.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                24,
              ),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return _buildProductCard(
                    product: _products[index],
                    isDark: isDark,
                  );
                }, childCount: _products.length),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isTablet ? 3 : 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: isTablet ? 0.90 : 0.75,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    final theme = Theme.of(context);

    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      style: GoogleFonts.inter(
        color: theme.textTheme.titleLarge?.color,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: 'Cari nama produk atau SKU...',
        hintStyle: GoogleFonts.inter(
          color: theme.textTheme.bodySmall?.color,
          fontSize: 13,
        ),
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9B5EFF)),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                  _loadProducts();
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: theme.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF9B5EFF), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(bool isDark) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildCategoryChip(label: 'Semua', categoryId: null, isDark: isDark),
          ..._categories.map(
            (category) => _buildCategoryChip(
              label: category.name,
              categoryId: category.id,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required int? categoryId,
    required bool isDark,
  }) {
    final selected = _selectedCategoryId == categoryId;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) {
          _selectCategory(categoryId);
        },
        label: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? Colors.white : theme.textTheme.bodyMedium?.color,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        selectedColor: const Color(0xFF9B5EFF),
        backgroundColor: theme.cardColor,
        side: BorderSide(
          color: selected
              ? const Color(0xFF9B5EFF)
              : isDark
              ? const Color(0xFF1E1E35)
              : const Color(0xFFE5E7EB),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildProductCard({
    required ProductModel product,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final cartItem = _cartItems
        .where((item) => item.product.id == product.id)
        .firstOrNull;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _addToCart(product);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cartItem != null
                  ? const Color(0xFF9B5EFF)
                  : isDark
                  ? const Color(0xFF1E1E35)
                  : const Color(0xFFE5E7EB),
              width: cartItem != null ? 1.5 : 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: isDark
                            ? const Color(0xFF1E1E35)
                            : const Color(0xFFF1EDFF),
                        child: _buildProductImage(product),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: product.isOutOfStock
                                ? Colors.red.shade400
                                : product.isLowStock
                                ? Colors.orange.shade500
                                : Colors.green.shade500,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            product.isOutOfStock
                                ? 'Habis'
                                : 'Stok ${product.stock}',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (cartItem != null)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            width: 27,
                            height: 27,
                            decoration: const BoxDecoration(
                              color: Color(0xFF9B5EFF),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${cartItem.quantity}',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9B5EFF),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rp ${_formatPrice(product.sellingPrice)}',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF9B5EFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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

  Widget _buildProductImage(ProductModel product) {
    final imageUrl = product.imageUrl;

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return Center(
        child: Icon(
          Icons.inventory_2_rounded,
          color: const Color(0xFF9B5EFF).withValues(alpha: 0.50),
          size: 42,
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: const Color(0xFF9B5EFF).withValues(alpha: 0.50),
            size: 42,
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF9B5EFF),
            strokeWidth: 2,
          ),
        );
      },
    );
  }

  Widget _buildMobileCartBar({
    required double horizontalPadding,
    required bool isDark,
  }) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Material(
        color: theme.cardColor,
        child: InkWell(
          onTap: _showMobileCart,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? const Color(0xFF1E1E35)
                      : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.shopping_cart_outlined,
                      color: Color(0xFF9B5EFF),
                    ),
                    if (_totalCartQuantity > 0)
                      Positioned(
                        right: -9,
                        top: -8,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF9800),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$_totalCartQuantity',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _cartItems.isEmpty
                        ? 'Keranjang masih kosong'
                        : '${_cartItems.length} jenis produk',
                    style: GoogleFonts.inter(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'Rp ${_formatPrice(_estimatedTotal)}',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF9B5EFF),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMobileCart() {
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return FractionallySizedBox(
              heightFactor: 0.90,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16162A) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: _buildCartPanel(
                  isDark: isDark,
                  embedded: false,
                  modalSetState: modalSetState,
                  closeBottomSheet: () {
                    Navigator.pop(bottomSheetContext);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCartPanel({
    required bool isDark,
    required bool embedded,
    StateSetter? modalSetState,
    VoidCallback? closeBottomSheet,
  }) {
    final theme = Theme.of(context);

    void refreshBoth(VoidCallback action) {
      setState(action);
      modalSetState?.call(() {});
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: embedded
                ? Colors.transparent
                : isDark
                ? const Color(0xFF1E1E35)
                : const Color(0xFFF5F5FA),
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
              const Icon(
                Icons.shopping_cart_outlined,
                color: Color(0xFF9B5EFF),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Keranjang Kasir',
                  style: GoogleFonts.poppins(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_cartItems.isNotEmpty)
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          refreshBoth(_clearCart);
                        },
                  child: Text(
                    'Hapus Semua',
                    style: GoogleFonts.inter(
                      color: Colors.red.shade400,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (!embedded)
                IconButton(
                  onPressed: closeBottomSheet,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
        Expanded(
          child: _cartItems.isEmpty
              ? _buildEmptyCart()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _cartItems.length,
                  itemBuilder: (context, index) {
                    final item = _cartItems[index];

                    return _buildCartItem(
                      item: item,
                      isDark: isDark,
                      onDecrease: () {
                        refreshBoth(() => _decreaseQuantity(item));
                      },
                      onIncrease: () {
                        if (item.quantity >= item.product.stock) {
                          _showSnackBar(
                            'Jumlah sudah mencapai stok tersedia.',
                            Colors.orange.shade500,
                          );
                          return;
                        }

                        refreshBoth(() => item.quantity++);
                      },
                      onDelete: () {
                        refreshBoth(() => _cartItems.remove(item));
                      },
                    );
                  },
                ),
        ),
        _buildPaymentForm(
          isDark: isDark,
          modalSetState: modalSetState,
          closeBottomSheet: closeBottomSheet,
        ),
      ],
    );
  }

  Widget _buildEmptyCart() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.remove_shopping_cart_outlined,
              color: theme.textTheme.bodySmall?.color,
              size: 54,
            ),
            const SizedBox(height: 14),
            Text(
              'Keranjang masih kosong',
              style: GoogleFonts.poppins(
                color: theme.textTheme.titleLarge?.color,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tekan produk untuk menambahkannya.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem({
    required _CashierCartItem item,
    required bool isDark,
    required VoidCallback onDecrease,
    required VoidCallback onIncrease,
    required VoidCallback onDelete,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF5F5FA),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Rp ${_formatPrice(item.product.sellingPrice)} × ${item.quantity}',
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
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
          ),
          _buildQuantityButton(
            icon: Icons.remove_rounded,
            onPressed: onDecrease,
            isDark: isDark,
          ),
          SizedBox(
            width: 32,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: theme.textTheme.titleLarge?.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _buildQuantityButton(
            icon: Icons.add_rounded,
            onPressed: onIncrease,
            isDark: isDark,
            isPrimary: true,
          ),
          const SizedBox(width: 5),
          IconButton(
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Colors.red.shade400,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDark,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 29,
        height: 29,
        decoration: BoxDecoration(
          color: isPrimary
              ? const Color(0xFF9B5EFF).withValues(alpha: 0.18)
              : isDark
              ? const Color(0xFF2A2A3A)
              : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isPrimary
              ? const Color(0xFF9B5EFF)
              : Theme.of(context).textTheme.bodyMedium?.color,
          size: 17,
        ),
      ),
    );
  }

  Widget _buildPaymentForm({
    required bool isDark,
    StateSetter? modalSetState,
    VoidCallback? closeBottomSheet,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        14,
        14,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131322) : const Color(0xFFF9FAFB),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _cashReceivedController,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                _onCashChanged(value);
                modalSetState?.call(() {});
              },
              style: GoogleFonts.inter(
                color: theme.textTheme.titleLarge?.color,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                labelText: 'Uang diterima',
                hintText: 'Masukkan nominal tunai',
                prefixText: 'Rp ',
                suffixIcon: TextButton(
                  onPressed: _cartItems.isEmpty || _isSubmitting
                      ? null
                      : () {
                          _setExactCash();
                          modalSetState?.call(() {});
                        },
                  child: const Text('Uang Pas'),
                ),
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              enabled: !_isSubmitting,
              maxLines: 2,
              maxLength: 1000,
              style: GoogleFonts.inter(
                color: theme.textTheme.titleLarge?.color,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Contoh: tanpa saus',
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 4),
            _buildPaymentSummary(isDark),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _cartItems.isEmpty || _isSubmitting
                    ? null
                    : () {
                        closeBottomSheet?.call();

                        if (closeBottomSheet != null) {
                          Future<void>.delayed(
                            const Duration(milliseconds: 250),
                            _submitTransaction,
                          );
                        } else {
                          _submitTransaction();
                        }
                      },
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.payments_outlined),
                label: Text(
                  _isSubmitting ? 'Menyimpan...' : 'Simpan Transaksi Tunai',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9800),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark
                      ? const Color(0xFF5C5878)
                      : const Color(0xFFD1D5DB),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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

  Widget _buildPaymentSummary(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF1EDFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            label: 'Total',
            value: 'Rp ${_formatPrice(_estimatedTotal)}',
            valueColor: const Color(0xFF9B5EFF),
          ),
          const SizedBox(height: 7),
          _buildSummaryRow(
            label: 'Uang diterima',
            value: 'Rp ${_formatPrice(_cashReceived)}',
          ),
          const SizedBox(height: 7),
          _buildSummaryRow(
            label: 'Estimasi kembalian',
            value: 'Rp ${_formatPrice(_estimatedChange)}',
            valueColor: Colors.green.shade500,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);

    return Row(
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
        Text(
          value,
          style: GoogleFonts.poppins(
            color: valueColor ?? theme.textTheme.titleLarge?.color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, color: Colors.red.shade300, size: 62),
            const SizedBox(height: 16),
            Text(
              'Produk gagal dimuat',
              style: GoogleFonts.poppins(
                color: theme.textTheme.titleLarge?.color,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _errorMessage ?? 'Terjadi kesalahan saat mengambil produk.',
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
                _loadInitialData();
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
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: theme.textTheme.bodySmall?.color,
              size: 58,
            ),
            const SizedBox(height: 14),
            Text(
              'Produk tidak ditemukan',
              style: GoogleFonts.poppins(
                color: theme.textTheme.titleLarge?.color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Coba ubah pencarian atau kategori.',
              style: GoogleFonts.inter(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 12,
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
}

class _CashierCartItem {
  ProductModel product;
  int quantity;

  _CashierCartItem({required this.product, required this.quantity});

  int get subtotal => product.sellingPrice * quantity;
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;

    if (!iterator.moveNext()) {
      return null;
    }

    return iterator.current;
  }
}
