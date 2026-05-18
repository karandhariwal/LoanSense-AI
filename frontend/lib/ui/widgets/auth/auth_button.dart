import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A reusable authentication button matching the reference design.
/// Features:
/// - Dark surface-container-high background (#2A2A2B)
/// - Subtle white/5 border
/// - Icon + label layout with 12px gap
/// - Rounded-xl (12px) corners
/// - py-4 px-6 padding (16px vertical, 24px horizontal)
/// - Glow effect on press
/// - Label uses Inter font at 12px, weight 600
class AuthButton extends StatefulWidget {
  final Widget? icon;
  final Widget Function(bool isPressed)? iconBuilder;
  final String label;
  final VoidCallback? onTap;

  const AuthButton({
    super.key,
    this.icon,
    this.iconBuilder,
    required this.label,
    this.onTap,
  }) : assert(icon != null || iconBuilder != null);

  @override
  State<AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<AuthButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return GestureDetector(
          onTapDown: (_) {
            setState(() => _isPressed = true);
            _glowController.forward();
          },
          onTapUp: (_) {
            setState(() => _isPressed = false);
            _glowController.reverse();
            widget.onTap?.call();
          },
          onTapCancel: () {
            setState(() => _isPressed = false);
            _glowController.reverse();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: _isPressed
                  ? const Color(0xFF353436) // surface-container-highest
                  : const Color(0xFF2A2A2B), // surface-container-high
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC3C6D7).withValues(
                    alpha: 0.2 * _glowController.value,
                  ),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.iconBuilder != null)
                  widget.iconBuilder!(_isPressed)
                else
                  widget.icon!,
                const SizedBox(width: 12),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE5E2E3),
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
