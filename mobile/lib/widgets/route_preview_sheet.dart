import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../core/models.dart';
import '../core/theme.dart';

/// Opens a bottom sheet with a real map preview of [route], reachable from
/// a "View map" action. Replaces the old pattern of navigating away to a
/// different tab just to see a route on a map.
void showRoutePreviewSheet(
  BuildContext context, {
  required ManualRouteItem route,
  required bool isFavorited,
  required bool isAuthenticated,
  required VoidCallback onToggleFavorite,
  required VoidCallback onRun,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return RoutePreviewSheet(
        route: route,
        isFavorited: isFavorited,
        isAuthenticated: isAuthenticated,
        onToggleFavorite: onToggleFavorite,
        onRun: () {
          Navigator.of(sheetContext).pop();
          onRun();
        },
      );
    },
  );
}

class RoutePreviewSheet extends StatefulWidget {
  const RoutePreviewSheet({
    super.key,
    required this.route,
    required this.isFavorited,
    required this.isAuthenticated,
    required this.onToggleFavorite,
    required this.onRun,
  });

  final ManualRouteItem route;
  final bool isFavorited;
  final bool isAuthenticated;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRun;

  @override
  State<RoutePreviewSheet> createState() => _RoutePreviewSheetState();
}

class _RoutePreviewSheetState extends State<RoutePreviewSheet> {
  late bool _isFavorited = widget.isFavorited;

  void _handleToggleFavorite() {
    setState(() => _isFavorited = !_isFavorited);
    widget.onToggleFavorite();
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    List<RoutePoint> routePoints = const [];
    try {
      routePoints = route.points;
    } catch (_) {
      routePoints = const [];
    }
    final points = routePoints.map((point) => LatLng(point.lat, point.lng)).toList();
    const fallbackCenter = LatLng(18.8059, 98.9523);

    final subtitleParts = <String>['By ${route.creatorFullName ?? 'Unknown'}'];
    if (route.creatorProvince != null && route.creatorProvince!.trim().isNotEmpty) {
      subtitleParts.add(route.creatorProvince!.trim());
    }

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: RunnaColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(RunnaSpacing.page, 12, RunnaSpacing.page, RunnaSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: RunnaColors.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    route.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: _handleToggleFavorite,
                  icon: Icon(
                    _isFavorited ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorited ? RunnaColors.danger : RunnaColors.muted,
                  ),
                  tooltip: _isFavorited ? 'Remove from favorites' : 'Add to favorites',
                ),
              ],
            ),
            Text(
              subtitleParts.join(' • '),
              style: const TextStyle(color: RunnaColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 220,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: points.isNotEmpty ? points.first : fallbackCenter,
                    initialZoom: 14,
                    initialCameraFit: points.length > 1
                        ? CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(36))
                        : null,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'runna_mobile',
                    ),
                    if (points.length > 1)
                      PolylineLayer(
                        polylines: [Polyline(points: points, strokeWidth: 5, color: RunnaColors.primary)],
                      ),
                    if (points.isNotEmpty)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: points.first,
                            width: 20,
                            height: 20,
                            child: const _PinDot(color: RunnaColors.primary),
                          ),
                          if (points.length > 1)
                            Marker(
                              point: points.last,
                              width: 20,
                              height: 20,
                              child: const _PinDot(color: RunnaColors.primaryDark),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatPill(icon: Icons.straighten, label: '${route.distanceKm.toStringAsFixed(1)} km'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatPill(icon: Icons.directions_run, label: '${route.runCount} runs'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.onRun,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(widget.isAuthenticated ? 'Start run' : 'Sign in to run'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: RunnaColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: RunnaColors.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

class _PinDot extends StatelessWidget {
  const _PinDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
