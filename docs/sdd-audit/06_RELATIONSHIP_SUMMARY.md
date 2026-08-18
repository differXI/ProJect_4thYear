# Relationship summary

Document identifiers not unambiguously present in source are marked `Needs document confirmation`.

## A. Use Case to Design

| Use Case | UI Screen | Flutter Controller | Mobile API Method | REST API | Backend Router | Service Method | Models/Schemas | Sequence Diagram |
|---|---|---|---|---|---|---|---|---|
| Register | AuthScreen | register | register | POST auth/register | register | AuthService.register | UserRegister/User | SD-01 |
| Login | AuthScreen | login | login/getMe | POST auth/login; GET me | login/get_me | AuthService.login/get_current_user | LoginRequest/TokenResponse | SD-02 |
| Logout | AuthScreen/app | logout | none | none | none | none | local token/profile | None; client-only |
| Forgot password | AuthScreen reset sheet | forgotPassword | forgotPassword | POST auth/forgot-password | forgot_password | AuthService.forgot_password | ForgotPasswordRequest/PasswordResetCode | SD-03 |
| Reset password | AuthScreen reset sheet | resetPassword | resetPassword | POST auth/reset-password | reset_password | AuthService.reset_password | ResetPasswordRequest | SD-04 |
| View route map | RoutesScreen | getBaseMap | getBaseMap | GET map/base | get_base_map_alias | MapService.get_base_map | BaseMapResponse | None requested |
| Save custom route | RoutesScreen | createManualRoute | createManualRoute | POST map/manual-routes | create_manual_route | MapService.create_manual_route | ManualRouteCreate/ManualRoute | SD-05 |
| Clear points | RoutesScreen | none | none | none | none | none | local List<RoutePoint> | SD-05 alternative |
| Delete saved route | RoutesScreen | deleteManualRoute | deleteManualRoute | DELETE map/manual-routes/{id} | delete_manual_route | MapService.delete_manual_route | ManualRoute/Run | SD-06 |
| Create hazard | HazardsScreen | createMarker | createMarker | POST map/markers | create_marker | MapService.create_marker | HazardMarkerCreate/Marker | SD-07 |
| View hazards | HazardsScreen | getMarkers | getMarkers | GET map/markers | list_markers | MapService.list_markers | HazardMarkerResponse | SD-08 |
| AI summary | RunsScreen | finishRun/getRun | finishRun/getRun | POST runs/{id}/finish | finish_run | RunService.finish_run/AnalysisService.analyze | Run/AnalysisResult | SD-09 |
| Manage users | AdminScreen | get/updateAdminUser | get/updateAdminUser | GET/PATCH admin/users | list/update_user | AdminService | AdminUser* | SD-10 |

## B. URS to Design

| URS | Related Use Case | Data Structure | Method Description | REST API | Sequence Diagram | UI |
|---|---|---|---|---|---|---|
| Needs document confirmation | Registration/Login/Reset/RBAC | User, Role, PasswordResetCode | AuthService methods | auth/*, me | SD-01..04 | AuthScreen |
| Needs document confirmation | Route map/create/clear/delete | ManualRoute, RoutePoint DTO | MapService + local clear | map/base, map/manual-routes | SD-05/06 | RoutesScreen |
| Needs document confirmation | Hazard create/view | HazardMarker | MapService create/list | map/markers | SD-07/08 | HazardsScreen |
| Needs document confirmation | AI summary | Run AI fields, AnalysisResult | finish_run/analyze | runs/{id}/finish | SD-09 | RunsScreen |
| Needs document confirmation | Admin users | AdminUserUpdate/Response | list/update users | admin/users | SD-10 | AdminScreen |

## C. SRS to Design

| SRS | Implementing File | Implementing Method | Data Structure | API/UI | Verification Evidence |
|---|---|---|---|---|---|
| Needs document confirmation | `services/auth_service.py` | register/login/reset methods | User/Role/ResetCode | AuthScreen/auth APIs | `test_auth.py`; mobile reset test |
| Needs document confirmation | `services/map_service.py` | get/create/list/delete | ManualRoute/HazardMarker | Routes/Hazards screens | `test_map.py` partly fails on missing validation route |
| Needs document confirmation | `services/run_service.py` | finish_run | Run AI fields | RunsScreen/run finish API | `test_runs.py` happy path |
| Needs document confirmation | `services/admin_service.py` | list_users/update_user | AdminUser schemas | AdminScreen/admin API | No backend test |

## D. Database Relationships

| Parent Model | Relationship | Child Model | Foreign Key | Cardinality | Delete Behavior |
|---|---|---|---|---|---|
| Role | users/back_populates | User | users.role_id | 1:N | restricted/no cascade configured |
| User | emergency_contacts | EmergencyContact | user_id | 1:N | ORM delete-orphan |
| User | hazard_markers | HazardMarker | user_id | 1:N | ORM delete-orphan |
| User | manual_routes | ManualRoute | user_id | 1:N | ORM delete-orphan |
| User | route_plans | RoutePlan | user_id | 1:N | ORM delete-orphan |
| User | runs | Run | user_id | 1:N | ORM delete-orphan |
| User | password_reset_codes | PasswordResetCode | user_id | 1:N | ORM + DB CASCADE |
| HazardMarker | validations | PinValidation | marker_id | 1:N | ORM delete-orphan |
| User | validation user (unidirectional child) | PinValidation | user_id | 1:N implicit | restricted DB FK |
| MapNode | no ORM relation | MapEdge | start/end_node_id | 1:N twice | restricted DB FK |
| ManualRoute | Run.manual_route | Run | manual_route_id nullable | 1:N implicit | service SET NULL before route hard delete |
| RoutePlan | Run.route_plan | Run | route_plan_id nullable | 1:N implicit | restricted unless manually cleared |
| Run | points | RunPoint | run_id | 1:N | ORM delete-orphan; DB FK no cascade |

## E. Router-Service-Model Relationships

| Router | Service | Model/Schema | Purpose |
|---|---|---|---|
| auth | AuthService/EmailService/security | User, Role, ResetCode, auth schemas | identity/reset |
| users | UserService | User, Contact | self profile/contact |
| map | MapService/AdminService | graph, ManualRoute, HazardMarker | map/route/pin/admin PII |
| routes | RouteService | RoutePlan/graph | PII generated routes |
| runs | RunService/AnalysisService | Run/RunPoint | PII tracking + PI AI |
| admin | AdminService | User/Role/Run/Marker/Route | users plus PII dashboard/moderation |

## F. Mobile-to-Backend Relationships

| Flutter Screen | Controller | API Client Method | Backend Path | Response Model |
|---|---|---|---|---|
| AuthScreen | AuthController | register/login/forgot/reset/getMe | auth/*, me | UserProfile/AuthToken/message |
| RoutesScreen | AuthController | getBaseMap/get/create/deleteManualRoute | map/base; map/manual-routes | BaseMapData/ManualRouteItem |
| HazardsScreen | AuthController | getMarkers/createMarker | map/markers | HazardMarkerItem |
| HazardsScreen | AuthController | validateMarker | map/markers/{id}/validate | **missing backend route** |
| RunsScreen | AuthController | run methods | runs/* | RunItem/RunPointItem |
| AdminScreen | AuthController | admin methods | admin/stats/users/markers | AdminStats/AdminUserItem/Marker |

## G. Progress Scope

| Component | Progress I | Progress II | Shared | Reason |
|---|---|---|---|---|
| Auth/RBAC/reset | Yes | No | token dependency shared | Explicit PI |
| Manual route raw save/delete/local clear | Yes | No | map graph used for display/snapping | Explicit PI |
| Hazard create/view/category/severity/note | Yes | No | lifecycle fields returned | Explicit PI |
| AI insight/reasoning | Yes | run tracking substrate | Run model/API shared | Summary is finish-triggered |
| Admin user list/update | Yes | No | stats/count projection mixed | Explicit PI |
| Runs/points/history/stats | No | Yes | AI depends on run finish | Explicit PII |
| Pin validation/lifecycle/moderation | No | Yes | base list filters status | Explicit PII |
| RoutePlan/Dijkstra/OSM/edge admin | No | Yes | graph renders map | Explicit PII |
