import 'package:flutter/material.dart';

import 'province_geometry.dart';

/// Fill-by-coverage-ratio, matching `fillFor()` in the original
/// 05-Region-Map.html mockup.
Color fillForRatio(double ratio) {
  if (ratio >= 0.85) return const Color(0xFF2C6B46);
  if (ratio >= 0.5) return const Color(0xFF54916B);
  if (ratio >= 0.2) return const Color(0xFF96BDA2);
  return const Color(0xFFDAE3D6);
}

class ProvinceMapPainter extends CustomPainter {
  ProvinceMapPainter({
    required this.geometry,
    required this.ratioFor,
    required this.labelFor,
    required this.selectedName,
  });

  final ProvinceGeometry geometry;
  final double Function(String name) ratioFor;
  final String Function(String name) labelFor;
  final String? selectedName;

  @override
  void paint(Canvas canvas, Size size) {
    // Context features (neighboring countries) extend geographically beyond
    // the province-only bounding box the projection is fit to, so they
    // project outside this canvas. The original HTML mockup got away with
    // this because an SVG's viewport clips overflow by default; Canvas does
    // not, so without this the context fill bleeds into whatever is above
    // the map in the layout.
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final contextPaint = Paint()
      ..color = const Color(0xFFEFE9DC)
      ..style = PaintingStyle.fill;
    final contextStroke = Paint()
      ..color = const Color(0xFFCFC6B4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final shape in geometry.context) {
      canvas.drawPath(shape.path, contextPaint);
      canvas.drawPath(shape.path, contextStroke);
    }

    // Matches the original mockup's `.prov-shape`/`.prov-shape.sel` CSS:
    // unselected provinces sit at 50% opacity, the selected one is full
    // opacity plus a drop shadow, and is drawn last (raised to the top, like
    // the JS version's `.raise()`) so its shadow isn't occluded by
    // neighbors. Stroke stays a constant 1.2px paper-colored outline either
    // way — selection is expressed by opacity + elevation, not stroke width.
    final ordered = [
      ...geometry.provinces.where((s) => s.name != selectedName),
      ...geometry.provinces.where((s) => s.name == selectedName),
    ];

    for (final shape in ordered) {
      final selected = shape.name == selectedName;
      final opacity = selected ? 1.0 : 0.5;

      if (selected) {
        final shadowPaint = Paint()
          ..color = const Color(0x47281F14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
        canvas.save();
        canvas.translate(0, 3);
        canvas.drawPath(shape.path, shadowPaint);
        canvas.restore();
      }

      final fillPaint = Paint()
        ..color = fillForRatio(ratioFor(shape.name)).withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawPath(shape.path, fillPaint);

      final strokePaint = Paint()
        ..color = const Color(0xFFEFE9DC).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawPath(shape.path, strokePaint);

      final ratio = ratioFor(shape.name);
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelFor(shape.name),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ratio >= 0.5 ? const Color(0xFFFBF7EE) : const Color(0xFF25543A),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, shape.labelPoint - Offset(textPainter.width / 2, textPainter.height / 2));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ProvinceMapPainter oldDelegate) =>
      oldDelegate.selectedName != selectedName || oldDelegate.geometry != geometry;
}
