import 'package:flutter/material.dart';
import '../theme/cozy_colors.dart';
import '../theme/cozy_text.dart';

/// Port of BouncyButtonStyle: every interactive control in the Swift app
/// scales to 0.96 while pressed.
///
/// ponytail: AnimatedScale + easeOutBack, not a real SpringSimulation. The
/// original spring(response:0.3, dampingFraction:0.6) is under-damped and
/// overshoots slightly; easeOutBack reads near-identically for a tenth of the
/// code. Swap in a SpringSimulation if it ever feels flat side-by-side.
class Bouncy extends StatefulWidget {
  const Bouncy({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Bouncy> createState() => _BouncyState();
}

class _BouncyState extends State<Bouncy> {
  bool _pressed = false;

  void _set(bool v) {
    if (widget.onTap == null || _pressed == v) return;
    setState(() => _pressed = v);
  }

  // Press feedback comes from Listener, not GestureDetector.
  //
  // onTapDown/onTapUp enter the gesture arena and compete with any enclosing
  // scroll view: drift a pixel and the scroll wins, the tap is cancelled, and
  // the control only fires if you press and hold perfectly still. That reads as
  // "you have to hold it", which is exactly the bug this fixes. Listener sees
  // raw pointer events and never competes, so the visual is immediate while
  // onTap stays a plain, reliable tap.
  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      );
}

/// Port of CozyButton: full-width pill with optional leading icon.
class CozyButton extends StatelessWidget {
  const CozyButton({
    super.key,
    required this.title,
    this.icon,
    this.background = CozyColors.sageGreen,
    this.foreground = CozyColors.textPrimary,
    this.onTap,
  });

  final String title;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Bouncy(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(24),
            boxShadow: enabled
                ? cozyShadow(
                    swiftUiRadius: 8,
                    y: 4,
                    color: background.withValues(alpha: 0.3),
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: CozyText.rounded(17,
                      weight: FontWeight.w700, color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Port of PastelIconBadge: circular pastel chip with a centred glyph.
class PastelIconBadge extends StatelessWidget {
  const PastelIconBadge({
    super.key,
    required this.icon,
    this.background = CozyColors.sageGreen,
    this.foreground = CozyColors.textPrimary,
    this.size = 44,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background.withValues(alpha: 0.85),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size * 0.45, color: foreground),
      );
}
