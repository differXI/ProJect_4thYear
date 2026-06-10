import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final _mapController = MapController();
  final _routeNameController = TextEditingController(text: 'Morning Campus Route');

  BaseMapData? _baseMap;
  List<ManualRouteItem> _manualRoutes = const [];
  List<RoutePoint> _drawnPoints = const [];
  ManualRouteItem? _selectedRoute;
  String? _message;
  bool _isLoading = false;

  static const _defaultCenter = LatLng(18.8059, 98.9523);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _routeNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final baseMap = await widget.controller.getBaseMap();
      final manualRoutes = widget.controller.isAuthenticated
          ? await widget.controller.getManualRoutes()
          : const <ManualRouteItem>[];
      if (!mounted) return;
      setState(() {
        _baseMap = baseMap;
        _manualRoutes = manualRoutes;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleMapTap(TapPosition _, LatLng point) {
    if (!widget.controller.isAuthenticated) {
      setState(() => _message = 'Sign in to draw and save routes.');
      return;
    }
    setState(() {
      _drawnPoints = [..._drawnPoints, RoutePoint(lat: point.latitude, lng: point.longitude)];
      _selectedRoute = null;
    });
  }

  Future<void> _saveRoute() async {
    if (_drawnPoints.length < 2) {
      setState(() => _message = 'Add at least two points on the map.');
      return;
    }
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      await widget.controller.createManualRoute(
        name: _routeNameController.text.trim(),
        points: _drawnPoints,
      );
      setState(() => _drawnPoints = const []);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRoute(ManualRouteItem route) async {
    setState(() => _isLoading = true);
    try {
      await widget.controller.deleteManualRoute(route.id);
      if (_selectedRoute?.id == route.id) {
        _selectedRoute = null;
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<LatLng> _polylinePoints(List<RoutePoint> points) {
    return points.map((point) => LatLng(point.lat, point.lng)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final map = _baseMap;
    final center = map != null && map.nodes.isNotEmpty
        ? LatLng(map.nodes.first.lat, map.nodes.first.lng)
        : _defaultCenter;

    final edgePolylines = map?.edges
            .map(
              (edge) => Polyline(
                points: _polylinePoints(edge.points),
                strokeWidth: 3,
                color: edge.riskScore >= 0.7
                    ? RunnaColors.warning.withValues(alpha: 0.8)
                    : RunnaColors.accent.withValues(alpha: 0.7),
              ),
            )
            .toList() ??
        const <Polyline>[];

    final hazardMarkers = map?.markers
            .map(
              (marker) => Marker(
                point: LatLng(marker.lat, marker.lng),
                width: 34,
                height: 34,
                child: const _PinIcon(color: RunnaColors.danger, icon: Icons.warning_amber_rounded),
              ),
            )
            .toList() ??
        const <Marker>[];

    final selectedPolyline = _selectedRoute != null ? _polylinePoints(_selectedRoute!.points) : const <LatLng>[];
    final drawnPolyline = _polylinePoints(_drawnPoints);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('Routes', subtitle: 'Draw, save, and reuse custom running routes'),
        const SizedBox(height: 16),
        Container(
          height: 360,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: RunnaColors.muted.withValues(alpha: 0.15)),
          ),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              onTap: _handleMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'runna_mobile',
              ),
              if (edgePolylines.isNotEmpty) PolylineLayer(polylines: edgePolylines),
              if (selectedPolyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(points: selectedPolyline, strokeWidth: 5, color: RunnaColors.primaryDark),
                  ],
                ),
              if (drawnPolyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(points: drawnPolyline, strokeWidth: 5, color: RunnaColors.primary),
                  ],
                ),
              MarkerLayer(
                markers: [
                  ...hazardMarkers,
                  ..._drawnPoints.map(
                    (point) => Marker(
                      point: LatLng(point.lat, point.lng),
                      width: 22,
                      height: 22,
                      child: const _PinIcon(color: RunnaColors.primary, icon: Icons.circle),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_message!, style: const TextStyle(color: RunnaColors.danger)),
          ),
        RunnaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _routeNameController,
                enabled: widget.controller.isAuthenticated,
                decoration: const InputDecoration(labelText: 'Route name'),
              ),
              const SizedBox(height: 12),
              Text('Points on map: ${_drawnPoints.length}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton(
                    onPressed: _isLoading || !widget.controller.isAuthenticated ? null : _saveRoute,
                    child: const Text('Save route'),
                  ),
                  OutlinedButton(
                    onPressed: _isLoading ? null : () => setState(() => _drawnPoints = const []),
                    child: const Text('Clear points'),
                  ),
                  FilledButton.tonal(
                    onPressed: _isLoading ? null : _load,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle('Saved routes'),
        const SizedBox(height: 12),
        if (!widget.controller.isAuthenticated)
          const RunnaCard(child: Text('Sign in to create and save your own routes.'))
        else if (_manualRoutes.isEmpty)
          const RunnaCard(child: Text('No saved routes yet. Tap the map to start drawing.'))
        else
          ..._manualRoutes.map(
            (route) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RunnaCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(route.name),
                  subtitle: Text('${route.distanceKm.toStringAsFixed(2)} km • ${route.points.length} points'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _isLoading ? null : () => _deleteRoute(route),
                  ),
                  onTap: () => setState(() {
                    _selectedRoute = route;
                    _drawnPoints = const [];
                  }),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PinIcon extends StatelessWidget {
  const _PinIcon({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}
