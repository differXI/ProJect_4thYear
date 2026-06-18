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
  }) async {
    final token = _requireToken();
    return _api.createMarker(
      accessToken: token,
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
  }) async {
    final token = _requireToken();
    return _api.validateMarker(
      accessToken: token,
      markerId: markerId,
      confirmed: confirmed,
    );
  }

  Future<List<ManualRouteItem>> getManualRoutes() async {
    final token = _requireToken();
    return _api.getManualRoutes(token);
  }

  Future<ManualRouteItem> createManualRoute({
    required String name,
    required List<RoutePoint> points,
  }) async {
    final token = _requireToken();
    return _api.createManualRoute(
      accessToken: token,
      name: name,
      points: points,
    );
  }

  Future<void> deleteManualRoute(int routeId) async {
    final token = _requireToken();
    return _api.deleteManualRoute(accessToken: token, routeId: routeId);
  }

  Future<List<RunItem>> getRuns() async {
    final token = _requireToken();
    return _api.getRuns(token);
  }

  Future<RunItem> getRun(int runId) async {
    final token = _requireToken();
    return _api.getRun(accessToken: token, runId: runId);
  }

  Future<RunItem> startRun({int? manualRouteId, int? routePlanId, String? notes}) async {
    final token = _requireToken();
    return _api.startRun(
      accessToken: token,
      manualRouteId: manualRouteId,
      notes: notes,
    );
  }

  Future<void> addRunPoints({
    required int runId,
    required List<RunPointUpload> points,
  }) async {
    final token = _requireToken();
    return _api.addRunPoints(
      accessToken: token,
      runId: runId,
      points: points,
    );
  }

  Future<RunItem> finishRun({
    required int runId,
    double? distanceKm,
    int? durationSeconds,
    int stepCount = 0,
  }) async {
    final token = _requireToken();
    return _api.finishRun(
      accessToken: token,
      runId: runId,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      stepCount: stepCount,
    );
  }

  Future<List<RoutePlanItem>> getRoutes() async {
    final token = _requireToken();
    return _api.getRoutes(token);
  }

  Future<RoutePlanItem> generateRoute({
    required String startLabel,
    required double targetDistanceKm,
    required String routeType,
    required String environment,
  }) async {
    final token = _requireToken();
    return _api.generateRoute(
      accessToken: token,
      startLabel: startLabel,
      targetDistanceKm: targetDistanceKm,
      routeType: routeType,
      environment: environment,
    );
  }

  Future<AdminStats> getAdminStats() async {
    final token = _requireToken();
    return _api.getAdminStats(token);
  }

  Future<List<AdminUserItem>> getAdminUsers() async {
    final token = _requireToken();
    return _api.getAdminUsers(token);
  }

  Future<AdminUserItem> updateAdminUser({
    required int userId,
    bool? isActive,
    String? roleName,
  }) async {
    final token = _requireToken();
    return _api.updateAdminUser(
      accessToken: token,
      userId: userId,
      isActive: isActive,
      roleName: roleName,
    );
  }

  Future<List<HazardMarkerItem>> getAdminMarkers() async {
    final token = _requireToken();
    return _api.getAdminMarkers(token);
  }

  Future<void> deleteAdminMarker(int markerId) async {
    final token = _requireToken();
    return _api.deleteAdminMarker(accessToken: token, markerId: markerId);
  }
  
  String _requireToken() {
    final token = _accessToken;
    if (token == null) {
      throw const RunnaApiException('Please sign in first.');
    }
    return token;
  }
}