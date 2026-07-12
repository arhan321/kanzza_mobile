import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  static final headline = GoogleFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static final title = GoogleFonts.poppins(
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );

  static final body = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  static final caption = GoogleFonts.inter(
    fontSize: 14,
    color: Colors.grey,
  );
}