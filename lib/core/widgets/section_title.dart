// lib/core/widgets/section_title.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final bool? isDark;

  const SectionTitle({
    super.key,
    required this.title,
    this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = this.isDark ?? false;
    
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: isDark ? const Color(0xFFF0EAFF) : const Color(0xFF1F2937),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}