// lib/core/widgets/theme_toggle_button.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kanzza_sales_app_fe/core/theme/theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  final bool showLabel;
  final double size;

  const ThemeToggleButton({
    super.key,
    this.showLabel = false,
    this.size = 44,
  });

  void _showThemeSnackBar(BuildContext context, bool isDark) {
    // Hilangkan snackbar sebelumnya
    ScaffoldMessenger.of(context).clearSnackBars();
    
    final snackBar = SnackBar(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isDark ? 'Mode Terang' : 'Mode Gelap',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isDark ? '☀️' : '🌙',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
      backgroundColor: isDark
          ? Colors.grey.shade900.withValues(alpha: 0.95)
          : const Color(0xFF7C3AED).withValues(alpha: 0.95),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      duration: const Duration(milliseconds: 1200),
      margin: const EdgeInsets.only(
        top: 60,
        left: 24,
        right: 24,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 12,
      ),
      elevation: 8,
      dismissDirection: DismissDirection.horizontal,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return GestureDetector(
      onTap: () {
        themeProvider.toggleTheme();
        _showThemeSnackBar(context, isDark);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1E35).withValues(alpha: 0.5)
              : const Color(0xFFF5F5FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? const Color(0xFF2D2D45)
                : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isDark ? Icons.light_mode : Icons.dark_mode,
          color: isDark ? const Color(0xFFFFD93D) : const Color(0xFF6B7280),
          size: size * 0.5,
        ),
      ),
    );
  }
}
