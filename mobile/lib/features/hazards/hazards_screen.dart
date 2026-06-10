import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';

class HazardsScreen extends StatefulWidget {
  const HazardsScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<HazardsScreen> createState() => _HazardsScreenState();
}

class _HazardsScreenState extends State<HazardsScreen> {
  final _mapController = MapController();
  final _noteController = TextEditingController();

  List<HazardMarkerItem> _markers = const [];
  LatLng? _selectedPoint;
  String _category = 'construction';
  int _severity = 3;
  String? _message;
  bool _isLoading = false;

  static const _categories = [
    'construction',
    'road_closure',
    'animals',
    'obstacle',
    'accident',
    'dark_area',
    'unsafe_crossing',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final markers = await widget.controller.getMarkers();
      if (!mounted) return;
      setState(() => _markers = markers);
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleMapTap(TapPosition _, LatLng point) {
    setState(() => _selectedPoint = point);
  }

  Future<void> _createPin() async {
    final point = _selectedPoint;
    if (point == null) {
      setState(() => _message = 'Tap the map to choose a pin location.');
      return;
    }
    if (!widget.controller.isAuthenticated) {
      setState(() => _message = 'Sign in to report hazards.');
      return;
    }
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      await widget.controller.createMarker(
        markerType: _category,
        severity: _severity,
        lat: point.latitude,
        lng: point.longitude,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
      setState(() {
        _selectedPoint = null;
        _noteController.clear();
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _validatePin(HazardMarkerItem marker, bool confirmed) async {
    if (!widget.controller.isAuthenticated) {
      setState(() => _message = 'Sign in to validate hazard pins.');
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    final mapMarkers = _markers
        .map(
          (marker) => Marker(
            point: LatLng(marker.lat, marker.lng),
            width: 36,
            height: 36,
            child: CircleAvatar(
              backgroundColor: RunnaColors.danger,
              child: Text('${marker.severity}', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
        )
        .toList();

    if (_selectedPoint != null) {
      mapMarkers.add(
        Marker(
          point: _selectedPoint!,
          width: 28,
          height: 28,
          child: const CircleAvatar(
            backgroundColor: RunnaColors.primary,
            child: Icon(Icons.add, color: Colors.white, size: 16),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle(
          'Hazard pins',
          subtitle: 'Report, view, and validate real-world route conditions',
        ),
        const SizedBox(height: 16),
        Container(
          height: 280,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: RunnaColors.muted.withValues(alpha: 0.15)),
          ),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(18.8059, 98.9523),
              initialZoom: 14,
              onTap: _handleMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'runna_mobile',
              ),
              MarkerLayer(markers: mapMarkers),
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
              const Text('Report a hazard', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map((item) => DropdownMenuItem(value: item, child: Text(item.replaceAll('_', ' '))))
                    .toList(),
                onChanged: widget.controller.isAuthenticated
                    ? (value) => setState(() => _category = value ?? 'other')
                    : null,
              ),
              const SizedBox(height: 12),
              Text('Severity: $_severity'),
              Slider(
                value: _severity.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '$_severity',
                onChanged: widget.controller.isAuthenticated
                    ? (value) => setState(() => _severity = value.round())
                    : null,
              ),
              TextField(
                controller: _noteController,
                enabled: widget.controller.isAuthenticated,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isLoading || !widget.controller.isAuthenticated ? null : _createPin,
                child: const Text('Create hazard pin'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionTitle('Active community pins'),
            TextButton(onPressed: _isLoading ? null : _load, child: const Text('Refresh')),
          ],
        ),
        const SizedBox(height: 12),
        if (_markers.isEmpty)
          const RunnaCard(child: Text('No active hazard pins nearby.'))
        else
          ..._markers.map(
            (marker) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RunnaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      marker.categoryLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Severity ${marker.severity} • Confirms ${marker.confirmCount} • '
                      'Dismissals ${marker.dismissCount}',
                    ),
                    if (marker.note != null) ...[
                      const SizedBox(height: 4),
                      Text(marker.note!),
                    ],
                    if (widget.controller.isAuthenticated) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : () => _validatePin(marker, true),
                              child: const Text('Still there'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: _isLoading ? null : () => _validatePin(marker, false),
                              child: const Text('Resolved'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
