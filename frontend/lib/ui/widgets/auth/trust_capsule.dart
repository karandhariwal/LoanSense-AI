import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Trust capsule / privacy indicator matching the reference design.
/// Features:
/// - primary/5 background
/// - primary/10 border
/// - verified_user icon in primary color
/// - Label: Inter, 12px, weight 600, on-surface-variant/80
/// - 12px padding, 8px border-radius
class TrustCapsule extends StatelessWidget {
  final String message;

  const TrustCapsule({
    super.key,
    this.message = 'Zero-knowledge proof authentication enabled.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFC3C6D7).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFC3C6D7).withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user,
            color: Color(0xFFC3C6D7),
            size: 14,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFC7C6CC).withValues(alpha: 0.80),
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
