import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/location_service.dart';
import '../../core/models.dart';
import '../auth/auth_controller.dart';

// ─────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────

String _formatAiStatusMessage(String? aiInsight) {
  if (aiInsight == null || aiInsight.isEmpty) {
    return 'No AI data available for this run.';
  }
  if (aiInsight.startsWith('[AI unavailable]')) {
    return 'Gemini ยังไม่พร้อม: ${aiInsight.replaceFirst('[AI unavailable] ', '')}';
  }
  if (aiInsight.startsWith('[Unexpected AI error]')) {
    return 'เกิดข้อผิดพลาดจาก AI: ${aiInsight.replaceFirst('[Unexpected AI error] ', '')}';
  }
  return aiInsight;
}

bool _hasRealAiInsight(String? aiInsight) {
  return aiInsight != null &&
      aiInsight.isNotEmpty &&
      !aiInsight.startsWith('[AI unavailable]') &&
      !aiInsight.startsWith('[Unexpected AI error]');
}

String _formatRunDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

String _formatRunPace(double? paceMinPerKm) {
  if (paceMinPerKm == null) return '--';
  return '${paceMinPerKm.toStringAsFixed(2)} min/km';
}

// ─────────────────────────────────────────────────────────
// RunsScreen
// ─────────────────────────────────────────────────────────

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

  // FIX: track whether map has been initialised so we never call
  // _mapController.move() before FlutterMap is ready.
  bool _mapReady = false;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _runningTimer;

  List<RunItem> _runs = const [];
  List<ManualRouteItem> _manualRoutes = const [];
  List<RoutePoint> _trackedPoints = const [];
  List<HazardMarkerItem> _hazardMarkers = const [];
  ManualRouteItem? _selectedRoute;
  RunItem? _activeRun;
  RunItem? _justFinishedRun;
  Position? _currentPosition;
  double? _headingDeg;
  String? _message;
  bool _isLoading = false;
  bool _isTracking = false;

  int _secondsElapsed = 0;
  double _trackedDistanceKm = 0.0;

  // ── safe map move ─────────────────────────
  // Call this instead of _mapController.move() everywhere so we never
  // crash when the map widget has not finished initialising yet.
  void _safeMapMove(LatLng center, double zoom) {
    if (!_mapReady || !mounted) return;
    try {
      _mapController.move(center, zoom);
    } catch (_) {
      // map not ready yet — ignore
    }
  }

  // ── helpers ──────────────────────────────

  int _estimateSteps(double distanceKm) => (distanceKm * 1000 / 0.75).round();

  String _headingLabel(double? degrees) {
    if (degrees == null) return '—';
    const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) % 360 / 45).floor();
    return '${labels[index]} (${degrees.round()}°)';
  }

  double? _resolveHeading(Position position) {
    if (position.heading >= 0) return position.heading;
    if (_trackedPoints.isEmpty) return null;
    final previous = _trackedPoints.last;
    return Geolocator.bearingBetween(
      previous.lat,
      previous.lng,
      position.latitude,
      position.longitude,
    );
  }

  String _formatDuration(int totalSeconds) => _formatRunDuration(totalSeconds);
  String _formatPace(double? paceMinPerKm) => _formatRunPace(paceMinPerKm);

  void _syncElapsedFromStart(DateTime? startedAt) {
    if (startedAt == null) return;
    final elapsed =
        DateTime.now().toUtc().difference(startedAt.toUtc()).inSeconds;
    if (elapsed > _secondsElapsed) _secondsElapsed = elapsed;
  }

  bool _shouldRecordPoint(RoutePoint point) {
    if (_trackedPoints.isEmpty) return true;
    final last = _trackedPoints.last;
    final meters = _distance(
      LatLng(last.lat, last.lng),
      LatLng(point.lat, point.lng),
    );
    return meters >= 2;
  }

  double _calculateDistanceKm(List<RoutePoint> points) {
    var meters = 0.0;
    for (var i = 1; i < points.length; i++) {
      meters += _distance(
        LatLng(points[i - 1].lat, points[i - 1].lng),
        LatLng(points[i].lat, points[i].lng),
      );
    }
    return meters / 1000;
  }

  double? get _offRouteMeters {
    final position = _currentPosition;
    final route = _selectedRoute;
    if (position == null || route == null || route.points.isEmpty) return null;
    final here = LatLng(position.latitude, position.longitude);
    return route.points
        .map((p) => _distance(here, LatLng(p.lat, p.lng)))
        .reduce((a, b) => a < b ? a : b);
  }

  double get _progress {
    final routeDistance = _selectedRoute?.distanceKm ?? 0;
    if (routeDistance <= 0) return 0;
    return (_trackedDistanceKm / routeDistance).clamp(0.0, 1.0);
  }

  // ── lifecycle ────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadRuns();
    _loadHazardMarkers();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _runningTimer?.cancel();
    super.dispose();
  }

  // ── data loading ─────────────────────────

  Future<void> _loadHazardMarkers() async {
    try {
      final markers = await widget.controller.getMarkers();
      if (!mounted) return;
      setState(() => _hazardMarkers = markers);
    } catch (_) {
      // Non-fatal
    }
  }

  Future<void> _loadRuns() async {
    if (!widget.controller.isAuthenticated) {
      setState(() => _message = 'Please sign in before tracking a run.');
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

      final wasTracking = _isTracking;
      final activeRun = runs
          .cast<RunItem?>()
          .firstWhere((r) => r?.status == 'active', orElse: () => null);

      setState(() {
        _runs = runs;
        _manualRoutes = manualRoutes;
        _activeRun = activeRun;
        _selectedRoute = _pickSelectedRoute(manualRoutes, activeRun);
      });

      if (activeRun != null && !wasTracking) {
        // FIX: only restore points — do NOT auto-start the location stream.
        // The user must press "Resume GPS" intentionally. This prevents
        // double-subscription and the "stats stuck at 0" bug.
        await _resumeActiveRun(activeRun);
      } else if (activeRun == null) {
        _moveToRoute();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resumeActiveRun(RunItem activeRun) async {
    try {
      final points = await widget.controller.getRunPoints(activeRun.id);
      if (!mounted) return;
      final routePoints =
          points.map((p) => RoutePoint(lat: p.lat, lng: p.lng)).toList();
      setState(() {
        _trackedPoints = routePoints;
        _trackedDistanceKm = _calculateDistanceKm(routePoints);
        _syncElapsedFromStart(activeRun.startedAt);
        // FIX: show a clear message so the user knows to press Resume GPS
        _message = 'Active run found — tap Resume GPS to continue tracking.';
      });
      if (routePoints.isNotEmpty) {
        final last = routePoints.last;
        // FIX: defer map move until after the current frame so FlutterMap
        // is guaranteed to be initialised.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _safeMapMove(LatLng(last.lat, last.lng), 16);
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _message = 'Active run found — tap Resume GPS to continue.');
    }
  }

  ManualRouteItem? _pickSelectedRoute(
      List<ManualRouteItem> routes, RunItem? activeRun) {
    if (routes.isEmpty) return null;
    if (activeRun?.manualRouteId != null) {
      return routes
          .cast<ManualRouteItem?>()
          .firstWhere((r) => r?.id == activeRun!.manualRouteId,
              orElse: () => routes.first);
    }
    return _selectedRoute ?? routes.first;
  }

  // ── location stream ───────────────────────

  Future<void> _startLocationStream() async {
    // FIX: cancel any existing subscription before creating a new one so we
    // never have two streams running simultaneously (which caused the timer
    // and distance counter to fight each other and appear stuck at 0).
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _runningTimer?.cancel();
    _runningTimer = null;

    if (_activeRun?.startedAt != null) {
      _syncElapsedFromStart(_activeRun!.startedAt);
    }

    // FIX: set _isTracking = true BEFORE subscribing so the timer callback
    // always sees the correct flag from the very first tick.
    setState(() {
      _isTracking = true;
      _message = null;
    });

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

    _startTimer();
  }

  void _startTimer() {
    _runningTimer?.cancel();
    _runningTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isTracking) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  Future<void> _handlePosition(Position position) async {
    if (!mounted) return;

    final activeRun = _activeRun;
    final point = RoutePoint(lat: position.latitude, lng: position.longitude);
    final heading = _resolveHeading(position);
    final shouldRecord = _shouldRecordPoint(point);

    setState(() {
      _currentPosition = position;
      _headingDeg = heading;
      if (shouldRecord) {
        final updated = [..._trackedPoints, point];
        _trackedPoints = updated;
        _trackedDistanceKm = _calculateDistanceKm(updated);
      }
    });

    // FIX: guard map move — map may not be ready on the very first position
    // event (especially on web where the first fix arrives quickly).
    if (_isTracking) {
      _safeMapMove(
        LatLng(position.latitude, position.longitude),
        _mapReady ? _mapController.camera.zoom : 16,
      );
    }

    if (activeRun == null || !shouldRecord) return;

    try {
      await widget.controller.addRunPoints(
        runId: activeRun.id,
        points: [
          RunPointUpload(
            lat: position.latitude,
            lng: position.longitude,
            accuracyM: position.accuracy,
            speedMps: position.speed >= 0 ? position.speed : null,
            headingDeg: heading,
            recordedAt: position.timestamp,
          ),
        ],
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Tracking locally, upload failed: $error');
    }
  }

  // ── run actions ───────────────────────────

  Future<void> _locateMe() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() => _currentPosition = position);
      _safeMapMove(LatLng(position.latitude, position.longitude), 16);
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startRun() async {
    final route = _selectedRoute;
    if (route == null) {
      setState(() => _message = 'Create and select a manual route first.');
      return;
    }

    // FIX: cancel streams before resetting state so the old timer can never
    // fire after _secondsElapsed is reset to 0.
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _runningTimer?.cancel();
    _runningTimer = null;

    setState(() {
      _isLoading = true;
      _message = null;
      _trackedPoints = const [];
      _trackedDistanceKm = 0.0;
      _justFinishedRun = null;
      _secondsElapsed = 0;
      _headingDeg = null;
      _isTracking = false;
    });

    try {
      final run = await widget.controller.startRun(
        manualRouteId: route.id,
        notes: 'Following manual route: ${route.name}',
      );
      if (!mounted) return;
      setState(() => _activeRun = run);
      // Start the stream FIRST, then reload the run list in the background.
      await _startLocationStream();
      // FIX: reload silently without awaiting — prevents _loadRuns from
      // calling _resumeActiveRun (which would set wasTracking=false and
      // reset the stream).
      _loadRuns();
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      // Stop tracking before API call so no more points are uploaded.
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      _runningTimer?.cancel();
      _runningTimer = null;

      final estimatedSteps = _estimateSteps(_trackedDistanceKm);
      final finalDuration = _secondsElapsed > 0 ? _secondsElapsed : 1;

      final finished = await widget.controller.finishRun(
        runId: activeRun.id,
        distanceKm: _trackedDistanceKm,
        durationSeconds: finalDuration,
        stepCount: estimatedSteps,
      );

      if (!mounted) return;

      setState(() {
        _activeRun = null;
        _isTracking = false;
        _headingDeg = null;
        _justFinishedRun = finished;
      });
      _loadRuns();
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _moveToRoute() {
    final route = _selectedRoute;
    if (route == null || route.points.isEmpty) return;
    // FIX: defer so FlutterMap is ready before we move.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _safeMapMove(
          LatLng(route.points.first.lat, route.points.first.lng), 15);
    });
  }

  void _openHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _RunHistorySheet(
          runs: _runs,
          scrollController: scrollController,
          onRefresh: _loadRuns,
          isLoading: _isLoading,
        ),
      ),
    );
  }

  void _showHazardDetails(HazardMarkerItem marker) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFC45C4A)),
              const SizedBox(width: 8),
              Text(
                marker.categoryLabel,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
                'Severity: ${marker.severity} • Confirms: ${marker.confirmCount}'),
            if (marker.note != null && marker.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(marker.note!),
            ],
          ],
        ),
      ),
    );
  }

  // ── build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final route = _selectedRoute;
    final routePolyline =
        route?.points.map((p) => LatLng(p.lat, p.lng)).toList() ??
            const <LatLng>[];
    final trackedPolyline =
        _trackedPoints.map((p) => LatLng(p.lat, p.lng)).toList();
    final currentPosition = _currentPosition;
    final offRouteMeters = _offRouteMeters;
    final justFinished = _justFinishedRun;

    final hazardMapMarkers = _hazardMarkers
        .map((m) => Marker(
              point: LatLng(m.lat, m.lng),
              width: 36,
              height: 36,
              child: GestureDetector(
                onTap: () => _showHazardDetails(m),
                child: const _HazardPin(),
              ),
            ))
        .toList();

    // ── Summary screen ───────────────────────────────────────────────
    if (justFinished != null) {
      final hasAi = _hasRealAiInsight(justFinished.aiInsight);
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => setState(() {
                    _justFinishedRun = null;
                    _trackedPoints = const [];
                    _trackedDistanceKm = 0.0;
                  }),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Summary Result',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Run history',
                  onPressed: _openHistorySheet,
                  icon: const Icon(Icons.history),
                ),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                          child: _MetricTile(
                              label: 'Distance',
                              value:
                                  '${justFinished.distanceKm.toStringAsFixed(2)} km')),
                      Expanded(
                          child: _MetricTile(
                              label: 'Steps',
                              value: '${justFinished.stepCount} steps')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                          child: _MetricTile(
                              label: 'Duration',
                              value: _formatDuration(
                                  justFinished.durationSeconds))),
                      Expanded(
                          child: _MetricTile(
                              label: 'Pace',
                              value:
                                  _formatPace(justFinished.avgPaceMinPerKm))),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: const Color(0xFFA5D6A7), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.auto_awesome, color: Color(0xFF2E7D32)),
                      SizedBox(width: 8),
                      Text('AI Insight Summary',
                          style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ]),
                    const Divider(color: Color(0xFFA5D6A7), height: 24),
                    if (hasAi) ...[
                      _ReadableAiSection(
                          title: 'Insight', body: justFinished.aiInsight!),
                      if (justFinished.aiReasoning?.isNotEmpty == true) ...[
                        const SizedBox(height: 14),
                        _ReadableAiSection(
                            title: 'Reasoning',
                            body: justFinished.aiReasoning!),
                      ],
                      if (justFinished.aiRecommendations?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 14),
                        _ReadableAiSection(
                            title: 'Recommendations',
                            body: justFinished.aiRecommendations!),
                      ],
                    ] else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _formatAiStatusMessage(justFinished.aiInsight),
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Main run-tracking screen ─────────────────────────────────────
    final canFinishRun = !_isLoading && _activeRun != null;
    final canStartRun = !_isLoading && _activeRun == null && route != null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Runs', style: Theme.of(context).textTheme.headlineSmall),
            IconButton.filledTonal(
              tooltip: 'Run history',
              onPressed: _openHistorySheet,
              icon: const Icon(Icons.history),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // ── Map ─────────────────────────────────────────────────────
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
              initialCenter: routePolyline.isNotEmpty
                  ? routePolyline.first
                  : const LatLng(18.8059, 98.9523),
              initialZoom: 15,
              // FIX: set _mapReady = true once FlutterMap fires its onMapReady
              // callback so _safeMapMove knows it is safe to call move().
              onMapReady: () {
                if (mounted) setState(() => _mapReady = true);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'runna_mobile',
              ),
              if (routePolyline.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(
                    points: routePolyline,
                    strokeWidth: 6,
                    color: const Color(0xFF23402B),
                  ),
                ]),
              if (trackedPolyline.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(
                    points: trackedPolyline,
                    strokeWidth: 6,
                    color: const Color(0xFF2A9D8F),
                  ),
                  Polyline(
                    points: trackedPolyline,
                    strokeWidth: 2,
                    color: const Color(0xFFB2DFDB),
                    borderStrokeWidth: 0,
                  ),
                ]),
              if (_trackedPoints.isNotEmpty)
                CircleLayer(
                  circles: _trackedPoints
                      .map((p) => CircleMarker(
                            point: LatLng(p.lat, p.lng),
                            radius: 4,
                            useRadiusInMeter: false,
                            color: const Color(0x662A9D8F),
                            borderColor: const Color(0xFF2A9D8F),
                            borderStrokeWidth: 1,
                          ))
                      .toList(),
                ),
              if (currentPosition != null && currentPosition.accuracy > 0)
                CircleLayer(circles: [
                  CircleMarker(
                    point: LatLng(
                        currentPosition.latitude, currentPosition.longitude),
                    radius: currentPosition.accuracy,
                    useRadiusInMeter: true,
                    color: const Color(0x222A9D8F),
                    borderColor: const Color(0x552A9D8F),
                    borderStrokeWidth: 1,
                  ),
                ]),
              MarkerLayer(markers: [
                ...hazardMapMarkers,
                if (currentPosition != null)
                  Marker(
                    point: LatLng(
                        currentPosition.latitude, currentPosition.longitude),
                    width: 48,
                    height: 48,
                    child: _DirectionalLocationPin(headingDeg: _headingDeg),
                  ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_message!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ),
        // ── Control card ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_activeRun == null
                  ? 'No active run'
                  : 'Active run #${_activeRun!.id}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: route?.id,
                decoration:
                    const InputDecoration(labelText: 'Manual route'),
                items: _manualRoutes
                    .map((r) => DropdownMenuItem<int>(
                          value: r.id,
                          child: Text(
                              '${r.name} (${r.distanceKm.toStringAsFixed(2)} km)'),
                        ))
                    .toList(),
                onChanged: _activeRun != null
                    ? null
                    : (routeId) {
                        setState(() {
                          _selectedRoute = _manualRoutes
                              .firstWhere((r) => r.id == routeId);
                        });
                        _moveToRoute();
                      },
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                'Progress: ${(_progress * 100).toStringAsFixed(0)}%'
                ' • Tracked: ${_trackedDistanceKm.toStringAsFixed(2)} km'
                ' • ~${_estimateSteps(_trackedDistanceKm)} steps'
                '${_activeRun != null ? ' • Time: ${_formatDuration(_secondsElapsed)}' : ''}',
              ),
              if (_isTracking && _headingDeg != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Transform.rotate(
                    angle: _headingDeg! * math.pi / 180,
                    child: const Icon(Icons.navigation,
                        size: 16, color: Color(0xFF2A9D8F)),
                  ),
                  const SizedBox(width: 6),
                  Text('Heading: ${_headingLabel(_headingDeg)}'),
                ]),
              ],
              if (offRouteMeters != null) ...[
                const SizedBox(height: 6),
                Text(
                  offRouteMeters > 50
                      ? 'Off route by about ${offRouteMeters.toStringAsFixed(0)} m'
                      : 'On route • nearest point ${offRouteMeters.toStringAsFixed(0)} m away',
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
                    onPressed: canStartRun ? _startRun : null,
                    child: const Text('Start route run'),
                  ),
                  FilledButton.tonal(
                    onPressed: canFinishRun ? _finishRun : null,
                    child: const Text('Finish run'),
                  ),
                  OutlinedButton(
                    onPressed: _isLoading ||
                            _activeRun == null ||
                            _isTracking
                        ? null
                        : _startLocationStream,
                    child: const Text('Resume GPS'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _openHistorySheet,
          icon: const Icon(Icons.history),
          label: Text('View all runs (${_runs.length})'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────

class _HazardPin extends StatelessWidget {
  const _HazardPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFC45C4A),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: const Icon(Icons.warning_amber_rounded,
          color: Colors.white, size: 18),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ReadableAiSection extends StatelessWidget {
  const _ReadableAiSection({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Color(0xFF1B5E20),
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        const SizedBox(height: 4),
        Text(body,
            style: const TextStyle(
                color: Colors.black87, height: 1.4, fontSize: 13)),
      ],
    );
  }
}

class _DirectionalLocationPin extends StatelessWidget {
  const _DirectionalLocationPin({required this.headingDeg});
  final double? headingDeg;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Color(0x332A9D8F),
            shape: BoxShape.circle,
          ),
        ),
        Transform.rotate(
          angle: (headingDeg ?? 0) * math.pi / 180,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF2A9D8F),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 8,
                    offset: Offset(0, 2))
              ],
            ),
            child: const Icon(Icons.navigation, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Run history bottom sheet
// ─────────────────────────────────────────────────────────

class _RunHistorySheet extends StatefulWidget {
  const _RunHistorySheet({
    required this.runs,
    required this.scrollController,
    required this.onRefresh,
    required this.isLoading,
  });

  final List<RunItem> runs;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final bool isLoading;

  @override
  State<_RunHistorySheet> createState() => _RunHistorySheetState();
}

class _RunHistorySheetState extends State<_RunHistorySheet> {
  int? _expandedRunId;

  @override
  Widget build(BuildContext context) {
    final finishedRuns =
        widget.runs.where((r) => r.status == 'finished').toList();

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Run history',
                  style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                onPressed: widget.isLoading ? null : widget.onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: finishedRuns.isEmpty
              ? const Center(child: Text('No finished runs yet.'))
              : ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: finishedRuns.length,
                  itemBuilder: (context, index) {
                    final run = finishedRuns[index];
                    final isExpanded = _expandedRunId == run.id;
                    final hasAi = _hasRealAiInsight(run.aiInsight);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            title: Text('Run #${run.id}'),
                            subtitle: Text(
                              '${run.distanceKm.toStringAsFixed(2)} km'
                              ' • ${_formatRunDuration(run.durationSeconds)}'
                              ' • ${run.stepCount} steps'
                              '${run.avgPaceMinPerKm != null ? ' • ${_formatRunPace(run.avgPaceMinPerKm)}' : ''}',
                            ),
                            trailing: Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: const Color(0xFF2A9D8F),
                            ),
                            onTap: () => setState(() {
                              _expandedRunId = isExpanded ? null : run.id;
                            }),
                          ),
                          if (isExpanded)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        Expanded(
                                            child: _MetricTile(
                                                label: 'Distance',
                                                value:
                                                    '${run.distanceKm.toStringAsFixed(2)} km')),
                                        Expanded(
                                            child: _MetricTile(
                                                label: 'Steps',
                                                value: '${run.stepCount}')),
                                        Expanded(
                                            child: _MetricTile(
                                                label: 'Duration',
                                                value: _formatRunDuration(
                                                    run.durationSeconds))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5E9),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFA5D6A7)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (hasAi) ...[
                                          _ReadableAiSection(
                                              title: 'Insight',
                                              body: run.aiInsight!),
                                          if (run.aiReasoning?.isNotEmpty ==
                                              true) ...[
                                            const SizedBox(height: 8),
                                            _ReadableAiSection(
                                                title: 'Reasoning',
                                                body: run.aiReasoning!),
                                          ],
                                          if (run.aiRecommendations
                                                  ?.isNotEmpty ==
                                              true) ...[
                                            const SizedBox(height: 8),
                                            _ReadableAiSection(
                                                title: 'Recommendations',
                                                body:
                                                    run.aiRecommendations!),
                                          ],
                                        ] else
                                          Text(
                                            _formatAiStatusMessage(
                                                run.aiInsight),
                                            style: const TextStyle(
                                              color: Color(0xFF1B5E20),
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}