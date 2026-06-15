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

  Future<HealthResponse> getHealth() => _api.getHealth();

  Future<UserProfile> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
  }) async {
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

  Future<List<RunItem>> getRuns() async {
    final token = _requireToken();
    return _api.getRuns(token);
  }

  Future<RunItem> startRun({int? manualRouteId, int? routePlanId, String? notes}) async {
    final token = _requireToken();
    return _api.startRun(
      accessToken: token,
      manualRouteId: manualRouteId,
      routePlanId: routePlanId,
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
  }) async {
    final token = _requireToken();
    return _api.finishRun(
      accessToken: token,
      runId: runId,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
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

  String _requireToken() {
    final token = _accessToken;
    if (token == null) {
      throw const RunnaApiException('Please sign in first.');
    }
    return token;
  }
}
