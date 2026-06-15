import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/location_service.dart';
import '../../core/models.dart';
import '../auth/auth_controller.dart';

class RunsScreen extends StatefulWidget {
  const RunsScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<RunsScreen> createState() => _RunsScreenState();
}

class _RunsScreenState extends State<RunsScreen> {
  final _mapController = MapController();
  final _locationService = LocationService();
  final _distance = const Distance();

  StreamSubscription<Position>? _positionSubscription;
  List<RunItem> _runs = const [];
  List<ManualRouteItem> _manualRoutes = const [];
  List<RoutePoint> _trackedPoints = const [];
  ManualRouteItem? _selectedRoute;
  RunItem? _activeRun;
  Position? _currentPosition;
  String? _message;
  bool _isLoading = false;
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _loadRuns();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRuns() async {
    if (!widget.controller.isAuthenticated) {
      setState(() {
        _message = 'Please sign in before tracking a run.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final results = await Future.wait([
        widget.controller.getRuns(),
        widget.controller.getManualRoutes(),
      ]);
      final runs = results[0] as List<RunItem>;
      final manualRoutes = results[1] as List<ManualRouteItem>;
      if (!mounted) return;
      final activeRun = runs.where((run) => run.status == 'active').cast<RunItem?>().firstWhere(
            (run) => run != null,
            orElse: () => null,
          );
      setState(() {
        _runs = runs;
        _manualRoutes = manualRoutes;
        _activeRun = activeRun;
        _selectedRoute = _pickSelectedRoute(manualRoutes, activeRun);
      });
      _moveToRoute();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  ManualRouteItem? _pickSelectedRoute(List<ManualRouteItem> routes, RunItem? activeRun) {
    if (routes.isEmpty) return null;
    if (activeRun?.manualRouteId != null) {
      return routes.where((route) => route.id == activeRun!.manualRouteId).cast<ManualRouteItem?>().firstWhere(
            (route) => route != null,
            orElse: () => routes.first,
          );
    }
    return _selectedRoute ?? routes.first;
  }

  Future<void> _locateMe() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
      _mapController.move(LatLng(position.latitude, position.longitude), 16);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startRun() async {
    final route = _selectedRoute;
    if (route == null) {
      setState(() {
        _message = 'Create and select a manual route first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
      _trackedPoints = const [];
    });
    try {
      final run = await widget.controller.startRun(
        manualRouteId: route.id,
        notes: 'Following manual route: ${route.name}',
      );
      if (!mounted) return;
      setState(() {
        _activeRun = run;
      });
      await _startLocationStream();
      await _loadRuns();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startLocationStream() async {
    await _positionSubscription?.cancel();
    _positionSubscription = _locationService.positionStream().listen(
      _handlePosition,
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _message = '$error';
          _isTracking = false;
        });
      },
    );
    setState(() {
      _isTracking = true;
    });
  }

  Future<void> _handlePosition(Position position) async {
    final activeRun = _activeRun;
    final point = RoutePoint(lat: position.latitude, lng: position.longitude);
    if (!mounted) return;
    setState(() {
      _currentPosition = position;
      _trackedPoints = [..._trackedPoints, point];
    });
    _mapController.move(LatLng(position.latitude, position.longitude), 16);

    if (activeRun == null) return;
    try {
      await widget.controller.addRunPoints(
        runId: activeRun.id,
        points: [
          RunPointUpload(
            lat: position.latitude,
            lng: position.longitude,
            accuracyM: position.accuracy,
            speedMps: position.speed >= 0 ? position.speed : null,
            headingDeg: position.heading >= 0 ? position.heading : null,
            recordedAt: position.timestamp,
          ),
        ],
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = 'Tracking locally, upload failed: $error';
      });
    }
  }

  Future<void> _finishRun() async {
    final activeRun = _activeRun;
    if (activeRun == null) return;
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      await widget.controller.finishRun(runId: activeRun.id);
      if (!mounted) return;
      setState(() {
        _activeRun = null;
        _isTracking = false;
      });
      await _loadRuns();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _moveToRoute() {
    final route = _selectedRoute;
    if (route == null || route.points.isEmpty) return;
    final first = route.points.first;
    _mapController.move(LatLng(first.lat, first.lng), 15);
  }

  double get _trackedDistanceKm {
    var meters = 0.0;
    for (var index = 1; index < _trackedPoints.length; index += 1) {
      final previous = _trackedPoints[index - 1];
      final current = _trackedPoints[index];
      meters += _distance(
        LatLng(previous.lat, previous.lng),
        LatLng(current.lat, current.lng),
      );
    }
    return meters / 1000;
  }

  double get _progress {
    final routeDistance = _selectedRoute?.distanceKm ?? 0;
    if (routeDistance <= 0) return 0;
    return (_trackedDistanceKm / routeDistance).clamp(0, 1);
  }

  double? get _offRouteMeters {
    final position = _currentPosition;
    final route = _selectedRoute;
    if (position == null || route == null || route.points.isEmpty) return null;
    final here = LatLng(position.latitude, position.longitude);
    return route.points
        .map((point) => _distance(here, LatLng(point.lat, point.lng)))
        .reduce((value, element) => value < element ? value : element);
  }

  @override
  Widget build(BuildContext context) {
    final route = _selectedRoute;
    final routePolyline = route?.points.map((point) => LatLng(point.lat, point.lng)).toList() ?? const <LatLng>[];
    final trackedPolyline = _trackedPoints.map((point) => LatLng(point.lat, point.lng)).toList();
    final currentPosition = _currentPosition;
    final offRouteMeters = _offRouteMeters;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Runs', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Container(
          height: 380,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: routePolyline.isNotEmpty ? routePolyline.first : const LatLng(18.8059, 98.9523),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'runna_mobile',
              ),
              if (routePolyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePolyline,
                      strokeWidth: 6,
                      color: const Color(0xFF23402B),
                    ),
                  ],
                ),
              if (trackedPolyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: trackedPolyline,
                      strokeWidth: 5,
                      color: const Color(0xFF2A9D8F),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (currentPosition != null)
                    Marker(
                      point: LatLng(currentPosition.latitude, currentPosition.longitude),
                      width: 42,
                      height: 42,
                      child: const _CurrentLocationPin(),
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
            child: Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_activeRun == null ? 'No active run' : 'Active run #${_activeRun!.id}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: route?.id,
                decoration: const InputDecoration(labelText: 'Manual route'),
                items: _manualRoutes
                    .map(
                      (item) => DropdownMenuItem<int>(
                        value: item.id,
                        child: Text('${item.name} (${item.distanceKm.toStringAsFixed(2)} km)'),
                      ),
                    )
                    .toList(),
                onChanged: _activeRun != null
                    ? null
                    : (routeId) {
                        setState(() {
                          _selectedRoute = _manualRoutes.firstWhere((item) => item.id == routeId);
                        });
                        _moveToRoute();
                      },
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                'Progress: ${(_progress * 100).toStringAsFixed(0)}% • Tracked: ${_trackedDistanceKm.toStringAsFixed(2)} km',
              ),
              if (offRouteMeters != null) ...[
                const SizedBox(height: 6),
                Text(
                  offRouteMeters > 50
                      ? 'Off route by about ${offRouteMeters.toStringAsFixed(0)} m'
                      : 'On route • nearest route point ${offRouteMeters.toStringAsFixed(0)} m away',
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.tonal(
                    onPressed: _isLoading ? null : _locateMe,
                    child: const Text('Locate me'),
                  ),
                  FilledButton(
                    onPressed: _isLoading || _activeRun != null ? null : _startRun,
                    child: const Text('Start route run'),
                  ),
                  FilledButton.tonal(
                    onPressed: _isLoading || _activeRun == null ? null : _finishRun,
                    child: const Text('Finish run'),
                  ),
                  OutlinedButton(
                    onPressed: _isLoading || _activeRun == null || _isTracking ? null : _startLocationStream,
                    child: const Text('Resume GPS'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.tonal(
          onPressed: _isLoading ? null : _loadRuns,
          child: const Text('Refresh runs'),
        ),
        const SizedBox(height: 16),
        if (_runs.isEmpty)
          const Text('No runs yet.')
        else
          ..._runs.map(
            (run) => Card(
              child: ListTile(
                title: Text('Run #${run.id}'),
                subtitle: Text(
                  'Status: ${run.status}\nDistance: ${run.distanceKm.toStringAsFixed(2)} km\nDuration: ${run.durationSeconds}s',
                ),
                isThreeLine: true,
              ),
            ),
          ),
      ],
    );
  }
}

class _CurrentLocationPin extends StatelessWidget {
  const _CurrentLocationPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A9D8F),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.my_location, color: Colors.white, size: 18),
    );
  }
}
