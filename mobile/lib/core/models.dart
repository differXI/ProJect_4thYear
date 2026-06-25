import 'dart:convert';

class HealthResponse {
  const HealthResponse({required this.status});

  final String status;

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(status: json['status'] as String? ?? 'unknown');
  }
}

class AuthToken {
  const AuthToken({required this.accessToken, required this.tokenType});

  final String accessToken;
  final String tokenType;

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    return AuthToken(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.isActive,
    required this.roleId,
    required this.roleName,
    this.province,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String? province;
  final bool isActive;
  final int roleId;
  final String roleName;

  bool get isAdmin => roleName == 'admin';
  String get fullName => '$firstName $lastName';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      province: json['province'] as String?,
      isActive: json['is_active'] as bool,
      roleId: json['role_id'] as int,
      roleName: json['role_name'] as String? ?? 'member',
    );
  }
}

class RunItem {
  const RunItem({
    required this.id,
    required this.userId,
    required this.status,
    required this.distanceKm,
    required this.durationSeconds,
    this.manualRouteId,
    this.routePlanId,
    this.startedAt,
    this.finishedAt,
    this.stepCount = 0,
    this.avgPaceMinPerKm,
    this.notes,
    this.aiInsight,
    this.aiReasoning,
    this.aiRecommendations,
  });

  final int id;
  final int userId;
  final int? manualRouteId;
  final int? routePlanId;
  final String status;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final double distanceKm;
  final int durationSeconds;
  final int stepCount;
  final double? avgPaceMinPerKm;
  final String? notes;
  final String? aiInsight;
  final String? aiReasoning;
  final String? aiRecommendations;

  factory RunItem.fromJson(Map<String, dynamic> json) {
    return RunItem(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      manualRouteId: json['manual_route_id'] as int?,
      routePlanId: json['route_plan_id'] as int?,
      status: json['status'] as String,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : null,
      finishedAt: json['finished_at'] != null ? DateTime.parse(json['finished_at'] as String) : null,
      distanceKm: (json['distance_km'] as num).toDouble(),
      durationSeconds: json['duration_seconds'] as int,
      stepCount: json['step_count'] as int? ?? 0,
      avgPaceMinPerKm: (json['avg_pace_min_per_km'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      aiInsight: json['ai_insight'] as String?,
      aiReasoning: json['ai_reasoning'] as String?,
      aiRecommendations: json['ai_recommendations'] as String?,
    );
  }
}

class RunPointItem {
  const RunPointItem({
    required this.id,
    required this.runId,
    required this.sequence,
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.speedMps,
    this.headingDeg,
    this.recordedAt,
  });

  final int id;
  final int runId;
  final int sequence;
  final double lat;
  final double lng;
  final double? accuracyM;
  final double? speedMps;
  final double? headingDeg;
  final DateTime? recordedAt;

  factory RunPointItem.fromJson(Map<String, dynamic> json) {
    return RunPointItem(
      id: json['id'] as int,
      runId: json['run_id'] as int,
      sequence: json['sequence'] as int,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
      speedMps: (json['speed_mps'] as num?)?.toDouble(),
      headingDeg: (json['heading_deg'] as num?)?.toDouble(),
      recordedAt: json['recorded_at'] != null ? DateTime.parse(json['recorded_at'] as String) : null,
    );
  }
}

class RunPointUpload {
  const RunPointUpload({
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.speedMps,
    this.headingDeg,
    this.recordedAt,
  });

  final double lat;
  final double lng;
  final double? accuracyM;
  final double? speedMps;
  final double? headingDeg;
  final DateTime? recordedAt;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'accuracy_m': accuracyM,
        'speed_mps': speedMps,
        'heading_deg': headingDeg,
        'recorded_at': recordedAt?.toUtc().toIso8601String(),
      };
}

class RoutePoint {
  const RoutePoint({
    required this.lat,
    required this.lng,
  });

  final double lat;
  final double lng;

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class RoutePlanItem {
  const RoutePlanItem({
    required this.id,
    required this.userId,
    required this.startLabel,
    required this.targetDistanceKm,
    required this.routeType,
    required this.environment,
    required this.centerLat,
    required this.centerLng,
    required this.pathJson,
    required this.estimatedMinutes,
    required this.safetyLevel,
    required this.summary,
  });

  final int id;
  final int userId;
  final String startLabel;
  final double targetDistanceKm;
  final String routeType;
  final String environment;
  final double centerLat;
  final double centerLng;
  final String pathJson;
  final int estimatedMinutes;
  final String safetyLevel;
  final String summary;

  factory RoutePlanItem.fromJson(Map<String, dynamic> json) {
    return RoutePlanItem(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      startLabel: json['start_label'] as String,
      targetDistanceKm: (json['target_distance_km'] as num).toDouble(),
      routeType: json['route_type'] as String,
      environment: json['environment'] as String,
      centerLat: (json['center_lat'] as num).toDouble(),
      centerLng: (json['center_lng'] as num).toDouble(),
      pathJson: json['path_json'] as String,
      estimatedMinutes: json['estimated_minutes'] as int,
      safetyLevel: json['safety_level'] as String,
      summary: json['summary'] as String,
    );
  }

  List<RoutePoint> get points {
    final decoded = jsonDecode(pathJson) as List<dynamic>;
    return decoded
        .map(
          (item) => RoutePoint(
            lat: (item['lat'] as num).toDouble(),
            lng: (item['lng'] as num).toDouble(),
          ),
        )
        .toList();
  }
}

class MapNodeItem {
  const MapNodeItem({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.isIntersection,
  });

  final int id;
  final String? name;
  final double lat;
  final double lng;
  final bool isIntersection;

  factory MapNodeItem.fromJson(Map<String, dynamic> json) {
    return MapNodeItem(
      id: json['id'] as int,
      name: json['name'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      isIntersection: json['is_intersection'] as bool,
    );
  }
}

class MapEdgeItem {
  const MapEdgeItem({
    required this.id,
    required this.startNodeId,
    required this.endNodeId,
    required this.roadName,
    required this.roadClass,
    required this.speedLimitKph,
    required this.lengthM,
    required this.riskScore,
    required this.isForbidden,
    required this.geometryJson,
  });

  final int id;
  final int startNodeId;
  final int endNodeId;
  final String roadName;
  final String roadClass;
  final double speedLimitKph;
  final double lengthM;
  final double riskScore;
  final bool isForbidden;
  final String geometryJson;

  factory MapEdgeItem.fromJson(Map<String, dynamic> json) {
    return MapEdgeItem(
      id: json['id'] as int,
      startNodeId: json['start_node_id'] as int,
      endNodeId: json['end_node_id'] as int,
      roadName: json['road_name'] as String,
      roadClass: json['road_class'] as String,
      speedLimitKph: (json['speed_limit_kph'] as num).toDouble(),
      lengthM: (json['length_m'] as num).toDouble(),
      riskScore: (json['risk_score'] as num).toDouble(),
      isForbidden: json['is_forbidden'] as bool,
      geometryJson: json['geometry_json'] as String,
    );
  }

  List<RoutePoint> get points {
    final decoded = jsonDecode(geometryJson) as List<dynamic>;
    return decoded
        .map(
          (item) => RoutePoint(
            lat: (item['lat'] as num).toDouble(),
            lng: (item['lng'] as num).toDouble(),
          ),
        )
        .toList();
  }
}

class HazardMarkerItem {
  const HazardMarkerItem({
    required this.id,
    required this.userId,
    required this.markerType,
    required this.severity,
    required this.lat,
    required this.lng,
    required this.note,
    required this.status,
    this.confirmCount = 0,
    this.dismissCount = 0,
    this.expiresAt,
  });

  final int id;
  final int userId;
  final String markerType;
  final int severity;
  final double lat;
  final double lng;
  final String? note;
  final String status;
  final int confirmCount;
  final int dismissCount;
  final String? expiresAt;

  String get categoryLabel => markerType.replaceAll('_', ' ');

  factory HazardMarkerItem.fromJson(Map<String, dynamic> json) {
    return HazardMarkerItem(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      markerType: json['marker_type'] as String,
      severity: json['severity'] as int,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      note: json['note'] as String?,
      status: json['status'] as String,
      confirmCount: json['confirm_count'] as int? ?? 0,
      dismissCount: json['dismiss_count'] as int? ?? 0,
      expiresAt: json['expires_at'] as String?,
    );
  }
}

class BaseMapData {
  const BaseMapData({
    required this.nodes,
    required this.edges,
    required this.markers,
  });

  final List<MapNodeItem> nodes;
  final List<MapEdgeItem> edges;
  final List<HazardMarkerItem> markers;

  factory BaseMapData.fromJson(Map<String, dynamic> json) {
    final nodesJson = json['nodes'] as List<dynamic>;
    final edgesJson = json['edges'] as List<dynamic>;
    final markersJson = json['markers'] as List<dynamic>;
    return BaseMapData(
      nodes: nodesJson.map((item) => MapNodeItem.fromJson(item as Map<String, dynamic>)).toList(),
      edges: edgesJson.map((item) => MapEdgeItem.fromJson(item as Map<String, dynamic>)).toList(),
      markers: markersJson.map((item) => HazardMarkerItem.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }
}

class ManualRouteItem {
  const ManualRouteItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.pathJson,
    required this.distanceKm,
  });

  final int id;
  final int userId;
  final String name;
  final String pathJson;
  final double distanceKm;

  factory ManualRouteItem.fromJson(Map<String, dynamic> json) {
    return ManualRouteItem(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      name: json['name'] as String,
      pathJson: json['path_json'] as String,
      distanceKm: (json['distance_km'] as num).toDouble(),
    );
  }

  List<RoutePoint> get points {
    final decoded = jsonDecode(pathJson) as List<dynamic>;
    return decoded
        .map(
          (item) => RoutePoint(
            lat: (item['lat'] as num).toDouble(),
            lng: (item['lng'] as num).toDouble(),
          ),
        )
        .toList();
  }
}

class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalRuns,
    required this.finishedRuns,
    required this.activePins,
    required this.expiredPins,
    required this.totalRoutes,
  });

  final int totalUsers;
  final int activeUsers;
  final int totalRuns;
  final int finishedRuns;
  final int activePins;
  final int expiredPins;
  final int totalRoutes;

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalUsers: json['total_users'] as int,
      activeUsers: json['active_users'] as int,
      totalRuns: json['total_runs'] as int,
      finishedRuns: json['finished_runs'] as int,
      activePins: json['active_pins'] as int,
      expiredPins: json['expired_pins'] as int,
      totalRoutes: json['total_routes'] as int,
    );
  }
}

class AdminUserItem {
  const AdminUserItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.isActive,
    required this.roleName,
    required this.runCount,
    required this.pinCount,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final bool isActive;
  final String roleName;
  final int runCount;
  final int pinCount;

  factory AdminUserItem.fromJson(Map<String, dynamic> json) {
    return AdminUserItem(
      id: json['id'] as int,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      isActive: json['is_active'] as bool,
      roleName: json['role_name'] as String,
      runCount: json['run_count'] as int? ?? 0,
      pinCount: json['pin_count'] as int? ?? 0,
    );
  }
}