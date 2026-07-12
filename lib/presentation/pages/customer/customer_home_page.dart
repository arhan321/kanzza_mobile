// lib/presentation/pages/customer/customer_home_page.dart

import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:kanzza_sales_app_fe/core/theme/theme_provider.dart';
import 'package:kanzza_sales_app_fe/core/widgets/gradient_nav_bar.dart';
import 'package:kanzza_sales_app_fe/core/widgets/header.dart';
import 'package:kanzza_sales_app_fe/core/widgets/search_bar.dart';
import 'package:kanzza_sales_app_fe/core/widgets/promo_banner.dart';
import 'package:kanzza_sales_app_fe/core/widgets/section_title.dart';
import 'package:kanzza_sales_app_fe/core/widgets/product_card.dart';

import 'customer_cart_page.dart';
import 'customer_profile_page.dart';
import 'customer_orders_page.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  int currentIndex = 0;
  int selectedCategory = 0;
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _allProducts = [
    {
      'name': 'Keripik Singkong Original',
      'price': 15000,
      'category': 'Snack',
      'rating': 4.8,
      'sold': '234',
      'image': '',
    },
    {
      'name': 'Air Mineral 600ml',
      'price': 4000,
      'category': 'Minuman',
      'rating': 4.9,
      'sold': '1.2k',
      'image': '',
    },
    {
      'name': 'Es Krim Coklat',
      'price': 12000,
      'category': 'Frozen',
      'rating': 4.7,
      'sold': '567',
      'image': '',
    },
    {
      'name': 'Beras Premium 5kg',
      'price': 65000,
      'category': 'Sembako',
      'rating': 4.9,
      'sold': '892',
      'image': '',
    },
    {
      'name': 'Mie Instan Goreng',
      'price': 3500,
      'category': 'Instan',
      'rating': 4.6,
      'sold': '3.4k',
      'image': '',
    },
    {
      'name': 'Teh Botol 350ml',
      'price': 5000,
      'category': 'Minuman',
      'rating': 4.7,
      'sold': '1.8k',
      'image': '',
    },
    {
      'name': 'Keripik Singkong Original Sangat Panjang Untuk Testing',
      'price': 15000,
      'category': 'Snack',
      'rating': 4.8,
      'sold': '234',
      'image': '',
    },
  ];

  final categories = [
    "Semua",
    "Snack",
    "Minuman",
    "Frozen",
    "Sembako",
    "Buah",
    "Instan",
  ];

  List<Map<String, dynamic>> get _filteredProducts {
    var filtered = _allProducts;

    if (selectedCategory > 0) {
      filtered = filtered
          .where((product) => product['category'] == categories[selectedCategory])
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) =>
          product['name'].toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    return filtered;
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  void _scrollToProducts() {
    _scrollController.animateTo(
      350,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _onNavTap(int index) {
    if (index == 0) {
      setState(() => currentIndex = 0);
      return;
    }
    
    setState(() => currentIndex = index);
    
    Widget page;
    if (index == 1) {
      page = const CustomerOrdersPage();
    } else if (index == 2) {
      page = const CustomerCartPage();
    } else if (index == 3) {
      page = const CustomerProfilePage();
    } else {
      setState(() => currentIndex = 0);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    ).then((_) {
      if (mounted) setState(() => currentIndex = 0);
    });
  }

  void _addToCart(Map<String, dynamic> product) {
    HapticFeedback.lightImpact();
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "${product['name']} ditambahkan ke keranjang",
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: isDark ? const Color(0xFF9B5EFF) : const Color(0xFF7C3AED),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
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
        child: SafeArea(
          child: Column(
            children: [
              // Konten scrollable
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: hPad),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            Header(isDark: isDark),
                            const SizedBox(height: 20),
                            SearchBar(
                              onSearchChanged: (query) {
                                setState(() {
                                  _searchQuery = query;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                            PromoBanner(
                              onTap: _scrollToProducts,
                            ),
                            const SizedBox(height: 24),
                            SectionTitle(title: "Kategori", isDark: isDark),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                      
                      // Category List
                      SizedBox(
                        height: 45,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final selected = selectedCategory == index;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(categories[index]),
                                selected: selected,
                                onSelected: (val) {
                                  setState(() {
                                    selectedCategory = index;
                                  });
                                },
                                backgroundColor: isDark ? const Color(0xFF16162A) : Colors.white,
                                selectedColor: const Color(0xFF9B5EFF).withOpacity(0.2),
                                checkmarkColor: const Color(0xFF9B5EFF),
                                labelStyle: GoogleFonts.inter(
                                  color: selected 
                                      ? const Color(0xFF9B5EFF) 
                                      : isDark 
                                          ? const Color(0xFF8B8BA8) 
                                          : const Color(0xFF6B7280),
                                  fontSize: 13,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                ),
                                shape: StadiumBorder(
                                  side: BorderSide(
                                    color: selected 
                                        ? const Color(0xFF9B5EFF) 
                                        : isDark 
                                            ? const Color(0xFF1E1E35) 
                                            : const Color(0xFFE5E7EB),
                                    width: 1,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // Product Section
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: hPad),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            SectionTitle(
                              title: _searchQuery.isNotEmpty 
                                  ? "Hasil Pencarian: '$_searchQuery'" 
                                  : "Produk Populer",
                              isDark: isDark,
                            ),
                            if (_searchQuery.isNotEmpty && _filteredProducts.isEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                "Produk tidak ditemukan",
                                style: GoogleFonts.inter(
                                  color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      
                      // Product Grid
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: hPad),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredProducts.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isTablet ? 3 : 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.62,
                          ),
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            final price = product['price'] is int 
                                ? 'Rp ${_formatPrice(product['price'])}'
                                : product['price'];
                            
                            return ProductCard(
                              name: product['name'],
                              price: price,
                              rating: product['rating'],
                              soldCount: product['sold'],
                              imageUrl: product['image'],
                              isDark: isDark,
                              onAddToCart: () => _addToCart(product),
                              onTap: () {},
                            );
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
              
              // Bottom Navigation Bar
              GradientNavBar(
                currentIndex: currentIndex,
                onTap: _onNavTap,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}