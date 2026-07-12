import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const DashboardCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.04,
            ),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            height: 55,
            width: 55,

            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(16),

              gradient: const LinearGradient(
                colors: [
                  Color(0xFF8B5CF6),
                  Color(0xFF5B21B6),
                ],
              ),
            ),

            child: Icon(
              icon,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      GoogleFonts.poppins(
                    fontWeight:
                        FontWeight.w600,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      GoogleFonts.inter(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}