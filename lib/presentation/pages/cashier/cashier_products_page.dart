import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/category.dart';
import '../../../data/models/owner_product_input.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/product_repository.dart';

enum ProductManagementMode { cashier, owner }

class CashierProductsPage extends StatefulWidget {
  const CashierProductsPage({
    super.key,
    this.mode = ProductManagementMode.cashier,
  });

  final ProductManagementMode mode;

  @override
  State<CashierProductsPage> createState() => _CashierProductsPageState();
}

class _CashierProductsPageState extends State<CashierProductsPage> {
  static const Color _primary = Color(0xFF9B5EFF);

  final ProductRepository _repository = ProductRepository();
  final TextEditingController _searchController = TextEditingController();

  List<ProductModel> _products = const [];
  List<CategoryModel> _categories = const [];
  Timer? _searchDebounce;
  int _requestGeneration = 0;
  int? _selectedCategoryId;
  int? _processingProductId;
  _ProductStatusFilter _statusFilter = _ProductStatusFilter.all;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isMutating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _requestGeneration++;
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts({bool refresh = false}) async {
    final generation = ++_requestGeneration;

    if (mounted) {
      setState(() {
        if (refresh) {
          _isRefreshing = true;
        } else if (_products.isEmpty) {
          _isLoading = true;
        }
        _errorMessage = null;
      });
    }

    try {
      final query = _searchController.text.trim();
      final results = await Future.wait<dynamic>([
        _repository.getCategories(activeOnly: false),
        _repository.getProducts(
          search: query.isEmpty ? null : query,
          categoryId: _selectedCategoryId,
          isActive: _statusFilter.activeValue,
          lowStock: _statusFilter.onlyLowStock,
          perPage: 100,
        ),
      ]);

      if (!mounted || generation != _requestGeneration) {
        return;
      }

      setState(() {
        _categories = results[0] as List<CategoryModel>;
        _products = results[1] as List<ProductModel>;
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      _handleLoadError(generation, error.firstValidationError);
    } catch (error) {
      debugPrint('CASHIER PRODUCTS ERROR: $error');
      _handleLoadError(
        generation,
        'Data produk gagal dimuat. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  void _handleLoadError(int generation, String message) {
    if (!mounted || generation != _requestGeneration) {
      return;
    }

    setState(() {
      _isLoading = false;
      _isRefreshing = false;
      _errorMessage = message;
    });

    if (_products.isNotEmpty) {
      _showMessage(message, isError: true);
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      _loadProducts,
    );
    setState(() {});
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    FocusScope.of(context).unfocus();
    _loadProducts();
  }

  Future<void> _openProductForm([ProductModel? product]) async {
    if (_isMutating) {
      return;
    }

    FocusScope.of(context).unfocus();

    final input = await showModalBottomSheet<OwnerProductInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CashierProductEditorSheet(
        product: product,
        categories: _categories,
      ),
    );

    if (input == null || !mounted) {
      return;
    }

    setState(() {
      _isMutating = true;
      _processingProductId = product?.id ?? -1;
    });

    try {
      if (product == null) {
        if (widget.mode == ProductManagementMode.owner) {
          await _repository.createOwnerProduct(input);
        } else {
          await _repository.createCashierProduct(input);
        }
        _showMessage('Produk berhasil ditambahkan.');
      } else {
        if (widget.mode == ProductManagementMode.owner) {
          await _repository.updateOwnerProduct(
            productId: product.id,
            input: input,
          );
        } else {
          await _repository.updateCashierProduct(
            productId: product.id,
            input: input,
          );
        }
        _showMessage('Produk berhasil diperbarui.');
      }

      await _loadProducts(refresh: true);
    } on ApiException catch (error) {
      _showMessage(error.firstValidationError, isError: true);
    } catch (error) {
      debugPrint('CASHIER PRODUCT SAVE ERROR: $error');
      _showMessage(
        'Produk belum berhasil disimpan. Silakan coba lagi.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
          _processingProductId = null;
        });
      }
    }
  }

  Future<void> _deleteProduct(ProductModel product) async {
    if (_isMutating) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFFFECEC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFEF5350),
              size: 30,
            ),
          ),
          title: Text(
            'Hapus produk?',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: Text(
            '${product.name} akan dihapus dari daftar produk. Tindakan ini tidak dapat dibatalkan.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
              height: 1.5,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350),
              ),
              child: const Text('Ya, hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isMutating = true;
      _processingProductId = product.id;
    });

    try {
      if (widget.mode == ProductManagementMode.owner) {
        await _repository.deleteOwnerProduct(product.id);
      } else {
        await _repository.deleteCashierProduct(product.id);
      }
      _showMessage('Produk berhasil dihapus.');
      await _loadProducts(refresh: true);
    } on ApiException catch (error) {
      _showMessage(error.firstValidationError, isError: true);
    } catch (error) {
      debugPrint('CASHIER PRODUCT DELETE ERROR: $error');
      _showMessage(
        'Produk belum berhasil dihapus. Silakan coba lagi.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
          _processingProductId = null;
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFD84343)
              : const Color(0xFF2E9B62),
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF080817)
        : const Color(0xFFF7F6FB);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                _buildHeader(isDark),
                _buildSearchField(isDark),
                _buildFilters(isDark),
                _buildResultSummary(isDark),
                Expanded(child: _buildBody(isDark)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1D2635);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          _HeaderButton(
            tooltip: 'Kembali',
            icon: Icons.arrow_back_rounded,
            isDark: isDark,
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kelola Produk',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Atur katalog, harga, dan persediaan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: textColor.withValues(alpha: 0.52),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: 'Tambah produk',
            child: Material(
              color: _isMutating ? _primary.withValues(alpha: 0.55) : _primary,
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                onTap: _isMutating ? null : () => _openProductForm(),
                borderRadius: BorderRadius.circular(17),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: _processingProductId == -1
                      ? const Padding(
                          padding: EdgeInsets.all(17),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    final fieldColor = isDark
        ? const Color(0xFF15152B)
        : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF202939);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fieldColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : const Color(0xFFEAE8F1),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF251354).withValues(alpha: 0.045),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _loadProducts(),
          style: GoogleFonts.inter(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Cari nama atau SKU produk...',
            hintStyle: GoogleFonts.inter(
              color: textColor.withValues(alpha: 0.42),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: textColor.withValues(alpha: 0.55),
            ),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Hapus pencarian',
                    onPressed: _clearSearch,
                    icon: Icon(
                      Icons.close_rounded,
                      color: textColor.withValues(alpha: 0.55),
                    ),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _ProductStatusFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _ProductStatusFilter.values[index];
              return _FilterChip(
                label: filter.label,
                selected: filter == _statusFilter,
                isDark: isDark,
                onTap: () {
                  if (_statusFilter == filter) {
                    return;
                  }
                  setState(() => _statusFilter = filter);
                  _loadProducts();
                },
              );
            },
          ),
        ),
        if (_categories.isNotEmpty) ...[
          const SizedBox(height: 9),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final category = index == 0 ? null : _categories[index - 1];
                final selected = category == null
                    ? _selectedCategoryId == null
                    : _selectedCategoryId == category.id;

                return _CategoryChip(
                  label: category?.name ?? 'Semua kategori',
                  selected: selected,
                  active: category?.isActive ?? true,
                  isDark: isDark,
                  onTap: () {
                    final nextId = category?.id;
                    if (_selectedCategoryId == nextId) {
                      return;
                    }
                    setState(() => _selectedCategoryId = nextId);
                    _loadProducts();
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultSummary(bool isDark) {
    final color = isDark ? Colors.white : const Color(0xFF252C3A);
    final isWorking = (_isLoading || _isRefreshing) && _products.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_products.length} produk ditemukan',
              style: GoogleFonts.inter(
                color: color.withValues(alpha: 0.68),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isWorking)
            const SizedBox.square(
              dimension: 17,
              child: CircularProgressIndicator(
                color: _primary,
                strokeWidth: 2,
              ),
            )
          else
            InkWell(
              onTap: () => _loadProducts(refresh: true),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Row(
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      color: _primary,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Muat ulang',
                      style: GoogleFonts.inter(
                        color: _primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading && _products.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _primary),
      );
    }

    if (_errorMessage != null && _products.isEmpty) {
      return _StateView(
        icon: Icons.cloud_off_rounded,
        title: 'Produk belum dapat dimuat',
        message: _errorMessage!,
        actionLabel: 'Coba lagi',
        onAction: _loadProducts,
        isDark: isDark,
      );
    }

    if (_products.isEmpty) {
      final hasFilter = _searchController.text.trim().isNotEmpty ||
          _selectedCategoryId != null ||
          _statusFilter != _ProductStatusFilter.all;
      return _StateView(
        icon: hasFilter
            ? Icons.search_off_rounded
            : Icons.inventory_2_outlined,
        title: hasFilter ? 'Produk tidak ditemukan' : 'Belum ada produk',
        message: hasFilter
            ? 'Coba ubah kata pencarian atau filter yang dipilih.'
            : 'Tekan tombol tambah untuk membuat produk pertama.',
        actionLabel: hasFilter ? 'Reset filter' : 'Tambah produk',
        onAction: hasFilter ? _resetFilters : () => _openProductForm(),
        isDark: isDark,
      );
    }

    return RefreshIndicator(
      color: _primary,
      onRefresh: () => _loadProducts(refresh: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
        itemCount: _products.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final product = _products[index];
          return _ProductCard(
            product: product,
            isDark: isDark,
            isProcessing: _processingProductId == product.id,
            onEdit: _isMutating ? null : () => _openProductForm(product),
            onDelete: _isMutating ? null : () => _deleteProduct(product),
          );
        },
      ),
    );
  }

  void _resetFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedCategoryId = null;
      _statusFilter = _ProductStatusFilter.all;
    });
    _loadProducts();
  }
}

enum _ProductStatusFilter {
  all('Semua', null, false),
  active('Aktif', true, false),
  inactive('Nonaktif', false, false),
  lowInventory('Stok menipis', null, true);

  const _ProductStatusFilter(
    this.label,
    this.activeValue,
    this.onlyLowStock,
  );

  final String label;
  final bool? activeValue;
  final bool onlyLowStock;
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? Colors.white : const Color(0xFF273142);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark ? const Color(0xFF15152B) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE8E6EF),
              ),
            ),
            child: Icon(icon, color: color, size: 25),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? Colors.white
        : isDark
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFF596170);

    return Material(
      color: selected
          ? _CashierProductsPageState._primary
          : isDark
          ? const Color(0xFF15152B)
          : Colors.white,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? _CashierProductsPageState._primary
                  : isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : const Color(0xFFE5E3EB),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: foreground,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? _CashierProductsPageState._primary
        : isDark
        ? Colors.white.withValues(alpha: active ? 0.62 : 0.36)
        : const Color(0xFF687080).withValues(alpha: active ? 1 : 0.55);

    return Material(
      color: selected
          ? _CashierProductsPageState._primary.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? _CashierProductsPageState._primary.withValues(alpha: 0.45)
                  : isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE4E1E9),
            ),
          ),
          child: Text(
            active ? label : '$label (nonaktif)',
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isDark,
    required this.isProcessing,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductModel product;
  final bool isDark;
  final bool isProcessing;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF1D2635);
    final cardColor = isDark ? const Color(0xFF15152B) : Colors.white;

    return AnimatedOpacity(
      opacity: isProcessing ? 0.58 : 1,
      duration: const Duration(milliseconds: 180),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.065)
                : const Color(0xFFECEAF1),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF29134F).withValues(alpha: 0.055),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ProductImage(product: product, isDark: isDark),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      _ProductTag(
                        label: product.categoryName,
                        foreground: const Color(0xFF8B54DE),
                        background: const Color(0xFFF1E9FF),
                        darkBackground: const Color(0xFF2B1C46),
                        isDark: isDark,
                      ),
                      _StockTag(product: product, isDark: isDark),
                      if (!product.isActive)
                        _ProductTag(
                          label: 'Nonaktif',
                          foreground: const Color(0xFFEF5350),
                          background: const Color(0xFFFFEAEA),
                          darkBackground: const Color(0xFF3B1B2A),
                          isDark: isDark,
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _rupiah(product.sellingPrice),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: _CashierProductsPageState._primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SKU: ${product.sku.isEmpty ? '-' : product.sku}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: textColor.withValues(alpha: 0.43),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 9),
            if (isProcessing)
              const SizedBox(
                width: 42,
                height: 90,
                child: Center(
                  child: CircularProgressIndicator(
                    color: _CashierProductsPageState._primary,
                    strokeWidth: 2.3,
                  ),
                ),
              )
            else
              Column(
                children: [
                  _ActionButton(
                    tooltip: 'Edit produk',
                    icon: Icons.edit_rounded,
                    foreground: const Color(0xFF249BD7),
                    background: isDark
                        ? const Color(0xFF102A43)
                        : const Color(0xFFE9F7FF),
                    border: const Color(0xFFBCE5F7),
                    onTap: onEdit,
                  ),
                  const SizedBox(height: 8),
                  _ActionButton(
                    tooltip: 'Hapus produk',
                    icon: Icons.delete_outline_rounded,
                    foreground: const Color(0xFFEF5350),
                    background: isDark
                        ? const Color(0xFF3A1927)
                        : const Color(0xFFFFEEEE),
                    border: const Color(0xFFF8C7C7),
                    onTap: onDelete,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.product, required this.isDark});

  final ProductModel product;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl?.trim();
    final placeholder = ColoredBox(
      color: isDark ? const Color(0xFF20203A) : const Color(0xFFF2F3F7),
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: isDark
              ? Colors.white.withValues(alpha: 0.3)
              : const Color(0xFF98A0AF),
          size: 31,
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        width: 82,
        height: 94,
        child: imageUrl == null || imageUrl.isEmpty
            ? placeholder
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class _ProductTag extends StatelessWidget {
  const _ProductTag({
    required this.label,
    required this.foreground,
    required this.background,
    required this.darkBackground,
    required this.isDark,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Color darkBackground;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 105),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? darkBackground : background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: foreground.withValues(alpha: 0.23)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          color: foreground,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StockTag extends StatelessWidget {
  const _StockTag({required this.product, required this.isDark});

  final ProductModel product;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    late final Color foreground;
    late final Color background;
    late final Color darkBackground;

    if (product.isOutOfStock) {
      foreground = const Color(0xFFEF5350);
      background = const Color(0xFFFFEAEA);
      darkBackground = const Color(0xFF3B1B2A);
    } else if (product.isLowStock) {
      foreground = const Color(0xFFE69A16);
      background = const Color(0xFFFFF4D8);
      darkBackground = const Color(0xFF3B2B17);
    } else {
      foreground = const Color(0xFF4FA866);
      background = const Color(0xFFEAF8EC);
      darkBackground = const Color(0xFF183427);
    }

    return _ProductTag(
      label: product.isOutOfStock
          ? 'Stok habis'
          : 'Stok: ${product.stock} ${product.unit}',
      foreground: foreground,
      background: background,
      darkBackground: darkBackground,
      isDark: isDark,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.border,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color foreground;
  final Color background;
  final Color border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border.withValues(alpha: 0.72)),
            ),
            child: Icon(icon, color: foreground, size: 21),
          ),
        ),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? Colors.white : const Color(0xFF232B39);

    return RefreshIndicator(
      color: _CashierProductsPageState._primary,
      onRefresh: () async => onAction(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 46, 28, 28),
        children: [
          Center(
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: _CashierProductsPageState._primary.withValues(
                  alpha: isDark ? 0.16 : 0.1,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 38,
                color: _CashierProductsPageState._primary,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: color.withValues(alpha: 0.58),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 19),
          Center(
            child: FilledButton.icon(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: _CashierProductsPageState._primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _CashierProductEditorSheet extends StatefulWidget {
  const _CashierProductEditorSheet({
    required this.product,
    required this.categories,
  });

  final ProductModel? product;
  final List<CategoryModel> categories;

  @override
  State<_CashierProductEditorSheet> createState() =>
      _CashierProductEditorSheetState();
}

class _CashierProductEditorSheetState
    extends State<_CashierProductEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _skuController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _minimumStockController;
  late final TextEditingController _unitController;

  int? _categoryId;
  String? _imagePath;
  bool _isActive = true;
  bool _isPickingImage = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _skuController = TextEditingController(text: product?.sku ?? '');
    _nameController = TextEditingController(text: product?.name ?? '');
    _descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    _costPriceController = TextEditingController(
      text: (product?.costPrice ?? 0).toString(),
    );
    _sellingPriceController = TextEditingController(
      text: product?.sellingPrice.toString() ?? '',
    );
    _stockController = TextEditingController(
      text: product?.stock.toString() ?? '0',
    );
    _minimumStockController = TextEditingController(
      text: product?.minimumStock.toString() ?? '0',
    );
    _unitController = TextEditingController(text: product?.unit ?? 'pcs');
    _categoryId = product == null || product.categoryId == 0
        ? null
        : product.categoryId;
    _isActive = product?.isActive ?? true;
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _minimumStockController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111124) : const Color(0xFFFAF9FD);
    final textColor = isDark ? Colors.white : const Color(0xFF202938);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.94,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 13, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _CashierProductsPageState._primary.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _isEditing
                        ? Icons.edit_rounded
                        : Icons.add_business_rounded,
                    color: _CashierProductsPageState._primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing ? 'Edit Produk' : 'Tambah Produk',
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _isEditing
                            ? 'Perbarui informasi produk berikut'
                            : 'Lengkapi informasi produk baru',
                        style: GoogleFonts.inter(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: textColor.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: textColor.withValues(alpha: 0.08),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  24 + keyboardHeight,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildImagePicker(isDark, textColor),
                        const SizedBox(height: 22),
                        _sectionTitle('Informasi dasar', textColor),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _validInitialCategoryId,
                          isExpanded: true,
                          decoration: _inputDecoration(
                            label: 'Kategori (opsional)',
                            icon: Icons.category_outlined,
                            isDark: isDark,
                          ),
                          items: widget.categories
                              .map(
                                (category) => DropdownMenuItem<int>(
                                  value: category.id,
                                  child: Text(
                                    category.isActive
                                        ? category.name
                                        : '${category.name} (nonaktif)',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => _categoryId = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          controller: _skuController,
                          label: 'SKU',
                          icon: Icons.qr_code_2_rounded,
                          isDark: isDark,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 80,
                          validator: (value) => _required(value, 'SKU'),
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          controller: _nameController,
                          label: 'Nama produk',
                          icon: Icons.inventory_2_outlined,
                          isDark: isDark,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 255,
                          validator: (value) => _required(value, 'Nama produk'),
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          controller: _descriptionController,
                          label: 'Deskripsi (opsional)',
                          icon: Icons.notes_rounded,
                          isDark: isDark,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 22),
                        _sectionTitle('Harga dan persediaan', textColor),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 430;
                            final costPriceField = _numberField(
                              controller: _costPriceController,
                              label: 'Harga modal',
                              icon: Icons.payments_outlined,
                              minimum: 0,
                              isDark: isDark,
                            );
                            final sellingPriceField = _numberField(
                              controller: _sellingPriceController,
                              label: 'Harga jual',
                              icon: Icons.sell_outlined,
                              minimum: 1,
                              isDark: isDark,
                            );
                            return compact
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      costPriceField,
                                      const SizedBox(height: 12),
                                      sellingPriceField,
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(child: costPriceField),
                                      const SizedBox(width: 12),
                                      Expanded(child: sellingPriceField),
                                    ],
                                  );
                          },
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 430;
                            final stockField = _numberField(
                              controller: _stockController,
                              label: 'Stok',
                              icon: Icons.warehouse_outlined,
                              minimum: 0,
                              isDark: isDark,
                            );
                            final minimumStockField = _numberField(
                              controller: _minimumStockController,
                              label: 'Batas stok minimum',
                              icon: Icons.warning_amber_rounded,
                              minimum: 0,
                              isDark: isDark,
                            );
                            return compact
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      stockField,
                                      const SizedBox(height: 12),
                                      minimumStockField,
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(child: stockField),
                                      const SizedBox(width: 12),
                                      Expanded(child: minimumStockField),
                                    ],
                                  );
                          },
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          controller: _unitController,
                          label: 'Satuan (contoh: pcs, pack, kg)',
                          icon: Icons.straighten_rounded,
                          isDark: isDark,
                          maxLength: 30,
                          validator: (value) => _required(value, 'Satuan'),
                        ),
                        const SizedBox(height: 16),
                        _buildActiveSwitch(isDark, textColor),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  _CashierProductsPageState._primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.save_rounded),
                            label: Text(
                              _isEditing ? 'Simpan Perubahan' : 'Tambah Produk',
                              style: GoogleFonts.inter(
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
            ),
          ),
        ],
      ),
    );
  }

  int? get _validInitialCategoryId {
    final current = _categoryId;
    if (current == null) {
      return null;
    }
    return widget.categories.any((category) => category.id == current)
        ? current
        : null;
  }

  Widget _sectionTitle(String value, Color textColor) {
    return Text(
      value,
      style: GoogleFonts.poppins(
        color: textColor,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildImagePicker(bool isDark, Color textColor) {
    final existingUrl = widget.product?.imageUrl?.trim();
    final imagePath = _imagePath;

    Widget image;
    if (imagePath != null) {
      image = Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imagePlaceholder(isDark, textColor),
      );
    } else if (existingUrl != null && existingUrl.isNotEmpty) {
      image = Image.network(
        existingUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imagePlaceholder(isDark, textColor),
      );
    } else {
      image = _imagePlaceholder(isDark, textColor);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(aspectRatio: 16 / 8.5, child: image),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _isPickingImage ? null : _pickImage,
          style: OutlinedButton.styleFrom(
            foregroundColor: _CashierProductsPageState._primary,
            side: BorderSide(
              color: _CashierProductsPageState._primary.withValues(alpha: 0.4),
            ),
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: _isPickingImage
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.photo_library_outlined),
          label: Text(
            imagePath == null && (existingUrl == null || existingUrl.isEmpty)
                ? 'Pilih Gambar Produk'
                : 'Ganti Gambar Produk',
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Format JPG, PNG, atau WebP • Maksimal 4 MB',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: textColor.withValues(alpha: 0.46),
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder(bool isDark, Color textColor) {
    return ColoredBox(
      color: isDark ? const Color(0xFF1C1C35) : const Color(0xFFF0EEF5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: textColor.withValues(alpha: 0.34),
              size: 48,
            ),
            const SizedBox(height: 7),
            Text(
              'Gambar produk',
              style: GoogleFonts.inter(
                color: textColor.withValues(alpha: 0.4),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSwitch(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A31) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE4E1EA),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _isActive
                  ? const Color(0xFFEAF8EC)
                  : const Color(0xFFFFEAEA),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              _isActive
                  ? Icons.check_circle_outline_rounded
                  : Icons.visibility_off_outlined,
              color: _isActive
                  ? const Color(0xFF4FA866)
                  : const Color(0xFFEF5350),
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Produk aktif',
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _isActive
                      ? 'Produk dapat dilihat dan dibeli customer'
                      : 'Produk disembunyikan dari katalog customer',
                  style: GoogleFonts.inter(
                    color: textColor.withValues(alpha: 0.48),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isActive,
            activeTrackColor: _CashierProductsPageState._primary,
            onChanged: (value) => setState(() => _isActive = value),
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    String? Function(String?)? validator,
    int maxLines = 1,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      validator: validator,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
        isDark: isDark,
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required int minimum,
    required bool isDark,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _inputDecoration(
        label: label,
        icon: icon,
        isDark: isDark,
        prefixText: label.toLowerCase().contains('harga') ? 'Rp ' : null,
      ),
      validator: (value) {
        final parsed = int.tryParse(value ?? '');
        if (parsed == null) {
          return '$label wajib berupa angka.';
        }
        if (parsed < minimum) {
          return 'Nilai minimal $minimum.';
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
    String? prefixText,
  }) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE3E0E9);
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      prefixText: prefixText,
      counterText: '',
      filled: true,
      fillColor: isDark ? const Color(0xFF1A1A31) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _CashierProductsPageState._primary,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF5350)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    );
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label wajib diisi.';
    }
    return null;
  }

  Future<void> _pickImage() async {
    setState(() => _isPickingImage = true);

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 86,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (image == null || !mounted) {
        return;
      }

      final file = File(image.path);
      final size = await file.length();
      final extension = image.path.split('.').last.toLowerCase();

      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        _showLocalMessage('Gunakan gambar JPG, PNG, atau WebP.');
        return;
      }

      if (size > 4 * 1024 * 1024) {
        _showLocalMessage('Ukuran gambar melebihi batas 4 MB.');
        return;
      }

      setState(() => _imagePath = image.path);
    } catch (error) {
      debugPrint('PRODUCT IMAGE PICKER ERROR: $error');
      _showLocalMessage('Gambar gagal dipilih. Silakan coba lagi.');
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _showLocalMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) {
      HapticFeedback.mediumImpact();
      return;
    }

    Navigator.pop(
      context,
      OwnerProductInput(
        categoryId: _categoryId,
        sku: _skuController.text,
        name: _nameController.text,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text,
        costPrice: int.parse(_costPriceController.text),
        sellingPrice: int.parse(_sellingPriceController.text),
        stock: int.parse(_stockController.text),
        minimumStock: int.parse(_minimumStockController.text),
        unit: _unitController.text,
        isActive: _isActive,
        imagePath: _imagePath,
      ),
    );
  }
}

String _rupiah(int value) {
  return NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(value);
}
