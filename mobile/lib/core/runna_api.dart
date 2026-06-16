import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'models.dart';

class RunnaApi {
  RunnaApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Map<String, String> _jsonHeaders([String? token]) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<HealthResponse> getHealth() async {
    final response = await _client.get(_uri('/health'));
    _ensureSuccess(response);
    return HealthResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<UserProfile> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/auth/register'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    _ensureSuccess(response);
    return UserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AuthToken> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/auth/login'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'username_or_email': usernameOrEmail,
        'password': password,
      }),
    );
    _ensureSuccess(response);
    return AuthToken.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<UserProfile> getMe(String accessToken) async {
    final response = await _client.get(_uri('/me'), headers: _jsonHeaders(accessToken));
    _ensureSuccess(response);
    return UserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<BaseMapData> getBaseMap() async {
    final response = await _client.get(_uri('/map/base'));
    _ensureSuccess(response);
    return BaseMapData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<HazardMarkerItem>> getMarkers() async {
    final response = await _client.get(_uri('/map/markers'));
    _ensureSuccess(response);
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((item) => HazardMarkerItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<HazardMarkerItem> createMarker({
    required String accessToken,
    required String markerType,
    required int severity,
    required double lat,
    required double lng,
    String? note,
  }) async {
    final response = await _client.post(
      _uri('/map/markers'),
      headers: _jsonHeaders(accessToken),
      body: jsonEncode({
        'marker_type': markerType,
        'severity': severity,
        'lat': lat,
        'lng': lng,
        'note': note,
      }),
    );
    _ensureSuccess(response);
    return HazardMarkerItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<HazardMarkerItem> validateMarker({
    required String accessToken,
    required int markerId,
    required bool confirmed,
  }) async {
    final response = await _client.post(
      _uri('/map/markers/$markerId/validate'),
      headers: _jsonHeaders(accessToken),
      body: jsonEncode({'confirmed': confirmed}),
    );
    _ensureSuccess(response);
    return HazardMarkerItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<ManualRouteItem>> getManualRoutes(String accessToken) async {
    final response = await _client.get(
      _uri('/map/manual-routes'),
      headers: _jsonHeaders(accessToken),
    );
    _ensureSuccess(response);
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((item) => ManualRouteItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ManualRouteItem> createManualRoute({
    required String accessToken,
    required String name,
    required List<RoutePoint> points,
  }) async {
    final response = await _client.post(
      _uri('/map/manual-routes'),
      headers: _jsonHeaders(accessToken),
      body: jsonEncode({
        'name': name,
        'points': points.map((point) => point.toJson()).toList(),
      }),
    );
    _ensureSuccess(response);
    return ManualRouteItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteManualRoute({
    required String accessToken,
    required int routeId,
  }) async {
    final response = await _client.delete(
      _uri('/map/manual-routes/$routeId'),
      headers: _jsonHeaders(accessToken),
    );
    _ensureSuccess(response);
  }

  Future<List<RunItem>> getRuns(String accessToken) async {
    final response = await _client.get(
      _uri('/runs'),
      headers: _jsonHeaders(accessToken),
    );
    _ensureSuccess(response);
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((item) => RunItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<RunItem> getRun({
    required String accessToken,
    required int runId,
  }) async {
    final response = await _client.get(
      _uri('/runs/$runId'),
      headers: _jsonHeaders(accessToken),
    );
    _ensureSuccess(response);
    return RunItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<RunItem> startRun({
    required String accessToken,
    int? manualRouteId,
    int? routePlanId,
    String? notes,
  }) async {
    final response = await _client.post(
      _uri('/runs/start'),
      headers: _jsonHeaders(accessToken),
      body: jsonEncode({
        'manual_route_id': manualRouteId,
        'route_plan_id': routePlanId,
        'notes': notes,
      }),
    );
    _ensureSuccess(response);
    return RunItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> addRunPoints({
    required String accessToken,
    required int runId,
    required List<RunPointUpload> points,
  }) async {
    if (points.isEmpty) return;
    final response = await _client.post(
      _uri('/runs/$runId/points'),
      headers: _jsonHeaders(accessToken),
      body: jsonEncode(points.map((point) => point.toJson()).toList()),
    );
    _ensureSuccess(response);
  }

  Future<RunItem> finishRun({
    required String accessToken,
    required int runId,
    double? distanceKm,
    int? durationSeconds,
    int stepCount = 0,
  }) async {
    final response = await _client.post(
      _uri('/runs/$runId/finish'),
      headers: _jsonHeaders(accessToken),
      body: jsonEncode({
        'distance_km': distanceKm,
        'duration_seconds': durationSeconds,
        'step_count': stepCount,
      }),
    );
    _ensureSuccess(response);
    return RunItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<RoutePlanItem>> getRoutes(String accessToken) async {
    final response = await _client.get(
      _uri('/routes'),
      headers: _jsonHeaders(accessToken),
    );
    _ensureSuccess(response);
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((item) => RoutePlanItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<RoutePlanItem> generateRoute({
    required String accessToken,
    required String startLabel,
    required double targetDistanceKm,
    required String routeType,
    required String environment,
  }) async {
    final response = await _client.post(
      _uri('/routes/generate'),
      headers: _jsonHeaders(accessToken),
      body: jsonEncode({
        'start_label': startLabel,
        'target_distance_km': targetDistanceKm,
        'route_type': routeType,
        'environment': environment,
      }),
    );
    _ensureSuccess(response);
    return RoutePlanItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AdminStats> getAdminStats(String accessToken) async {
    final response = await _client.get(
      _uri('/admin/stats'),
      headers: _jsonHeaders(accessToken),
    );
    _ensureSuccess(response);
    return AdminStats.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<AdminUserItem>> getAdminUsers(String accessToken) async {
    final response = await _client.get(
      _uri('/admin/users'),
      headers: _jsonHeaders(accessToken),
    );
    _ensureSuccess(response);
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((item) => AdminUserItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<AdminUserItem> updateAdminUser({
    required String accessToken,
    required int userId,
    bool? isActive,
    String? roleName,
  }) async {
    final response = await _client.patch(
      _uri('/admin/users/$userId'),
      headers: _jsonHeaders(accessToken),
      body: jsonEncode({
        if (isActive != null) 'is_active': isActive,
        if (roleName != null) 'role_name': roleName,
      }),
    );
    _ensureSuccess(response);
    return AdminUserItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<HazardMarkerItem>> getAdminMarkers(String accessToken) async {
    final response = await _client.get(
      _uri('/admin/markers'),
      headers: _jsonHeaders(accessToken),
    );
    _ensureSuccess(response);
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((item) => HazardMarkerItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> deleteAdminMarker({
    required String accessToken,
    required int markerId,
  }) async {
    final response = await _client.delete(
      _uri('/admin/markers/$markerId'),
      headers: _jsonHeaders(accessToken),
    );
    _ensureSuccess(response);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    String detail = 'Request failed with status ${response.statusCode}';
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        if (body['detail'] is String) {
          detail = body['detail'] as String;
        } else if (body['detail'] is List && (body['detail'] as List).isNotEmpty) {
          detail = '${(body['detail'] as List).first}';
        }
      }
    } catch (_) {
      // Keep fallback detail if the response is not JSON.
    }
    throw RunnaApiException(detail);
  }
}

class RunnaApiException implements Exception {
  const RunnaApiException(this.message);

  final String message;

  @override
  String toString() => message;
}