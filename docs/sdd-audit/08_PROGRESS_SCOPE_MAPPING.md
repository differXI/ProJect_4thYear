# Progress scope mapping

Every source category requested is classified below. “Include” means in the Progress I SDD detailed design; shared dependencies may be included only to explain a PI flow.

| Component | Source Path | Progress I / Progress II / Shared | Related Feature | Include in SDD? | Reason |
|---|---|---|---|---|---|
| main/router/deps/config/db/base/session | `backend/app/main.py`, `api/router.py`, `api/deps.py`, `core/config.py`, `db/*.py` | Shared | platform | Yes, architecture | Underpins all flows |
| auth router all 4 endpoints | `api/routes/auth.py` | Progress I | Authentication & Roles | Yes | Explicit PI |
| users router `/me` | `api/routes/users.py:11-27` | Shared | Authentication/profile | Yes where auth needs it | Session restore uses it |
| emergency-contact endpoints | `users.py:30-50` | Shared/outside listed scope | profile safety | No detailed design | Not in requested PI list |
| map base endpoints | `api/routes/map.py:35-54` | Shared | View Route Map | Yes limited | Graph is display substrate |
| map import | `map.py:57-68` | Progress II | OSM import | No; report separately | Explicit PII |
| marker list/create | `map.py:71-86` | Progress I | Collaborative Pin System | Yes | Explicit PI |
| manual route endpoints | `map.py:89-117` | Progress I | Route Creation | Yes | Explicit PI |
| edge override/approve/rebuild/high-risk | `map.py:119-167` | Progress II | moderation/map management | No | Explicit PII |
| generated-route router | `api/routes/routes.py` | Progress II | Dijkstra generation | No | Explicit PII |
| runs router list/start/get/points | `api/routes/runs.py:12-64` | Progress II | tracking/history/GPS | No | Explicit PII |
| finish run endpoint | `runs.py:67-79` | Shared | AI Run Summary + tracking | Yes only AI trigger/result | PI output on PII substrate |
| admin stats | `admin.py:32-39` | Shared/mixed | dashboard | Only contextual | Contains PII counts |
| admin users | `admin.py:42-74` | Progress I | Admin User Management | Yes | Explicit PI |
| admin markers | `admin.py:77-98` | Progress II | moderation | No | Explicit PII |
| User, Role, PasswordResetCode | `models/user.py`, `role.py`, `password_reset_code.py` | Progress I | Authentication & Roles | Yes | Core PI data |
| ManualRoute | `models/manual_route.py` | Progress I | Route Creation | Yes | Core PI data |
| HazardMarker core fields | `models/hazard_marker.py` | Progress I | pin create/view | Yes | Category/severity/note |
| Hazard lifecycle fields/PinValidation | hazard model; `pin_validation.py` | Progress II | confirmation/lifecycle | No detailed PI | Explicit PII |
| MapNode/MapEdge | `models/map_node.py`, `map_edge.py` | Shared/Progress II | map/graph | Limited shared | Display/snapping; management PII |
| RoutePlan | `models/route_plan.py` | Progress II | generated routes | No | Dijkstra feature |
| Run/RunPoint | `models/run.py` | Progress II with shared PI AI fields | tracking + summary | Only AI fields/dependency | Tracking is PII |
| EmergencyContact | `models/emergency_contact.py` | Shared/outside scope | contacts | No detailed design | Not listed |
| Auth schemas | `schemas/auth.py` | Progress I | Authentication | Yes | Exact contracts |
| UserResponse/AdminUser schemas | `schemas/user.py` | PI/shared | auth/admin | Yes relevant classes | Contracts |
| ManualRoute schemas | `schemas/manual_route.py` | Progress I | Route Creation | Yes | Contracts |
| Hazard create/response | `schemas/map.py:29-54` | Progress I/shared | pins | Yes core fields | Contracts |
| map node/edge/base schemas | `schemas/map.py:4-27,57-60` | Shared | view map | Limited | Display substrate |
| HazardMarkerValidate | `schemas/map.py:37-39` | Progress II/disconnected | validation | No | Missing backend endpoint |
| route schemas | `schemas/route.py` | Progress II | Dijkstra | No | Explicit PII |
| run schemas | `schemas/run.py` | Progress II/shared AI | tracking/AI | Only RunResponse AI fields | Mixed |
| contact schemas | `schemas/contact.py` | Shared/outside | contacts | No | Not listed |
| serializers | `schemas/serializers.py` | Shared | response conversion | Yes user; note route serializer unused | Supporting code |
| AuthService/security/email | `services/auth_service.py`, `security.py`, `email_service.py` | Progress I | Authentication & Roles | Yes | Core flows |
| MapService manual route/marker/base | `services/map_service.py:185-305` | PI/shared | routes/pins/map | Yes relevant methods | Core flows |
| MapService seed/import | `map_service.py:28-183` | Shared/PII | seed/OSM | Architecture/PII only | Not PI behavior |
| RouteService | `services/route_service.py` | Progress II | Dijkstra | No | Explicit PII |
| RunService | `services/run_service.py` | Progress II/shared AI | tracking/summary | Only finish AI branch | Mixed |
| AnalysisService/AnalysisResult | `services/analysis_service.py` | Progress I; recommendation portion PII | AI summary | Yes, separate recommendations | Explicit split |
| AdminService user methods | `services/admin_service.py:20-104` | PI/shared | user management/stats | Yes list/update; stats limited | Explicit PI |
| AdminService marker/graph methods | `admin_service.py:106-163` | Progress II | moderation/graph | No | Explicit PII |
| UserService | `services/user_service.py` | Shared/outside | profile/contacts | Only `/me` context | Not core PI list |
| seed service | `services/seed_service.py` | Shared | startup/RBAC/map seed | Architecture/security | Startup dependency |
| migrations 0001, 0002 | `alembic/versions/20260417_0001...`, `0002...` | Shared/mixed | auth/map/run | Yes relevant tables; separate PII tables | Schema truth |
| migrations 0003,0004 | `...0003...`, `...0004...` | Progress II | RoutePlan | No detail | Generated route |
| migration 0005 lifecycle | `...0005_add_run_analysis...` | Shared/mixed | manual validation/run AI/pins | Relevant PI columns only | Mixed |
| migration 20260615_0005 | `...add_run_points.py` | Progress II/shared AI | tracking | No detail; flag quality | Run points |
| migration 20260715_0006 | `...add_password_reset_codes.py` | Progress I | password reset | Yes | Core PI |
| Flutter app shell/theme/config | `mobile/lib/main.dart`, `core/theme.dart`, `app_config.dart` | Shared | platform | Architecture | Shared |
| Flutter DTO/API/controller | `core/models.dart`, `runna_api.dart`, `auth_controller.dart` | Shared/mixed | all | Include PI members only | Central mixed modules |
| LocationService | `core/location_service.dart` | Progress II | GPS tracking/location | Route “my location” shared; tracking PII | Limited shared mention |
| AuthScreen | `features/auth/auth_screen.dart` | Progress I | Authentication | Yes | PI UI |
| RoutesScreen | `features/routes/routes_screen.dart` | Progress I | Route Creation | Yes | PI UI/local clear |
| HazardsScreen create/view | `features/hazards/hazards_screen.dart` | Progress I | pins | Yes | PI UI |
| HazardsScreen validate actions | same `:108-124,265-283` | Progress II/disconnected | confirmation/dismissal | No | PII and backend missing |
| RunsScreen | `features/runs/runs_screen.dart` | Progress II/shared PI AI | tracking/history/summary | AI display only | Mixed |
| AdminScreen users | `features/admin/admin_screen.dart:64-111,182-226` | Progress I | Admin Users | Yes | PI UI |
| AdminScreen stats/markers | same | Progress II/shared | dashboard/moderation | No detail | Mixed/PII |
| HomeScreen | `features/home/home_screen.dart` | Shared | navigation/summary | Architecture only | Not explicit PI use case |
| backend auth tests | `backend/tests/test_auth.py` | Progress I | auth/reset | Evidence | PI verification |
| backend health | `test_health.py` | Shared | health | Evidence | infrastructure |
| backend map test | `test_map.py` | Mixed | route/pin/validation | PI evidence plus failing PII expectation | Mixed |
| backend routes test | `test_routes.py` | Progress II | Dijkstra | Report separately | Explicit PII |
| backend runs test | `test_runs.py` | Progress II/shared AI | tracking/finish | Report separately; AI weakly covered | Mixed |
| conftest | `backend/tests/conftest.py` | Shared | fixtures | Evidence setup | Shared |
| mobile reset test | `mobile/test/auth_password_reset_test.dart` | Progress I | reset UI | Evidence | PI |
| mobile widget smoke | `mobile/test/widget_test.dart` | Shared | app health | Evidence | Shared |

Major methods inherit the classification of their row; the exact method-by-method list is in `03_METHOD_CATALOG.md`. All 35 endpoints are individually classified in `04_REST_API_CATALOG.md`.
