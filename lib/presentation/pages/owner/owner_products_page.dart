import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/category.dart';
import '../../../data/models/owner_product_input.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/product_repository.dart';

class OwnerProductsPage extends StatefulWidget {
  const OwnerProductsPage({super.key});

  @override
  State<OwnerProductsPage> createState() => _OwnerProductsPageState();
}

class _OwnerProductsPageState extends State<OwnerProductsPage> {
  final ProductRepository _repository = ProductRepository();
  final TextEditingController _searchController = TextEditingController();

  final List<ProductModel> _products = [];
  final List<CategoryModel> _categories = [];
  Timer? _searchDebounce;
  bool _isLoading = true;
  String? _errorMessage;
  int? _categoryFilter;
  bool? _activeFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _repository.getCategories(activeOnly: false),
        _repository.getProducts(
          search: _searchController.text,
          categoryId: _categoryFilter,
          isActive: _activeFilter,
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _categories
          ..clear()
          ..addAll(results[0] as List<CategoryModel>);
        _products
          ..clear()
          ..addAll(results[1] as List<ProductModel>);
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.firstValidationError;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Data produk gagal dimuat: $error';
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), _loadData);
  }

  Future<void> _openProductForm([ProductModel? product]) async {
    final input = await showDialog<OwnerProductInput>(
      context: context,
      builder: (_) => _ProductFormDialog(
        product: product,
        categories: _categories,
      ),
    );
    if (input == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      if (product == null) {
        await _repository.createOwnerProduct(input);
        _showMessage('Produk berhasil ditambahkan.');
      } else {
        await _repository.updateOwnerProduct(
          productId: product.id,
          input: input,
        );
        _showMessage('Produk berhasil diperbarui.');
      }
      await _loadData();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage(error.firstValidationError, isError: true);
      }
    }
  }

  Future<void> _toggleProduct(ProductModel product) async {
    setState(() => _isLoading = true);
    final input = OwnerProductInput(
      categoryId: product.categoryId == 0 ? null : product.categoryId,
      sku: product.sku,
      name: product.name,
      description: product.description,
      costPrice: product.costPrice ?? 0,
      sellingPrice: product.sellingPrice,
      stock: product.stock,
      minimumStock: product.minimumStock,
      unit: product.unit,
      isActive: !product.isActive,
    );

    try {
      await _repository.updateOwnerProduct(productId: product.id, input: input);
      _showMessage(
        product.isActive ? 'Produk dinonaktifkan.' : 'Produk diaktifkan.',
      );
      await _loadData();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage(error.firstValidationError, isError: true);
      }
    }
  }

  Future<void> _manageCategories() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _CategoryManagerDialog(
        repository: _repository,
        initialCategories: _categories,
      ),
    );
    if (changed == true && mounted) await _loadData();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Produk'),
        actions: [
          IconButton(
            tooltip: 'Kelola kategori',
            onPressed: _isLoading ? null : _manageCategories,
            icon: const Icon(Icons.category_outlined),
          ),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Cari nama atau SKU produk',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                DropdownButton<int?>(
                  value: _categoryFilter,
                  hint: const Text('Semua kategori'),
                  items: [
                    ..._categories.map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _categoryFilter = value);
                    _loadData();
                  },
                ),
                if (_categoryFilter != null)
                  IconButton(
                    tooltip: 'Hapus filter kategori',
                    onPressed: () {
                      setState(() => _categoryFilter = null);
                      _loadData();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                const SizedBox(width: 12),
                SegmentedButton<bool?>(
                  segments: const [
                    ButtonSegment(value: null, label: Text('Semua')),
                    ButtonSegment(value: true, label: Text('Aktif')),
                    ButtonSegment(value: false, label: Text('Nonaktif')),
                  ],
                  selected: {_activeFilter},
                  onSelectionChanged: (values) {
                    setState(() => _activeFilter = values.first);
                    _loadData();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : () => _openProductForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Produk'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadData,
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }
    if (_products.isEmpty) {
      return const Center(child: Text('Produk tidak ditemukan.'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
        itemCount: _products.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final product = _products[index];
          return Card(
            child: ListTile(
              leading: _ProductImage(url: product.imageUrl),
              title: Text(product.name),
              subtitle: Text(
                '${product.sku} • ${product.categoryName}\n'
                '${_rupiah(product.sellingPrice)} • Stok ${product.stock} ${product.unit}',
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _openProductForm(product);
                  if (value == 'toggle') _toggleProduct(product);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit produk'),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(product.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _rupiah(int value) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(value);
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    if (url == null) {
      return const CircleAvatar(child: Icon(Icons.inventory_2_outlined));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: 54,
        height: 54,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.square(
          dimension: 54,
          child: Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({required this.product, required this.categories});
  final ProductModel? product;
  final List<CategoryModel> categories;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sku;
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _costPrice;
  late final TextEditingController _sellingPrice;
  late final TextEditingController _stock;
  late final TextEditingController _minimumStock;
  late final TextEditingController _unit;
  int? _categoryId;
  bool _isActive = true;
  String? _imagePath;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _sku = TextEditingController(text: product?.sku ?? '');
    _name = TextEditingController(text: product?.name ?? '');
    _description = TextEditingController(text: product?.description ?? '');
    _costPrice = TextEditingController(
      text: product?.costPrice?.toString() ?? '',
    );
    _sellingPrice = TextEditingController(
      text: product?.sellingPrice.toString() ?? '',
    );
    _stock = TextEditingController(text: product?.stock.toString() ?? '0');
    _minimumStock = TextEditingController(
      text: product?.minimumStock.toString() ?? '0',
    );
    _unit = TextEditingController(text: product?.unit ?? 'pcs');
    _categoryId = product == null || product.categoryId == 0
        ? null
        : product.categoryId;
    _isActive = product?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final controller in [
      _sku,
      _name,
      _description,
      _costPrice,
      _sellingPrice,
      _stock,
      _minimumStock,
      _unit,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'Tambah Produk' : 'Edit Produk'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: widget.categories
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            item.isActive
                                ? item.name
                                : '${item.name} (nonaktif)',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
                _field(_sku, 'SKU', required: true),
                _field(_name, 'Nama produk', required: true),
                _field(_description, 'Deskripsi', maxLines: 2),
                Row(
                  children: [
                    Expanded(
                      child: _numberField(
                        _costPrice,
                        'Harga modal',
                        minimum: 0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _numberField(
                        _sellingPrice,
                        'Harga jual',
                        minimum: 1,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _numberField(_stock, 'Stok', minimum: 0)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _numberField(
                        _minimumStock,
                        'Minimum stok',
                        minimum: 0,
                      ),
                    ),
                  ],
                ),
                _field(_unit, 'Satuan', required: true),
                const SizedBox(height: 12),
                _buildImagePicker(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Produk aktif'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) =>
                value == null || value.trim().isEmpty ? 'Wajib diisi.' : null
          : null,
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    required int minimum,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final parsed = int.tryParse(value ?? '');
        if (parsed == null || parsed < minimum) return 'Minimal $minimum.';
        return null;
      },
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      OwnerProductInput(
        categoryId: _categoryId,
        sku: _sku.text,
        name: _name.text,
        description: _description.text,
        costPrice: int.parse(_costPrice.text),
        sellingPrice: int.parse(_sellingPrice.text),
        stock: int.parse(_stock.text),
        minimumStock: int.parse(_minimumStock.text),
        unit: _unit.text,
        isActive: _isActive,
        imagePath: _imagePath,
      ),
    );
  }

  Widget _buildImagePicker() {
    final selectedPath = _imagePath;
    final existingUrl = widget.product?.imageUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: selectedPath != null
                ? Image.file(File(selectedPath), fit: BoxFit.cover)
                : existingUrl != null
                ? Image.network(
                    existingUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _imagePlaceholder(),
                  )
                : _imagePlaceholder(),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isPickingImage ? null : _pickImage,
          icon: _isPickingImage
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.photo_library_outlined),
          label: Text(
            selectedPath == null && existingUrl == null
                ? 'Pilih Gambar Produk'
                : 'Ganti Gambar Produk',
          ),
        ),
        Text(
          'JPG, PNG, atau WebP. Maksimal 4 MB.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _imagePlaceholder() {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.image_outlined, size: 52)),
    );
  }

  Future<void> _pickImage() async {
    setState(() => _isPickingImage = true);

    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (image == null || !mounted) return;

      final size = await File(image.path).length();
      if (size > 4 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ukuran gambar masih lebih dari 4 MB.'),
            ),
          );
        }
        return;
      }

      setState(() => _imagePath = image.path);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gambar gagal dipilih: $error')));
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }
}

class _CategoryManagerDialog extends StatefulWidget {
  const _CategoryManagerDialog({
    required this.repository,
    required this.initialCategories,
  });
  final ProductRepository repository;
  final List<CategoryModel> initialCategories;

  @override
  State<_CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<_CategoryManagerDialog> {
  late List<CategoryModel> _categories;
  bool _isSaving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _categories = List.of(widget.initialCategories);
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Kategori'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama kategori'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final category = await widget.repository.createOwnerCategory(name: name);
      if (!mounted) return;
      setState(() {
        _categories.add(category);
        _changed = true;
      });
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.firstValidationError)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggle(CategoryModel category) async {
    setState(() => _isSaving = true);
    try {
      final updated = await widget.repository.updateOwnerCategory(
        categoryId: category.id,
        name: category.name,
        description: category.description,
        isActive: !category.isActive,
      );
      if (!mounted) return;
      final index = _categories.indexWhere((item) => item.id == updated.id);
      setState(() {
        if (index >= 0) _categories[index] = updated;
        _changed = true;
      });
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.firstValidationError)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kelola Kategori'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: _categories.isEmpty
            ? const Center(child: Text('Belum ada kategori.'))
            : ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (_, index) {
                  final item = _categories[index];
                  return SwitchListTile(
                    title: Text(item.name),
                    subtitle: Text(item.isActive ? 'Aktif' : 'Nonaktif'),
                    value: item.isActive,
                    onChanged: _isSaving ? null : (_) => _toggle(item),
                  );
                },
              ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _isSaving ? null : _addCategory,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Tambah'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _changed),
          child: const Text('Selesai'),
        ),
      ],
    );
  }
}
