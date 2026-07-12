import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final void Function(String)? onFieldSubmitted;
  final String? Function(String?)? validator;
  final bool enabled;
  final int? maxLines;
  final int? minLines;

  const AppTextField({
    super.key,
    this.controller,
    required this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.validator,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      enabled: enabled,
      maxLines: maxLines,
      minLines: minLines,
      style: GoogleFonts.inter(
        fontSize: 15,
        color: const Color(0xFF1F2937),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.grey.shade400,
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                size: 20,
                color: Colors.grey.shade500,
              )
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7132F5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}