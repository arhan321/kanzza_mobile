// lib/presentation/pages/customer/customer_home_page.dart

import 'dart:async';

import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/gradient_nav_bar.dart';
import '../../../core/widgets/header.dart';
import '../../../core/widgets/promo_banner.dart';
import '../../../core/widgets/search_bar.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../routes.dart';
import '../../providers/customer_cart_provider.dart';
import '../../providers/customer_notification_provider.dart';
import 'customer_cart_page.dart';
import 'customer_notifications_page.dart';
import 'customer_orders_page.dart';
import 'customer_profile_page.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage>
    with WidgetsBindingObserver {
  final ProductRepository _productRepository = ProductRepository();
  final UserRepository _userRepository = UserRepository();
  final ScrollController _scrollController = ScrollController();
  Timer? _notificationTimer;

  final List<CategoryModel> _categories = [];
  final List<ProductModel> _allProducts = [];

  int _currentIndex = 0;
  int? _selectedCategoryId;
  String _searchQuery = '';

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePage();
    });

    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        unawaited(
          context
              .read<CustomerNotificationProvider>()
              .refreshUnreadCount(),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(
        context
            .read<CustomerNotificationProvider>()
            .refreshUnreadCount(),
      );
    }
  }

  Future<void> _initializePage() async {
    try {
      await context.read<CustomerCartProvider>().initialize(force: true);
    } catch (error) {
      debugPrint('INITIALIZE CUSTOMER CART ERROR: $error');
    }

    await context
        .read<CustomerNotificationProvider>()
        .refreshUnreadCount();

    if (!mounted) {
      return;
    }

    await _loadCatalog();
  }

  Future<void> _loadCatalog({bool isRefresh = false}) async {
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
      final results = await Future.wait<dynamic>([
        _productRepository.getCategories(),
        _productRepository.getProducts(isActive: true, perPage: 100),
      ]);

      final categories = results[0] as List<CategoryModel>;
      final products = results[1] as List<ProductModel>;

      products.sort(
        (first, second) =>
            first.name.toLowerCase().compareTo(second.name.toLowerCase()),
      );

      if (!mounted) {
        return;
      }

      await context.read<CustomerCartProvider>().synchronizeProducts(products);

      if (!mounted) {
        return;
      }

      final selectedCategoryStillExists =
          _selectedCategoryId == null ||
          categories.any((category) => category.id == _selectedCategoryId);

      setState(() {
        _categories
          ..clear()
          ..addAll(categories);

        _allProducts
          ..clear()
          ..addAll(products);

        if (!selectedCategoryStillExists) {
          _selectedCategoryId = null;
        }

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
      debugPrint('LOAD CUSTOMER HOME CATALOG ERROR: $error');

      _handleLoadError('Produk gagal dimuat. Silakan coba kembali.');
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

    await Future.wait<void>([
      _loadCatalog(isRefresh: true),
      context
          .read<CustomerNotificationProvider>()
          .refreshUnreadCount(),
    ]);
  }

  Future<void> _openNotifications() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerNotificationsPage(),
      ),
    );

    if (mounted) {
      await context
          .read<CustomerNotificationProvider>()
          .refreshUnreadCount();
    }
  }

  List<ProductModel> get _filteredProducts {
    final normalizedSearch = _searchQuery.trim().toLowerCase();

    return _allProducts.where((product) {
      if (_selectedCategoryId != null &&
          product.categoryId != _selectedCategoryId) {
        return false;
      }

      if (normalizedSearch.isEmpty) {
        return true;
      }

      return product.name.toLowerCase().contains(normalizedSearch) ||
          product.sku.toLowerCase().contains(normalizedSearch) ||
          product.categoryName.toLowerCase().contains(normalizedSearch);
    }).toList();
  }

  void _scrollToProducts() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.animateTo(
      360,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _onNavTap(int index) {
    if (index == 0) {
      setState(() {
        _currentIndex = 0;
      });
      return;
    }

    setState(() {
      _currentIndex = index;
    });

    final Widget page;

    switch (index) {
      case 1:
        page = const CustomerOrdersPage();
        break;
      case 2:
        page = const CustomerCartPage();
        break;
      case 3:
        page = const CustomerProfilePage();
        break;
      default:
        setState(() {
          _currentIndex = 0;
        });
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _currentIndex = 0;
      });

      _refresh();
    });
  }

  Future<void> _addToCart(ProductModel product) async {
    final result = await context.read<CustomerCartProvider>().addProduct(
      product,
    );

    if (!mounted) {
      return;
    }

    if (result.success) {
      HapticFeedback.lightImpact();
    }

    _showSnackBar(
      result.message,
      result.success ? const Color(0xFF7C3AED) : Colors.orange.shade500,
    );
  }

  void _showProductDetail(ProductModel product) {
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
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16162A) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      height: 210,
                      color: isDark
                          ? const Color(0xFF1E1E35)
                          : const Color(0xFFF1EDFF),
                      child: _buildProductImage(product, iconSize: 60),
                    ),
                  ),
                  const SizedBox(height: 17),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _badge(
                        text: product.categoryName,
                        color: const Color(0xFF9B5EFF),
                      ),
                      _badge(
                        text: product.isOutOfStock
                            ? 'Stok habis'
                            : product.isLowStock
                            ? 'Stok menipis'
                            : 'Tersedia',
                        color: _stockColor(product),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Text(
                    product.name,
                    style: GoogleFonts.poppins(
                      color: theme.textTheme.titleLarge?.color,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (product.sku.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'SKU: ${product.sku}',
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Rp ${_formatPrice(product.sellingPrice)}',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF9B5EFF),
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _detailRow(
                    label: 'Stok tersedia',
                    value: '${product.stock} ${product.unit}',
                  ),
                  _detailRow(
                    label: 'Stok minimum',
                    value: '${product.minimumStock} ${product.unit}',
                  ),
                  if (product.description != null &&
                      product.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Deskripsi',
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      product.description!,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: product.canBeSold
                          ? () async {
                              Navigator.pop(bottomSheetContext);
                              await _addToCart(product);
                            }
                          : null,
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: Text(
                        product.isOutOfStock
                            ? 'Stok Habis'
                            : 'Tambah ke Keranjang',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9B5EFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
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

  Widget _detailRow({required String label, required String value}) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
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
            style: GoogleFonts.inter(
              color: theme.textTheme.titleLarge?.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
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

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  Color _stockColor(ProductModel product) {
    if (product.isOutOfStock) {
      return Colors.red.shade400;
    }

    if (product.isLowStock) {
      return Colors.orange.shade500;
    }

    return Colors.green.shade500;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final cartProvider = context.watch<CustomerCartProvider>();
    final notificationProvider =
        context.watch<CustomerNotificationProvider>();
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
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _buildPageContent(
                  horizontalPadding: horizontalPadding,
                  isDark: isDark,
                  isTablet: isTablet,
                  notificationCount: notificationProvider.unreadCount,
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GradientNavBar(
                    currentIndex: _currentIndex,
                    onTap: _onNavTap,
                    isDark: isDark,
                  ),
                  if (cartProvider.totalItems > 0)
                    Positioned(
                      right: screenWidth * 0.29,
                      top: -4,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF9800),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cartProvider.totalItems > 99
                              ? '99+'
                              : '${cartProvider.totalItems}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent({
    required double horizontalPadding,
    required bool isDark,
    required bool isTablet,
    required int notificationCount,
  }) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF9B5EFF)),
      );
    }

    if (_errorMessage != null && _allProducts.isEmpty) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF9B5EFF),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Header(
                    isDark: isDark,
                    notificationCount: notificationCount,
                    onNotificationTap: _openNotifications,
                  ),
                  const SizedBox(height: 20),
                  SearchBar(
                    onSearchChanged: (query) {
                      setState(() {
                        _searchQuery = query;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  PromoBanner(onTap: _scrollToProducts),
                  const SizedBox(height: 24),
                  SectionTitle(title: 'Kategori', isDark: isDark),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            _buildCategoryList(
              horizontalPadding: horizontalPadding,
              isDark: isDark,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SectionTitle(
                          title: _searchQuery.trim().isNotEmpty
                              ? "Hasil Pencarian: '$_searchQuery'"
                              : 'Produk Kanzza',
                          isDark: isDark,
                        ),
                      ),
                      if (_isRefreshing)
                        const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            color: Color(0xFF9B5EFF),
                            strokeWidth: 2,
                          ),
                        )
                      else
                        IconButton(
                          tooltip: 'Muat ulang produk',
                          onPressed: _refresh,
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Color(0xFF9B5EFF),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_filteredProducts.length} produk ditemukan',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 11,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _buildInlineError(),
                  ],
                  const SizedBox(height: 14),
                ],
              ),
            ),
            if (_filteredProducts.isEmpty)
              _buildEmptyProducts()
            else
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredProducts.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isTablet ? 3 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: isTablet ? 0.78 : 0.67,
                  ),
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];

                    return _buildProductCard(product: product, isDark: isDark);
                  },
                ),
              ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList({
    required double horizontalPadding,
    required bool isDark,
  }) {
    return SizedBox(
      height: 43,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        children: [
          _categoryChip(label: 'Semua', categoryId: null, isDark: isDark),
          ..._categories.map(
            (category) => _categoryChip(
              label: category.name,
              categoryId: category.id,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip({
    required String label,
    required int? categoryId,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final selected = _selectedCategoryId == categoryId;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) {
          setState(() {
            _selectedCategoryId = categoryId;
          });
        },
        label: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? Colors.white : theme.textTheme.bodyMedium?.color,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        selectedColor: const Color(0xFF9B5EFF),
        backgroundColor: isDark ? const Color(0xFF16162A) : Colors.white,
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
    final stockColor = _stockColor(product);
    final cartProvider = context.watch<CustomerCartProvider>();
    final cartQuantity = cartProvider.items
        .where((item) => item.id == product.id)
        .fold<int>(0, (total, item) => total + item.quantity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _showProductDetail(product);
        },
        borderRadius: BorderRadius.circular(17),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: cartQuantity > 0
                  ? const Color(0xFF9B5EFF)
                  : isDark
                  ? const Color(0xFF1E1E35)
                  : const Color(0xFFE5E7EB),
              width: cartQuantity > 0 ? 1.5 : 1,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: isDark
                            ? const Color(0xFF1E1E35)
                            : const Color(0xFFF1EDFF),
                        child: _buildProductImage(product, iconSize: 44),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _badge(
                          text: product.isOutOfStock
                              ? 'Habis'
                              : product.isLowStock
                              ? 'Menipis'
                              : 'Stok ${product.stock}',
                          color: stockColor,
                        ),
                      ),
                      if (cartQuantity > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xFF9B5EFF),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$cartQuantity',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
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
                    const SizedBox(height: 3),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Rp ${_formatPrice(product.sellingPrice)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF9B5EFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: product.canBeSold
                            ? () {
                                _addToCart(product);
                              }
                            : null,
                        icon: Icon(
                          product.isOutOfStock
                              ? Icons.block_rounded
                              : Icons.add_shopping_cart_rounded,
                          size: 16,
                        ),
                        label: Text(
                          product.isOutOfStock ? 'Stok Habis' : 'Tambah',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9B5EFF),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: isDark
                              ? const Color(0xFF5C5878)
                              : const Color(0xFFD1D5DB),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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

  Widget _buildProductImage(ProductModel product, {required double iconSize}) {
    final imageUrl = product.imageUrl;

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return Center(
        child: Icon(
          Icons.inventory_2_rounded,
          color: const Color(0xFF9B5EFF).withValues(alpha: 0.50),
          size: iconSize,
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
            size: iconSize,
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

  Widget _badge({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInlineError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade500,
            size: 20,
          ),
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

  Widget _buildEmptyProducts() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            color: theme.textTheme.bodySmall?.color,
            size: 62,
          ),
          const SizedBox(height: 15),
          Text(
            'Produk tidak ditemukan',
            style: GoogleFonts.poppins(
              color: theme.textTheme.titleLarge?.color,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Coba ubah kata pencarian atau kategori.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: theme.textTheme.bodySmall?.color,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 15),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _selectedCategoryId = null;
              });
            },
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset Filter'),
          ),
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
            height: MediaQuery.of(context).size.height * 0.72,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: Colors.red.shade300,
                      size: 65,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Produk gagal dimuat',
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ??
                          'Terjadi kesalahan saat mengambil produk.',
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
                        _loadCatalog();
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
            ),
          ),
        ],
      ),
    );
  }
}
