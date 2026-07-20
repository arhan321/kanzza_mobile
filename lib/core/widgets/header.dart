// lib/core/widgets/header.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:kanzza_sales_app_fe/core/theme/theme_provider.dart';
import 'package:kanzza_sales_app_fe/core/widgets/theme_toggle_button.dart';

class Header extends StatelessWidget {
  final bool? isDark;
  final int notificationCount;
  final VoidCallback? onNotificationTap;

  const Header({
    super.key,
    this.isDark,
    this.notificationCount = 0,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = this.isDark ?? Provider.of<ThemeProvider>(context).isDarkMode;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Halo, Pelanggan! 👋",
                style: GoogleFonts.poppins(
                  color: isDark
                      ? const Color(0xFFF0EAFF)
                      : const Color(0xFF1F2937),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Belanja kebutuhan frozen food",
                style: GoogleFonts.inter(
                  color: isDark
                      ? const Color(0xFF9B97B8)
                      : const Color(0xFF6B7280),
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        // Right side - Buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ThemeToggleButton(),
            const SizedBox(width: 8),
            // Notification
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16162A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E1E35) : const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  IconButton(
                    tooltip: 'Notifikasi',
                    onPressed: onNotificationTap,
                    icon: Icon(
                      Icons.notifications_outlined,
                      color: isDark
                          ? const Color(0xFF9B97B8)
                          : const Color(0xFF6B7280),
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      top: 3,
                      right: 3,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5252),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF16162A)
                                : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          notificationCount > 99
                              ? '99+'
                              : '$notificationCount',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
