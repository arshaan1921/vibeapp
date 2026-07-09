import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZayloColors {
  static const List<Color> primaryGradient = [
    Color(0xFF8E24AA), // Purple
    Color(0xFFD81B60), // Pink
  ];
  static const Color electricBlue = Color(0xFF00E5FF);
}

class ZayloGradientButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool animate;

  const ZayloGradientButton({
    super.key,
    required this.text,
    required this.onTap,
    this.animate = true,
  });

  @override
  State<ZayloGradientButton> createState() => _ZayloGradientButtonState();
}

class _ZayloGradientButtonState extends State<ZayloGradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: ZayloColors.primaryGradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: ZayloColors.primaryGradient[0].withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Center(
              child: Text(
                widget.text,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ZayloInterestChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const ZayloInterestChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: ZayloColors.primaryGradient)
              : null,
          color: isSelected
              ? null
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}

class RadarAnimation extends StatefulWidget {
  const RadarAnimation({super.key});

  @override
  State<RadarAnimation> createState() => _RadarAnimationState();
}

class _RadarAnimationState extends State<RadarAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            ...List.generate(3, (index) {
              final double value = (_controller.value + index / 3) % 1.0;
              return Opacity(
                opacity: 1.0 - value,
                child: Container(
                  width: 300 * value,
                  height: 300 * value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ZayloColors.primaryGradient[0].withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                ),
              );
            }),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: ZayloColors.primaryGradient),
                boxShadow: [
                  BoxShadow(
                    color: ZayloColors.primaryGradient[0].withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_search_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ],
        );
      },
    );
  }
}
