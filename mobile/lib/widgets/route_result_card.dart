import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';

/// A compact card used to present a community/favorite route: name, creator
/// (with province, when known), run count and distance as plain text, a
/// favorite toggle, and explicit "View map" / "Run" actions.
///
/// Used on the Home screen's community list and the Routes screen's
/// favorites list so both look and behave the same way.
class RouteResultCard extends StatelessWidget {
  const RouteResultCard({
    super.key,
    required this.route,
    required this.isFavorited,
    required this.onToggleFavorite,
    required this.onViewMap,
    required this.onRun,
  });

  final ManualRouteItem route;
  final bool isFavorited;
  final VoidCallback onToggleFavorite;
  final VoidCallback onViewMap;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>['By ${route.creatorFullName ?? 'Unknown'}'];
    if (route.creatorProvince != null && route.creatorProvince!.trim().isNotEmpty) {
      subtitleParts.add(route.creatorProvince!.trim());
    }
    subtitleParts.add('${route.runCount} runs');

    return RunnaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RouteThumbnail(route: route, onTap: onViewMap),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitleParts.join(' • '),
                      style: const TextStyle(color: RunnaColors.muted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${route.distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onToggleFavorite,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isFavorited ? Icons.favorite : Icons.favorite_border,
                    color: isFavorited ? RunnaColors.danger : RunnaColors.muted,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewMap,
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('View map'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onRun,
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Run'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteThumbnail extends StatelessWidget {
  const _RouteThumbnail({required this.route, required this.onTap});

  final ManualRouteItem route;
  final VoidCallback onTap;
  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    List<RoutePoint> points = const [];
    try {
      points = route.points;
    } catch (_) {
      points = const [];
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: RunnaColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: RunnaColors.muted.withValues(alpha: 0.15)),
        ),
        clipBehavior: Clip.antiAlias,
        child: points.length >= 2
            ? CustomPaint(painter: _RouteShapePainter(points: points, color: RunnaColors.primary))
            : const Icon(Icons.map_rounded, color: RunnaColors.primary, size: 22),
      ),
    );
  }
}

class _RouteShapePainter extends CustomPainter {
  _RouteShapePainter({required this.points, required this.color});

  final List<RoutePoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    var minLat = points.first.lat, maxLat = points.first.lat;
    var minLng = points.first.lng, maxLng = points.first.lng;
    for (final point in points) {
      minLat = math.min(minLat, point.lat);
      maxLat = math.max(maxLat, point.lat);
      minLng = math.min(minLng, point.lng);
      maxLng = math.max(maxLng, point.lng);
    }
    final latSpan = (maxLat - minLat).abs() < 1e-9 ? 1e-9 : maxLat - minLat;
    final lngSpan = (maxLng - minLng).abs() < 1e-9 ? 1e-9 : maxLng - minLng;
    const padding = 9.0;
    final drawWidth = size.width - padding * 2;
    final drawHeight = size.height - padding * 2;

    Offset project(RoutePoint point) {
      final x = padding + ((point.lng - minLng) / lngSpan) * drawWidth;
      final y = padding + (1 - (point.lat - minLat) / latSpan) * drawHeight;
      return Offset(x, y);
    }

    final offsets = points.map(project).toList();
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final offset in offsets.skip(1)) {
      path.lineTo(offset.dx, offset.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(offsets.first, 3, Paint()..color = color);
    canvas.drawCircle(offsets.last, 3, Paint()..color = color.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(covariant _RouteShapePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}
