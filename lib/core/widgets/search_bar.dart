// lib/core/widgets/search_bar.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:kanzza_sales_app_fe/core/theme/theme_provider.dart';

class SearchBar extends StatefulWidget {
  final Function(String)? onSearchChanged;

  const SearchBar({
    super.key,
    this.onSearchChanged,
  });

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16162A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: TextField(
        controller: _controller,
        style: GoogleFonts.inter(
          color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
          fontSize: 14,
        ),
        onChanged: (value) {
          if (widget.onSearchChanged != null) {
            widget.onSearchChanged!(value);
          }
        },
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          hintText: "Cari produk...",
          hintStyle: GoogleFonts.inter(
            color: isDark ? const Color(0xFF5C5878) : const Color(0xFF9CA3AF),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? const Color(0xFF8B8BA8) : const Color(0xFF9CA3AF),
            size: 20,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    setState(() {
                      _controller.clear();
                    });
                    if (widget.onSearchChanged != null) {
                      widget.onSearchChanged!('');
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      color: isDark ? const Color(0xFF8B8BA8) : const Color(0xFF9CA3AF),
                      size: 18,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}