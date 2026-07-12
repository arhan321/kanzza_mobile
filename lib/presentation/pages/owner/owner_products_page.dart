// lib/features/owner/presentation/pages/owner_products_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:kanzza_sales_app_fe/core/theme/theme_provider.dart';
import 'package:kanzza_sales_app_fe/routes.dart';

class OwnerProductsPage extends StatefulWidget {
  const OwnerProductsPage({super.key});

  @override
  State<OwnerProductsPage> createState() => _OwnerProductsPageState();
}

class _OwnerProductsPageState extends State<OwnerProductsPage> {
  // Form Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedCategory = "Snack";
  String? _selectedImageName;
  bool _isLoading = false;
  bool _isEditing = false;
  int? _editingId;
  
  // Daftar produk (simulasi database)
  List<Map<String, dynamic>> _products = [
    {
      'id': 1,
      'name': 'Keripik Singkong Original',
      'price': 15000,
      'category': 'Snack',
      'stock': 45,
      'image': null,
      'popular': true,
    },
    {
      'id': 2,
      'name': 'Air Mineral 600ml',
      'price': 4000,
      'category': 'Minuman',
      'stock': 120,
      'image': null,
      'popular': true,
    },
    {
      'id': 3,
      'name': 'Es Krim Coklat',
      'price': 12000,
      'category': 'Frozen',
      'stock': 30,
      'image': null,
      'popular': false,
    },
    {
      'id': 4,
      'name': 'Beras Premium 5kg',
      'price': 65000,
      'category': 'Sembako',
      'stock': 15,
      'image': null,
      'popular': true,
    },
  ];

  final List<String> _categories = ["Snack", "Minuman", "Frozen", "Sembako", "Instan"];

  List<Map<String, dynamic>> get _filteredProducts {
    if (_searchController.text.isEmpty) return _products;
    return _products.where((p) => 
      p['name'].toLowerCase().contains(_searchController.text.toLowerCase())
    ).toList();
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  // Simulasi upload image
  void _pickImage() {
    setState(() {
      _selectedImageName = "product_${DateTime.now().millisecondsSinceEpoch}.jpg";
    });
    _showSnackBar("📷 Foto berhasil dipilih: $_selectedImageName", Colors.green);
  }

  void _resetForm() {
    setState(() {
      _nameController.clear();
      _priceController.clear();
      _stockController.clear();
      _selectedImageName = null;
      _selectedCategory = "Snack";
      _isEditing = false;
      _editingId = null;
    });
  }

  void _editProduct(Map<String, dynamic> product) {
    setState(() {
      _isEditing = true;
      _editingId = product['id'];
      _nameController.text = product['name'];
      _priceController.text = product['price'].toString();
      _stockController.text = product['stock'].toString();
      _selectedCategory = product['category'];
      _selectedImageName = product['image'];
    });
  }

  void _saveProduct() {
    // Validasi
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar("Nama produk harus diisi!", Colors.orange);
      return;
    }
    
    if (_priceController.text.trim().isEmpty) {
      _showSnackBar("Harga produk harus diisi!", Colors.orange);
      return;
    }
    
    if (_stockController.text.trim().isEmpty) {
      _showSnackBar("Stok produk harus diisi!", Colors.orange);
      return;
    }

    final price = int.tryParse(_priceController.text.trim());
    final stock = int.tryParse(_stockController.text.trim());
    
    if (price == null || price <= 0) {
      _showSnackBar("Harga harus berupa angka positif!", Colors.red);
      return;
    }
    
    if (stock == null || stock < 0) {
      _showSnackBar("Stok harus berupa angka!", Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulasi delay
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        if (_isEditing && _editingId != null) {
          // Edit produk
          final index = _products.indexWhere((p) => p['id'] == _editingId);
          if (index != -1) {
            _products[index] = {
              ..._products[index],
              'name': _nameController.text.trim(),
              'price': price,
              'category': _selectedCategory,
              'stock': stock,
              'image': _selectedImageName,
            };
          }
          _showSnackBar("✅ Produk berhasil diperbarui!", Colors.green);
        } else {
          // Tambah produk baru
          final newProduct = {
            'id': _products.length + 1,
            'name': _nameController.text.trim(),
            'price': price,
            'category': _selectedCategory,
            'stock': stock,
            'image': _selectedImageName,
            'popular': false,
          };
          _products.insert(0, newProduct);
          _showSnackBar("✅ Produk berhasil ditambahkan!", Colors.green);
        }
        
        _isLoading = false;
        _resetForm();
      });
    });
  }

  void _deleteProduct(int id) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
        final theme = Theme.of(context);
        
        return AlertDialog(
          backgroundColor: theme.cardTheme.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE8E8F0),
            ),
          ),
          title: Text(
            "Hapus Produk",
            style: GoogleFonts.poppins(
              color: theme.textTheme.titleLarge?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            "Apakah Anda yakin ingin menghapus produk ini?",
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
                setState(() {
                  _products.removeWhere((p) => p['id'] == id);
                });
                Navigator.pop(context);
                _showSnackBar("🗑️ Produk berhasil dihapus!", Colors.red);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Hapus",
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

  Widget _buildUploadPlaceholder(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_upload_outlined,
          color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
          size: 40,
        ),
        const SizedBox(height: 8),
        Text(
          "Tap untuk upload foto produk",
          style: GoogleFonts.inter(
            color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
            fontSize: 13,
          ),
        ),
        if (_selectedImageName != null) ...[
          const SizedBox(height: 4),
          Text(
            _selectedImageName!,
            style: GoogleFonts.inter(
              color: const Color(0xFF9B5EFF),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildProductImage(Map<String, dynamic> product, bool isDark) {
    bool hasImage = product['image'] != null && product['image'].toString().isNotEmpty;
    
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: hasImage
          ? Center(
              child: Icon(
                Icons.image_outlined,
                color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
                size: 28,
              ),
            )
          : Icon(
              Icons.inventory_2_outlined,
              color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
              size: 28,
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
            // Header
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
                      "Kelola Produk",
                      style: GoogleFonts.poppins(
                        color: isDark
                            ? const Color(0xFFF0EAFF)
                            : const Color(0xFF1F2937),
                        fontSize: isTablet ? 26 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Tombol Tambah Produk
                  GestureDetector(
                    onTap: () {
                      _resetForm();
                      _showAddProductDialog(isDark);
                    },
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

            // Content
            Expanded(
              child: Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() {}),
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: "Cari produk...",
                        hintStyle: GoogleFonts.inter(
                          color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
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
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF9B5EFF), width: 1),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),

                  // Product List
                  Expanded(
                    child: _filteredProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
                                  size: 64,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isNotEmpty
                                      ? "Produk tidak ditemukan"
                                      : "Belum ada produk",
                                  style: GoogleFonts.poppins(
                                    color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchController.text.isNotEmpty
                                      ? "Coba gunakan kata kunci lain"
                                      : "Klik + untuk menambahkan produk",
                                  style: GoogleFonts.inter(
                                    color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = _filteredProducts[index];
                              return _buildProductCard(product, isDark);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isDark) {
    final theme = Theme.of(context);
    
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
          // Image
          _buildProductImage(product, isDark),
          const SizedBox(width: 12),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'],
                  style: GoogleFonts.inter(
                    color: theme.textTheme.titleLarge?.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9B5EFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF9B5EFF).withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        product['category'],
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9B5EFF),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: product['stock'] > 10
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: product['stock'] > 10
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        "Stok: ${product['stock']}",
                        style: GoogleFonts.inter(
                          color: product['stock'] > 10
                              ? Colors.green.shade400
                              : Colors.red.shade400,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (product['popular'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFFF9800).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          "⭐ Populer",
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFF9800),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "Rp ${_formatPrice(product['price'])}",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF9B5EFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          
          // Actions
          Column(
            children: [
              // Edit Button
              GestureDetector(
                onTap: () {
                  _editProduct(product);
                  _showAddProductDialog(isDark);
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.2),
                    ),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    color: Colors.blue.shade400,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Delete Button
              GestureDetector(
                onTap: () => _deleteProduct(product['id']),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.2),
                    ),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade400,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(bool isDark) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16162A) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isEditing ? "Edit Produk" : "Tambah Produk",
                          style: GoogleFonts.poppins(
                            color: theme.textTheme.titleLarge?.color,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            _resetForm();
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.close,
                              color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Upload Image
                    GestureDetector(
                      onTap: () {
                        _pickImage();
                        setStateDialog(() {});
                      },
                      child: Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0D0D12) : const Color(0xFFF5F5FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: _selectedImageName != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_outlined,
                                      color: const Color(0xFF9B5EFF),
                                      size: 40,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _selectedImageName!,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF9B5EFF),
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              )
                            : _buildUploadPlaceholder(isDark),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nama Produk
                    Text(
                      "Nama Produk",
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: "Masukkan nama produk",
                        hintStyle: GoogleFonts.inter(
                          color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
                          fontSize: 14,
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
                    ),
                    const SizedBox(height: 12),

                    // Harga & Stok
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Harga (Rp)",
                                style: GoogleFonts.inter(
                                  color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: GoogleFonts.inter(
                                  color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: "0",
                                  hintStyle: GoogleFonts.inter(
                                    color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
                                    fontSize: 14,
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
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Stok",
                                style: GoogleFonts.inter(
                                  color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _stockController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: GoogleFonts.inter(
                                  color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: "0",
                                  hintStyle: GoogleFonts.inter(
                                    color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
                                    fontSize: 14,
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
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Kategori
                    Text(
                      "Kategori",
                      style: GoogleFonts.inter(
                        color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0D0D12) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          dropdownColor: isDark ? const Color(0xFF1E1E35) : Colors.white,
                          style: GoogleFonts.inter(
                            color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                          ),
                          isExpanded: true,
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setStateDialog(() {
                                _selectedCategory = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _resetForm();
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  "Batal",
                                  style: GoogleFonts.inter(
                                    color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: _isLoading ? null : () {
                              _saveProduct();
                              if (_nameController.text.isNotEmpty && 
                                  _priceController.text.isNotEmpty && 
                                  _stockController.text.isNotEmpty) {
                                Navigator.pop(context);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF9B5EFF), Color(0xFF6C3BD8)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        _isEditing ? "Update" : "Simpan",
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}