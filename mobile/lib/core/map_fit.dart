import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'models.dart';

/// Helpers for framing routes and points on flutter_map views.
class RunnaMapFit {
  RunnaMapFit._();

  static const fallbackCenter = LatLng(18.8059, 98.9523);

  /// Padding for the Runs screen map (taller viewport).
  static const runsMapPadding = EdgeInsets.symmetric(horizontal: 36, vertical: 44);

  /// Padding for route preview bottom sheets (shorter viewport).
  static const previewMapPadding = EdgeInsets.symmetric(horizontal: 28, vertical: 36);

  /// Padding for the Routes tab map when fitting a saved route.
  static const routesMapPadding = EdgeInsets.symmetric(horizontal: 40, vertical: 48);

  static List<LatLng> toLatLngs(List<RoutePoint> points) =>
      points.map((p) => LatLng(p.lat, p.lng)).toList();

  static LatLng centerOf(List<LatLng> points) {
    if (points.isEmpty) return fallbackCenter;
    var lat = 0.0;
    var lng = 0.0;
    for (final point in points) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  static CameraFit? cameraFitFor(
    List<LatLng> points, {
    EdgeInsets padding = runsMapPadding,
    double maxZoom = 16,
    double minZoom = 12,
  }) {
    if (points.length < 2) return null;
    return CameraFit.coordinates(
      coordinates: points,
      padding: padding,
      maxZoom: maxZoom,
      minZoom: minZoom,
    );
  }

  /// Fits the map camera to [points], or centers on a single point when needed.
  static void safeFitCamera(
    MapController controller,
    List<LatLng> points, {
    EdgeInsets padding = runsMapPadding,
    double maxZoom = 16,
    double minZoom = 12,
    double singlePointZoom = 15,
  }) {
    if (points.isEmpty) return;
    try {
      if (points.length == 1) {
        controller.move(points.first, singlePointZoom);
        return;
      }
      final fit = cameraFitFor(
        points,
        padding: padding,
        maxZoom: maxZoom,
        minZoom: minZoom,
      );
      if (fit != null) {
        controller.fitCamera(fit);
      }
    } catch (_) {
      // Map not ready yet — ignore.
    }
  }
}
