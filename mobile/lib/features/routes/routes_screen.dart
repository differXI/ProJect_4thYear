import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/route_preview_sheet.dart';
import '../../widgets/route_result_card.dart';
import '../auth/auth_controller.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key, required this.controller, this.onNavigate});

  final AuthController controller;

  /// Optional callback to switch bottom-nav tabs (e.g. jump to the Runs tab
  /// after starting a run on a favorited route).
  final ValueChanged<int>? onNavigate;

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final _mapController = MapController();
  final _routeNameController = TextEditingController();
  final _searchController = TextEditingController();
  static const _distanceCalculator = Distance();

  BaseMapData? _baseMap;
  List<ManualRouteItem> _manualRoutes = const [];
  List<ManualRouteItem> _favoriteRoutes = const [];
  List<HazardMarkerItem> _hazardMarkers = const [];
  List<RoutePoint> _drawnPoints = const [];
  ManualRouteItem? _selectedRoute;
  LatLng? _currentLocation;
  String? _message;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isLocating = false;
  bool _showHazardPins = true;

  static const _defaultCenter = LatLng(18.8059, 98.9523);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _routeNameController.dispose();
    _searchController.dispose();
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
      final hazardMarkers = await widget.controller.getMarkers();
      if (!mounted) return;
      setState(() {
        _baseMap = baseMap;
        _manualRoutes = manualRoutes;
        _hazardMarkers = hazardMarkers;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    // Loaded separately so a favorites hiccup never blocks the map/saved routes above.
    if (widget.controller.isAuthenticated) {
      try {
        final favoriteRoutes = await widget.controller.getFavoriteRoutes();
        if (!mounted) return;
        setState(() => _favoriteRoutes = favoriteRoutes);
      } catch (error) {
        if (!mounted) return;
        setState(() => _message = '$error');
      }
    } else if (mounted) {
      setState(() => _favoriteRoutes = const []);
    }
  }

  void _handleMapTap(TapPosition _, LatLng point) {
    if (!widget.controller.isAuthenticated) {
      setState(() => _message = 'Sign in to create and save routes.');
      return;
    }
    setState(() {
      _drawnPoints = [..._drawnPoints, RoutePoint(lat: point.latitude, lng: point.longitude)];
      _selectedRoute = null;
    });
  }

  Future<void> _goToMyLocation() async {
    setState(() {
      _isLocating = true;
      _message = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are turned off. Please enable GPS.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied. Enable it from app settings.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final here = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() => _currentLocation = here);
      _mapController.move(here, 16);
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
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
      final trimmedName = _routeNameController.text.trim();
      await widget.controller.createManualRoute(
        name: trimmedName.isEmpty ? 'Route ${_manualRoutes.length + 1}' : trimmedName,
        points: _drawnPoints,
      );
      _routeNameController.clear();
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

  Future<void> _unfavoriteRoute(ManualRouteItem route) async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      await widget.controller.favoriteManualRoute(routeId: route.id, favorite: false);
      if (!mounted) return;
      setState(() {
        _favoriteRoutes = _favoriteRoutes.where((existing) => existing.id != route.id).toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startRunOnFavorite(ManualRouteItem route) async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      await widget.controller.startRun(
        manualRouteId: route.id,
        notes: 'Following favorite route: ${route.name}',
      );
      if (!mounted) return;
      widget.onNavigate?.call(2);
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openFavoritesSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _FavoriteRoutesSheet(
          routes: _favoriteRoutes,
          onUnfavorite: _unfavoriteRoute,
          onRun: (route) {
            Navigator.of(sheetContext).pop();
            _startRunOnFavorite(route);
          },
          onViewMap: (route) {
            showRoutePreviewSheet(
              sheetContext,
              route: route,
              isFavorited: true,
              isAuthenticated: widget.controller.isAuthenticated,
              onToggleFavorite: () => _unfavoriteRoute(route),
              onRun: () => _startRunOnFavorite(route),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleShareRoute(ManualRouteItem route) async {
    if (!widget.controller.isAuthenticated) {
      setState(() => _message = 'Sign in to share routes with the community.');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final sharedRoute = await widget.controller.shareManualRoute(
        routeId: route.id,
        share: !route.isShared,
      );
      if (!mounted) return;
      setState(() {
        _manualRoutes = _manualRoutes
            .map((existing) => existing.id == route.id ? sharedRoute : existing)
            .toList();
        _message = sharedRoute.isShared ? 'Route shared to community.' : 'Route removed from community.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showHazardPinBottomSheet(HazardMarkerItem marker) {
    final daysAgo = marker.daysSinceReported;
    final dayLabel = daysAgo == null
        ? 'Unknown date'
        : daysAgo == 0
            ? 'today'
            : daysAgo == 1
                ? 'yesterday'
                : '$daysAgo days ago';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _getSeverityColor(marker.severity),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${marker.severity}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        marker.markerType.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${marker.reporterName ?? 'Anonymous'} • $dayLabel',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (marker.note != null) ...[
              const SizedBox(height: 12),
              Text(marker.note!),
            ],
            if (widget.controller.isAuthenticated) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Chip(
                    label: Text('${marker.confirmCount} confirms'),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${marker.dismissCount} disagree'),
                    backgroundColor: Colors.grey.shade200,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => _voteOnPin(marker, true),
                      child: const Text('Confirm'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _isLoading ? null : () => _voteOnPin(marker, false),
                      child: const Text('Disagree'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _voteOnPin(HazardMarkerItem marker, bool confirmed) async {
    if (!widget.controller.isAuthenticated) return;
    
    Navigator.of(context).pop();
    setState(() => _isLoading = true);
    try {
      await widget.controller.validateMarker(markerId: marker.id, confirmed: confirmed);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getSeverityColor(int severity) {
    switch (severity) {
      case 5:
        return const Color(0xFFC62828); // Dark red
      case 4:
        return const Color(0xFFE53935); // Red
      case 3:
        return const Color(0xFFFFA726); // Orange
      case 2:
        return const Color(0xFFFFCA28); // Amber
      default:
        return const Color(0xFF66BB6A); // Green
    }
  }

  List<LatLng> _polylinePoints(List<RoutePoint> points) {
    return points.map((point) => LatLng(point.lat, point.lng)).toList();
  }

  double _totalDistanceKm(List<RoutePoint> points) {
    if (points.length < 2) return 0;
    var totalMeters = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final a = LatLng(points[i].lat, points[i].lng);
      final b = LatLng(points[i + 1].lat, points[i + 1].lng);
      totalMeters += _distanceCalculator(a, b);
    }
    return totalMeters / 1000;
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

    final hazardMarkers = _hazardMarkers
            .map(
              (marker) => Marker(
                point: LatLng(marker.lat, marker.lng),
                width: 44,
                height: 44,
                child: GestureDetector(
                  onTap: () => _showHazardPinBottomSheet(marker),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getSeverityColor(marker.severity),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            )
            .toList();

    final selectedPolyline = _selectedRoute != null ? _polylinePoints(_selectedRoute!.points) : const <LatLng>[];
    final drawnPolyline = _polylinePoints(_drawnPoints);

    final query = _searchQuery.trim().toLowerCase();
    final filteredRoutes = query.isEmpty
        ? _manualRoutes
        : _manualRoutes.where((route) => route.name.toLowerCase().contains(query)).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: SectionTitle('Routes', subtitle: 'Create, save, and reuse custom running routes'),
            ),
            if (widget.controller.isAuthenticated) _FavoriteRoutesButton(
              count: _favoriteRoutes.length,
              onTap: _openFavoritesSheet,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 360,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: RunnaColors.muted.withValues(alpha: 0.15)),
          ),
          child: Stack(
            children: [
              FlutterMap(
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
                      if (_showHazardPins) ...hazardMarkers,
                      ..._drawnPoints.map(
                        (point) => Marker(
                          point: LatLng(point.lat, point.lng),
                          width: 22,
                          height: 22,
                          child: const _PinIcon(color: RunnaColors.primary, icon: Icons.circle),
                        ),
                      ),
                      if (_currentLocation != null)
                        Marker(
                          point: _currentLocation!,
                          width: 28,
                          height: 28,
                          child: const _PinIcon(color: RunnaColors.accent, icon: Icons.navigation),
                        ),
                    ],
                  ),
                ],
              ),
              if (_selectedRoute != null)
                Positioned(
                  left: 10,
                  top: 10,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 170),
                    child: Material(
                      color: RunnaColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.route, size: 14, color: RunnaColors.primaryDark),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _selectedRoute!.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Tooltip(
                              message: 'Clear route from map',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => setState(() => _selectedRoute = null),
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(Icons.refresh, size: 15, color: RunnaColors.primaryDark),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 12,
                top: 12,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'routes_toggle_hazards',
                      backgroundColor: RunnaColors.surface,
                      foregroundColor: RunnaColors.primaryDark,
                      onPressed: () => setState(() => _showHazardPins = !_showHazardPins),
                      tooltip: _showHazardPins ? 'Hide hazard pins' : 'Show hazard pins',
                      child: Icon(
                        _showHazardPins ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton.small(
                      heroTag: 'routes_locate_me',
                      backgroundColor: RunnaColors.surface,
                      foregroundColor: RunnaColors.primaryDark,
                      onPressed: _isLocating ? null : _goToMyLocation,
                      child: _isLocating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                    ),
                  ],
                ),
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
              const Text(
                'Create route',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap points on the map to build your path',
                style: TextStyle(fontSize: 12, color: RunnaColors.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _routeNameController,
                enabled: widget.controller.isAuthenticated,
                decoration: const InputDecoration(
                  labelText: 'Route name',
                  hintText: 'Name your route',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _RouteStat(
                      icon: Icons.location_on_outlined,
                      label: 'Points',
                      value: '${_drawnPoints.length}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RouteStat(
                      icon: Icons.straighten,
                      label: 'Distance',
                      value: '${_totalDistanceKm(_drawnPoints).toStringAsFixed(2)} km',
                    ),
                  ),
                ],
              ),
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
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionTitle('Saved routes (${_manualRoutes.length})'),
        const SizedBox(height: 12),
        if (widget.controller.isAuthenticated && _manualRoutes.isNotEmpty) ...[
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search saved routes',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      }),
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!widget.controller.isAuthenticated)
          const RunnaCard(child: Text('Sign in to create and save your own routes.'))
        else if (_manualRoutes.isEmpty)
          const RunnaCard(child: Text('No saved routes yet. Tap the map to start creating one.'))
        else if (filteredRoutes.isEmpty)
          const RunnaCard(child: Text('No routes match your search.'))
        else
          ...filteredRoutes.map(
            (route) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RunnaCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(route.name),
                  subtitle: Text('${route.distanceKm.toStringAsFixed(2)} km • ${route.points.length} points'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          route.isShared ? Icons.check_circle : Icons.share_outlined,
                          color: route.isShared ? RunnaColors.primary : null,
                        ),
                        tooltip: route.isShared ? 'Shared to community' : 'Share to community',
                        onPressed: _isLoading ? null : () => _toggleShareRoute(route),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _isLoading ? null : () => _deleteRoute(route),
                      ),
                    ],
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

class _FavoriteRoutesButton extends StatelessWidget {
  const _FavoriteRoutesButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: RunnaColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: RunnaColors.muted.withValues(alpha: 0.15)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.favorite, color: RunnaColors.danger, size: 20),
            if (count > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: RunnaColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 16),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteRoutesSheet extends StatefulWidget {
  const _FavoriteRoutesSheet({
    required this.routes,
    required this.onUnfavorite,
    required this.onRun,
    required this.onViewMap,
  });

  final List<ManualRouteItem> routes;
  final ValueChanged<ManualRouteItem> onUnfavorite;
  final ValueChanged<ManualRouteItem> onRun;
  final ValueChanged<ManualRouteItem> onViewMap;

  @override
  State<_FavoriteRoutesSheet> createState() => _FavoriteRoutesSheetState();
}

class _FavoriteRoutesSheetState extends State<_FavoriteRoutesSheet> {
  late final List<ManualRouteItem> _routes = List.of(widget.routes);

  void _handleUnfavorite(ManualRouteItem route) {
    setState(() => _routes.removeWhere((item) => item.id == route.id));
    widget.onUnfavorite(route);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: RunnaColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: RunnaColors.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Favorite routes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text('${_routes.length}', style: const TextStyle(color: RunnaColors.muted)),
                  ],
                ),
              ),
              Expanded(
                child: _routes.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'No favorites yet. Tap the heart on a community route from Home to save it here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: RunnaColors.muted),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: _routes.length,
                        itemBuilder: (context, index) {
                          final route = _routes[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: RouteResultCard(
                              route: route,
                              isFavorited: true,
                              onToggleFavorite: () => _handleUnfavorite(route),
                              onViewMap: () => widget.onViewMap(route),
                              onRun: () => widget.onRun(route),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RouteStat extends StatelessWidget {
  const _RouteStat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: RunnaColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: RunnaColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: RunnaColors.muted),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
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