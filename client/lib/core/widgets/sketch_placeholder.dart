import 'package:flutter/material.dart';

import '../theme.dart';

/// Port of `.sketch-placeholder` from tokens.css — stand-in for a real photo
/// until camera capture / object storage exist (see architecture.md phased
/// build order, phases 2-3). Renders a diagonal-hatch tile with a label.
class SketchPlaceholder extends StatelessWidget {
  const SketchPlaceholder({
    super.key,
    this.label = 'photo',
    this.borderRadius = AppRadius.md,
  });

  final String label;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.forestSoft,
          border: Border.all(color: AppColors.lineStrong, style: BorderStyle.solid),
        ),
        child: CustomPaint(
          painter: _HatchPainter(color: AppColors.forest.withValues(alpha: 0.08)),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.paperRaised,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: AppColors.forest,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  _HatchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const gap = 9.0;
    final diag = size.width + size.height;
    for (double x = -size.height; x < diag; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HatchPainter oldDelegate) => oldDelegate.color != color;
}
