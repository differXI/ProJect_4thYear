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

  List<HazardMarkerItem> _allMarkers = const [];
  List<HazardMarkerItem> _myMarkers = const [];
  LatLng? _selectedPoint;
  String _category = 'construction';
  int _severity = 3;
  String? _message;
  bool _isLoading = false;
  bool _showMyPins = false;
  String _sortBy = 'newest'; // 'newest', 'severity_high', 'confirms'

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
      final markersData = await widget.controller.getMarkers();
      List<HazardMarkerItem> myMarkersData = const [];
      
      if (widget.controller.isAuthenticated) {
        myMarkersData = await widget.controller.getMyMarkers();
      }

      if (!mounted) return;
      setState(() {
        _allMarkers = markersData;
        _myMarkers = myMarkersData;
      });
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

  String _formatMarkerType(String type) {
    return type.replaceAll('_', ' ').toUpperCase();
  }

  List<HazardMarkerItem> _getSortedMarkers() {
    final markers = List.of(_allMarkers);
    switch (_sortBy) {
      case 'severity_high':
        markers.sort((a, b) => b.severity.compareTo(a.severity));
        break;
      case 'confirms':
        markers.sort((a, b) => b.confirmCount.compareTo(a.confirmCount));
        break;
      case 'newest':
      default:
        // Already sorted by default
        break;
    }
    return markers;
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
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      setState(() {
        _selectedPoint = null;
        _noteController.clear();
        _category = 'construction';
        _severity = 3;
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
    final sortedMarkers = _getSortedMarkers();
    
    final mapMarkers = sortedMarkers
        .map(
          (marker) => Marker(
            point: LatLng(marker.lat, marker.lng),
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () => _showMarkerDetails(marker),
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

    if (_selectedPoint != null) {
      mapMarkers.add(
        Marker(
          point: _selectedPoint!,
          width: 40,
          height: 40,
          child: Container(
            decoration: const BoxDecoration(
              color: RunnaColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Hazard pins',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (_myMarkers.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _showMyPins = !_showMyPins),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: RunnaColors.muted.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: RunnaColors.primaryDark),
                      const SizedBox(width: 6),
                      Text(
                        'My pins (${_myMarkers.length})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: RunnaColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              IconButton.filledTonal(
                tooltip: 'Refresh',
                onPressed: _isLoading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Report and validate real-world route conditions',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),

        // ── Map ──────────────────────────────────────
        Container(
          height: 300,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: RunnaColors.muted.withValues(alpha: 0.2)),
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
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'runna_mobile',
              ),
              MarkerLayer(markers: mapMarkers),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_showMyPins && _myMarkers.isNotEmpty)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => setState(() => _showMyPins = false),
            child: Container(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: RunnaColors.muted.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'My pins',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() => _showMyPins = false),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._myMarkers.map((marker) => _buildMyPinInlineCard(marker)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // ── Messages ────────────────────────────────
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Text(
                _message!,
                style: const TextStyle(color: Color(0xFFC62828)),
              ),
            ),
          ),

        // ── Report section ──────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: RunnaColors.muted.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report a hazard',
                style:
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map((item) =>
                        DropdownMenuItem(
                          value: item,
                          child: Text(
                            item.replaceAll('_', ' ').toUpperCase(),
                          ),
                        ))
                    .toList(),
                onChanged:
                    widget.controller.isAuthenticated && !_isLoading
                        ? (value) =>
                            setState(() => _category = value ?? 'other')
                        : null,
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Severity: $_severity',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        ['Low', 'Medium', 'High', 'Very High', 'Critical'][
                            _severity - 1],
                        style: TextStyle(
                          color: _getSeverityColor(_severity),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _severity.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '$_severity',
                    onChanged:
                        widget.controller.isAuthenticated && !_isLoading
                            ? (value) =>
                                setState(() => _severity = value.round())
                            : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                enabled:
                    widget.controller.isAuthenticated && !_isLoading,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g., Pothole on left side near tree',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (!widget.controller.isAuthenticated ||
                          _isLoading)
                      ? null
                      : _createPin,
                  child: const Text('Report hazard'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Community Pins Header with Sort ─────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active community pins',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${sortedMarkers.length} pins in this area',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            PopupMenuButton<String>(
              onSelected: (value) => setState(() => _sortBy = value),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'newest',
                  child: Row(
                    children: [
                      if (_sortBy == 'newest')
                        const Icon(Icons.check, size: 18)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      const Text('Newest'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'severity_high',
                  child: Row(
                    children: [
                      if (_sortBy == 'severity_high')
                        const Icon(Icons.check, size: 18)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      const Text('High severity first'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'confirms',
                  child: Row(
                    children: [
                      if (_sortBy == 'confirms')
                        const Icon(Icons.check, size: 18)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      const Text('Most confirmed'),
                    ],
                  ),
                ),
              ],
              child: Chip(label: Text(_sortBy.replaceAll('_', ' '))),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (sortedMarkers.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No hazard pins reported yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          )
        else
          ..._myMarkers.isEmpty
              ? sortedMarkers
                  .map((marker) => _buildCommunityMarkerCard(marker))
                  .toList()
              : sortedMarkers
                  .where((m) => !m.isMine)
                  .map((marker) => _buildCommunityMarkerCard(marker))
                  .toList(),
      ],
    );
  }

  Widget _buildMyPinInlineCard(HazardMarkerItem marker) {
    final daysAgo = marker.daysSinceReported;
    final dayLabel = daysAgo == null
        ? 'Unknown date'
        : daysAgo == 0
            ? 'Reported today'
            : daysAgo == 1
                ? 'Reported yesterday'
                : 'Reported $daysAgo days ago';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RunnaColors.muted.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _getSeverityColor(marker.severity),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatMarkerType(marker.markerType),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  dayLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Pin actions',
            onSelected: (value) async {
              if (value == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete pin'),
                    content: const Text('Are you sure you want to delete this hazard pin?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirmed != true) return;

                if (!mounted) return;
                setState(() => _isLoading = true);
                try {
                  await widget.controller.deleteMarker(marker.id);
                  if (!mounted) return;
                  await _load();
                  setState(() => _showMyPins = false);
                } catch (error) {
                  if (!mounted) return;
                  setState(() => _message = 'Failed to delete pin: $error');
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              } else if (value == 'details') {
                _showMarkerDetails(marker);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'details',
                child: Text('View details'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
            child: const Icon(Icons.more_vert, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityMarkerCard(HazardMarkerItem marker) {
    final daysAgo = marker.daysSinceReported;
    final dayLabel = daysAgo == null
        ? 'Unknown date'
        : daysAgo == 0
            ? 'today'
            : daysAgo == 1
                ? 'yesterday'
                : '$daysAgo days ago';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RunnaColors.muted.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
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
                      _formatMarkerType(marker.markerType),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${marker.reporterName ?? 'Anonymous'} • $dayLabel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (marker.note != null) ...[
            const SizedBox(height: 8),
            Text(
              marker.note!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
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
        ],
      ),
    );
  }

  void _showMarkerDetails(HazardMarkerItem marker) {
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
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatMarkerType(marker.markerType),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${marker.reporterName ?? 'Anonymous'} • $dayLabel',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (marker.note != null) ...[
              Text('Description:', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(marker.note!),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Chip(label: Text('${marker.confirmCount} confirms')),
                const SizedBox(width: 8),
                Chip(label: Text('${marker.dismissCount} disagree')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
