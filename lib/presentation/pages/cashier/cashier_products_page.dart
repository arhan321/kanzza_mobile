import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/product_repository.dart';

class CashierProductsPage extends StatefulWidget {
  const CashierProductsPage({super.key});

  @override
  State<CashierProductsPage> createState() =>
      _CashierProductsPageState();
}

class _CashierProductsPageState
    extends State<CashierProductsPage> {
  final ProductRepository _productRepository = ProductRepository();
  final TextEditingController _searchController =
      TextEditingController();

  final List<CategoryModel> _categories = [];
  final List<ProductModel> _products = [];

  Timer? _searchDebounce;
  int? _selectedCategoryId;
  bool _isLoading = true;
  bool _isRefreshing = false;
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
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        _productRepository.getCategories(),
        _productRepository.getProducts(
          search: _normalizedSearch,
          categoryId: _selectedCategoryId,
        ),
      ]);

      if (!mounted) {
        return;
      }

      final categories = results[0] as List<CategoryModel>;
      final products = results[1] as List<ProductModel>;

      setState(() {
        _categories
          ..clear()
          ..addAll(categories);

        _products
          ..clear()
          ..addAll(products);

        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      _handleLoadError(error.firstValidationError);
    } catch (error) {
      debugPrint('LOAD CASHIER PRODUCTS ERROR: $error');
      _handleLoadError(
        'Terjadi kesalahan saat mengambil data produk.',
      );
    }
  }

  Future<void> _loadProducts({
    bool showMainLoading = false,
  }) async {
    if (mounted) {
      setState(() {
        if (showMainLoading) {
          _isLoading = true;
        }

        _errorMessage = null;
      });
    }

    try {
      final products = await _productRepository.getProducts(
        search: _normalizedSearch,
        categoryId: _selectedCategoryId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _products
          ..clear()
          ..addAll(products);

        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      _handleLoadError(error.firstValidationError);
    } catch (error) {
      debugPrint('FILTER CASHIER PRODUCTS ERROR: $error');
      _handleLoadError(
        'Terjadi kesalahan saat mengambil data produk.',
      );
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

  String? get _normalizedSearch {
    final value = _searchController.text.trim();

    if (value.isEmpty) {
      return null;
    }

    return value;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () {
        _loadProducts();
      },
    );
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

  Future<void> _refresh() async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    await _loadInitialData();
  }

  void _showProductDetail(ProductModel product) {
    final theme = Theme.of(context);
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: isDark
                  ? Border.all(
                      color: const Color(0xFF1E1E35),
                    )
                  : null,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 46,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  _buildDetailImage(product, isDark),
                  const SizedBox(height: 18),
                  Text(
                    product.name,
                    style: GoogleFonts.poppins(
                      color: theme.textTheme.titleLarge?.color,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.sku.isEmpty
                        ? 'SKU belum tersedia'
                        : product.sku,
                    style: GoogleFonts.inter(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildDetailRow(
                    title: 'Kategori',
                    value: product.categoryName,
                  ),
                  _buildDetailRow(
                    title: 'Harga jual',
                    value:
                        'Rp ${_formatPrice(product.sellingPrice)}',
                    valueColor: const Color(0xFF9B5EFF),
                  ),
                  _buildDetailRow(
                    title: 'Stok',
                    value: '${product.stock} ${product.unit}',
                    valueColor: _stockColor(product),
                  ),
                  _buildDetailRow(
                    title: 'Stok minimum',
                    value:
                        '${product.minimumStock} ${product.unit}',
                  ),
                  _buildDetailRow(
                    title: 'Status',
                    value: product.isOutOfStock
                        ? 'Stok habis'
                        : product.isLowStock
                            ? 'Stok menipis'
                            : 'Tersedia',
                    valueColor: _stockColor(product),
                  ),
                  if (product.description != null &&
                      product.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Deskripsi',
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.description!,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF9B5EFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Tutup',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
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

  Widget _buildDetailImage(
    ProductModel product,
    bool isDark,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        height: 190,
        color: isDark
            ? const Color(0xFF1E1E35)
            : const Color(0xFFF1EDFF),
        child: _buildProductImage(
          product,
          iconSize: 62,
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String title,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                color:
                    valueColor ?? theme.textTheme.titleLarge?.color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
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
      isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
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
                ? const [
                    Color(0xFF13102A),
                    Color(0xFF0D0D12),
                  ]
                : const [
                    Color(0xFFF5F5FA),
                    Color(0xFFE8E8F0),
                  ],
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
        color:
            isDark ? const Color(0xFF13102A) : Colors.white,
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
            ? const Border(
                bottom: BorderSide(
                  color: Color(0xFF1E1E35),
                ),
              )
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daftar Produk',
                  style: GoogleFonts.poppins(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: isTablet ? 24 : 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Data langsung dari backend Laravel',
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _isLoading ? null : _refresh,
            style: IconButton.styleFrom(
              backgroundColor:
                  const Color(0xFF9B5EFF).withValues(alpha: 0.12),
              foregroundColor: const Color(0xFF9B5EFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
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
        child: CircularProgressIndicator(
          color: Color(0xFF9B5EFF),
        ),
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
              18,
              horizontalPadding,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _buildSearchField(isDark),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              14,
              horizontalPadding,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _buildCategoryFilter(isDark),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              16,
              horizontalPadding,
              8,
            ),
            sliver: SliverToBoxAdapter(
              child: _buildResultInfo(),
            ),
          ),
          if (_errorMessage != null)
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              sliver: SliverToBoxAdapter(
                child: _buildInlineError(),
              ),
            ),
          if (_products.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                6,
                horizontalPadding,
                30,
              ),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildProductCard(
                      product: _products[index],
                      isDark: isDark,
                    );
                  },
                  childCount: _products.length,
                ),
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isTablet ? 4 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isTablet ? 0.80 : 0.70,
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
      textInputAction: TextInputAction.search,
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
                  _loadProducts();
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: theme.cardTheme.color,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF1E1E35)
                : const Color(0xFFE5E7EB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF1E1E35)
                : const Color(0xFFE5E7EB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF9B5EFF),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(bool isDark) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildCategoryChip(
            label: 'Semua',
            categoryId: null,
            isDark: isDark,
          ),
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
    final theme = Theme.of(context);
    final selected = _selectedCategoryId == categoryId;

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
            color: selected
                ? Colors.white
                : theme.textTheme.bodyMedium?.color,
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        selectedColor: const Color(0xFF9B5EFF),
        backgroundColor: theme.cardTheme.color,
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
      ),
    );
  }

  Widget _buildResultInfo() {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            '${_products.length} produk ditemukan',
            style: GoogleFonts.inter(
              color: theme.textTheme.bodySmall?.color,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          'Kasir hanya dapat melihat produk',
          style: GoogleFonts.inter(
            color: const Color(0xFF9B5EFF),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildInlineError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.25),
        ),
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
          TextButton(
            onPressed: _loadProducts,
            child: const Text('Ulangi'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard({
    required ProductModel product,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final stockColor = _stockColor(product);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _showProductDetail(product);
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF1E1E35)
                  : const Color(0xFFE8E8F0),
            ),
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
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(17),
                  ),
                  child: Container(
                    width: double.infinity,
                    color: isDark
                        ? const Color(0xFF1E1E35)
                        : const Color(0xFFF1EDFF),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _buildProductImage(
                            product,
                            iconSize: 44,
                          ),
                        ),
                        Positioned(
                          top: 9,
                          right: 9,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: stockColor,
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Text(
                              product.isOutOfStock
                                  ? 'Habis'
                                  : product.isLowStock
                                      ? 'Menipis'
                                      : 'Tersedia',
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
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  11,
                  12,
                  12,
                ),
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
                    const SizedBox(height: 8),
                    Text(
                      'Rp ${_formatPrice(product.sellingPrice)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF9B5EFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          color: stockColor,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Stok ${product.stock} ${product.unit}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: stockColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildProductImage(
    ProductModel product, {
    required double iconSize,
  }) {
    final imageUrl = product.imageUrl;

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return Center(
        child: Icon(
          Icons.inventory_2_rounded,
          color: const Color(0xFF9B5EFF).withValues(alpha: 0.55),
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
            color: const Color(0xFF9B5EFF).withValues(alpha: 0.55),
            size: iconSize,
          ),
        );
      },
      loadingBuilder: (
        context,
        child,
        loadingProgress,
      ) {
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

  Widget _buildErrorState() {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: Colors.red.shade300,
              size: 64,
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
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
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
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Produk tidak ditemukan',
              style: GoogleFonts.poppins(
                color: theme.textTheme.titleLarge?.color,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Coba ubah kata pencarian atau kategori produk.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
