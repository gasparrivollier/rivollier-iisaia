import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

/// A single province (or context/background) shape, pre-projected into
/// canvas-local coordinates so the painter never touches lon/lat.
class ProvinceShape {
  ProvinceShape({required this.name, required this.kind, required this.path});

  final String name;
  final String kind;
  final Path path;

  Offset get labelPoint => path.getBounds().center;
}

/// Parses design/yvoty-ui/data/ar-lowpoly.geojson (bundled as an app asset)
/// and projects it with a simple equirectangular fit — good enough for a
/// small-country illustrative map; d3's spherical mercator (used in the
/// original HTML mockup) isn't needed at this scale.
class ProvinceGeometry {
  ProvinceGeometry({required this.provinces, required this.context});

  final List<ProvinceShape> provinces;
  final List<ProvinceShape> context;

  static Future<ProvinceGeometry> load(String assetPath, Size canvasSize) async {
    final raw = await rootBundle.loadString(assetPath);
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    final features = (doc['features'] as List).cast<Map<String, dynamic>>();

    double lonMin = 180, lonMax = -180, latMin = 90, latMax = -90;
    for (final f in features) {
      final props = f['properties'] as Map<String, dynamic>;
      if (props['kind'] != 'provincia') continue;
      for (final ring in _rings(f['geometry'] as Map<String, dynamic>)) {
        for (final pt in ring) {
          final lon = pt[0].toDouble();
          final lat = pt[1].toDouble();
          if (lon < lonMin) lonMin = lon;
          if (lon > lonMax) lonMax = lon;
          if (lat < latMin) latMin = lat;
          if (lat > latMax) latMax = lat;
        }
      }
    }

    const pad = 16.0;
    final availW = canvasSize.width - pad * 2;
    final availH = canvasSize.height - pad * 2;
    final lonSpan = lonMax - lonMin == 0 ? 1.0 : lonMax - lonMin;
    final latSpan = latMax - latMin == 0 ? 1.0 : latMax - latMin;
    final scale = (availW / lonSpan < availH / latSpan) ? availW / lonSpan : availH / latSpan;
    final projW = lonSpan * scale;
    final projH = latSpan * scale;
    final offsetX = pad + (availW - projW) / 2 - lonMin * scale;
    final offsetY = pad + (availH - projH) / 2 + latMax * scale;

    Offset project(num lon, num lat) => Offset(lon * scale + offsetX, -lat * scale + offsetY);

    Path buildPath(Map<String, dynamic> geometry) {
      final path = Path()..fillType = PathFillType.evenOdd;
      for (final ring in _rings(geometry)) {
        if (ring.isEmpty) continue;
        final first = project(ring.first[0], ring.first[1]);
        path.moveTo(first.dx, first.dy);
        for (final pt in ring.skip(1)) {
          final o = project(pt[0], pt[1]);
          path.lineTo(o.dx, o.dy);
        }
        path.close();
      }
      return path;
    }

    final provinces = <ProvinceShape>[];
    final ctx = <ProvinceShape>[];
    for (final f in features) {
      final props = f['properties'] as Map<String, dynamic>;
      final shape = ProvinceShape(
        name: (props['name'] as String?) ?? '',
        kind: (props['kind'] as String?) ?? '',
        path: buildPath(f['geometry'] as Map<String, dynamic>),
      );
      if (shape.kind == 'provincia') {
        provinces.add(shape);
      } else {
        ctx.add(shape);
      }
    }

    return ProvinceGeometry(provinces: provinces, context: ctx);
  }

  /// Flattens a Polygon or MultiPolygon geometry to a plain list of rings —
  /// a ring being a list of `[lon, lat]` points.
  static List<List<List<num>>> _rings(Map<String, dynamic> geometry) {
    final type = geometry['type'] as String;
    final coords = geometry['coordinates'] as List;

    List<num> point(dynamic p) => (p as List).cast<num>();
    List<List<num>> ring(dynamic r) => (r as List).map(point).toList();

    if (type == 'MultiPolygon') {
      return coords.expand((polygon) => (polygon as List).map(ring)).toList();
    }
    // Polygon: coords is already a list of rings.
    return coords.map(ring).toList();
  }
}
