// lib/core/widgets/gradient_nav_bar.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GradientNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isDark;

  const GradientNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13102A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black12 : Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_outlined, Icons.home, "Beranda", 0),
            _buildNavItem(Icons.receipt_long_outlined, Icons.receipt_long, "Pesanan", 1),
            _buildNavItem(Icons.shopping_cart_outlined, Icons.shopping_cart, "Keranjang", 2),
            _buildNavItem(Icons.person_outlined, Icons.person, "Profil", 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index) {
    final isSelected = currentIndex == index;
    final color = isSelected
        ? const Color(0xFF9B5EFF)
        : isDark
            ? const Color(0xFF9B97B8)
            : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}