import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models.dart';
import '../../core/runna_api.dart';

class AuthController extends ChangeNotifier {
  AuthController({RunnaApi? api}) : _api = api ?? RunnaApi();

  static const _tokenStorageKey = 'runna_access_token';
  final RunnaApi _api;
  String? _accessToken;
  UserProfile? _currentUser;
  bool _isRestoring = true;

  String? get accessToken => _accessToken;
  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _accessToken != null && _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isRestoring => _isRestoring;

  /// Attempts to restore a previous session from the persistent storage pool.
  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_tokenStorageKey);

      if (savedToken != null && savedToken.isNotEmpty) {
        // Validate token vitality by calling the profile endpoint
        final user = await _api.getMe(savedToken);
        _accessToken = savedToken;
        _currentUser = user;
      }
    } catch (_) {
      // Invalidate on expiration or connection failure to prevent corruption
      await _clearStoredToken();
      _accessToken = null;
      _currentUser = null;
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  Future<void> _persistToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenStorageKey, token);
  }

  Future<void> _clearStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenStorageKey);
  }

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
    await _persistToken(token.accessToken);
    notifyListeners();
    return _currentUser!;
  }

  Future<String> forgotPassword({required String email}) {
    return _api.forgotPassword(email: email);
  }

  Future<String> resetPassword({
    required String email,
    required String code,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _api.resetPassword(
      email: email,
      code: code,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }

  Future<void> logout() async {
    _accessToken = null;
    _currentUser = null;
    await _clearStoredToken();
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

  Future<List<RunPointItem>> getRunPoints(int runId) async {
    final token = _requireToken();
    return _api.getRunPoints(accessToken: token, runId: runId);
  }

  Future<RunItem> startRun({
    int? manualRouteId,
    int? routePlanId,
    String? notes,
  }) async {
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
    return _api.addRunPoints(accessToken: token, runId: runId, points: points);
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
