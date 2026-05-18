import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Futuristic divider with "SECURED BY AI" label.
/// Matches the reference:
/// - Two thin horizontal lines (white/5) flanking the text
/// - Label: Inter, 12px, weight 600, on-surface-variant/40
/// - 12px vertical margin
class SecurityDivider extends StatelessWidget {
  final String label;

  const SecurityDivider({
    super.key,
    this.label = 'SECURED BY AI',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFC7C6CC).withValues(alpha: 0.40),
                height: 1.0,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ],
      ),
    );
  }
}
