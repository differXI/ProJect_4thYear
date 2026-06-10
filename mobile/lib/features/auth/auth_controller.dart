import 'package:flutter/foundation.dart';

import '../../core/models.dart';
import '../../core/runna_api.dart';

class AuthController extends ChangeNotifier {
  AuthController({RunnaApi? api}) : _api = api ?? RunnaApi();

  final RunnaApi _api;
  String? _accessToken;
  UserProfile? _currentUser;

  String? get accessToken => _accessToken;
  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _accessToken != null && _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  Future<HealthResponse> getHealth() => _api.getHealth();

  Future<UserProfile> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
  }) {
    return _api.register(
      firstName: firstName,
      lastName: lastName,
      username: username,
      email: email,
      password: password,
    );
  }

  Future<UserProfile> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final token = await _api.login(
      usernameOrEmail: usernameOrEmail,
      password: password,
    );
    _accessToken = token.accessToken;
    _currentUser = await _api.getMe(token.accessToken);
    notifyListeners();
    return _currentUser!;
  }

  void logout() {
    _accessToken = null;
    _currentUser = null;
    notifyListeners();
  }

  Future<BaseMapData> getBaseMap() => _api.getBaseMap();

  Future<List<HazardMarkerItem>> getMarkers() => _api.getMarkers();

  Future<HazardMarkerItem> createMarker({
    required String markerType,
    required int severity,
    required double lat,
    required double lng,
    String? note,
  }) {
    return _api.createMarker(
      accessToken: _requireToken(),
      markerType: markerType,
      severity: severity,
      lat: lat,
      lng: lng,
      note: note,
    );
  }

  Future<HazardMarkerItem> validateMarker({
    required int markerId,
    required bool confirmed,
  }) {
    return _api.validateMarker(
      accessToken: _requireToken(),
      markerId: markerId,
      confirmed: confirmed,
    );
  }

  Future<List<ManualRouteItem>> getManualRoutes() {
    return _api.getManualRoutes(_requireToken());
  }

  Future<ManualRouteItem> createManualRoute({
    required String name,
    required List<RoutePoint> points,
  }) {
    return _api.createManualRoute(
      accessToken: _requireToken(),
      name: name,
      points: points,
    );
  }

  Future<void> deleteManualRoute(int routeId) {
    return _api.deleteManualRoute(accessToken: _requireToken(), routeId: routeId);
  }

  Future<List<RunItem>> getRuns() => _api.getRuns(_requireToken());

  Future<RunItem> getRun(int runId) => _api.getRun(accessToken: _requireToken(), runId: runId);

  Future<RunItem> startRun({int? manualRouteId, String? notes}) {
    return _api.startRun(
      accessToken: _requireToken(),
      manualRouteId: manualRouteId,
      notes: notes,
    );
  }

  Future<RunItem> finishRun({
    required int runId,
    required double distanceKm,
    required int durationSeconds,
    required int stepCount,
  }) {
    return _api.finishRun(
      accessToken: _requireToken(),
      runId: runId,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      stepCount: stepCount,
    );
  }

  Future<AdminStats> getAdminStats() => _api.getAdminStats(_requireToken());

  Future<List<AdminUserItem>> getAdminUsers() => _api.getAdminUsers(_requireToken());

  Future<AdminUserItem> updateAdminUser({
    required int userId,
    bool? isActive,
    String? roleName,
  }) {
    return _api.updateAdminUser(
      accessToken: _requireToken(),
      userId: userId,
      isActive: isActive,
      roleName: roleName,
    );
  }

  Future<List<HazardMarkerItem>> getAdminMarkers() => _api.getAdminMarkers(_requireToken());

  Future<void> deleteAdminMarker(int markerId) {
    return _api.deleteAdminMarker(accessToken: _requireToken(), markerId: markerId);
  }

  String _requireToken() {
    final token = _accessToken;
    if (token == null) {
      throw const RunnaApiException('Please sign in first.');
    }
    return token;
  }
}
