// lib/core/widgets/product_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductCard extends StatelessWidget {
  final String name;
  final String price;
  final double rating;
  final String soldCount;
  final String imageUrl;
  final bool isDark;
  final VoidCallback onAddToCart;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    required this.rating,
    required this.soldCount,
    required this.imageUrl,
    required this.isDark,
    required this.onAddToCart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16162A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFF3F4F6),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: imageUrl.isEmpty
                  ? Icon(
                      Icons.inventory_2_outlined,
                      color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
                      size: 40,
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.inventory_2_outlined,
                          color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
                          size: 40,
                        );
                      },
                    ),
            ),
            // Content - EXPANDED to fill remaining space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name - takes available space
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Rating
                    Row(
                      children: [
                        Icon(
                          Icons.star_rate_rounded,
                          color: const Color(0xFFFFD93D),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toString(),
                          style: GoogleFonts.inter(
                            color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "($soldCount terjual)",
                            style: GoogleFonts.inter(
                              color: isDark ? const Color(0xFF9B97B8) : const Color(0xFF6B7280),
                              fontSize: 9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Price & Add to Cart - FIXED AT BOTTOM
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            price,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF9B5EFF),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: onAddToCart,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF9B5EFF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add_shopping_cart_outlined,
                              color: Color(0xFF9B5EFF),
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}