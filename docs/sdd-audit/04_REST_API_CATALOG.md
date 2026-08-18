# REST API catalog

Resolution rule: application `/api` (`main.py:45`) + central router prefix (`api/router.py:12-18`) + decorator path. Root `/` is separate.

| API ID | Method | Final Path | Router Function | Authentication | Request Schema | Response Schema | Status Code | Service Method | Progress Scope |
|---|---|---|---|---|---|---|---|---|---|
| API-001 | GET | `/` | root | Public | none | dict | 200 | none | Shared |
| API-002 | GET | `/api/health` | healthcheck | Public | none | dict | 200 | none | Shared |
| API-003 | POST | `/api/auth/register` | register | Public | UserRegister | UserResponse | 201 | AuthService.register | PI |
| API-004 | POST | `/api/auth/login` | login | Public | LoginRequest | TokenResponse | 200 | AuthService.login | PI |
| API-005 | POST | `/api/auth/forgot-password` | forgot_password | Public | ForgotPasswordRequest | GenericMessageResponse | 200 | forgot_password | PI |
| API-006 | POST | `/api/auth/reset-password` | reset_password | Public | ResetPasswordRequest | GenericMessageResponse | 200 | reset_password | PI |
| API-007 | GET | `/api/me` | get_me | Bearer | none | UserResponse | 200 | serializer | Shared |
| API-008 | PUT | `/api/me` | update_me | Bearer/self | UserUpdate | UserResponse | 200 | UserService.update_user | Shared |
| API-009 | GET | `/api/me/emergency-contacts` | list_emergency_contacts | Bearer/self | none | list contact | 200 | list_contacts | Shared |
| API-010 | POST | `/api/me/emergency-contacts` | create_emergency_contact | Bearer/self | EmergencyContactCreate | response | 201 | create_contact | Shared |
| API-011 | GET | `/api/map/` | get_base_map | Public | none | BaseMapResponse | 200 | get_base_map | Shared |
| API-012 | GET | `/api/map/base` | get_base_map_alias | Public | none | BaseMapResponse | 200 | get_base_map | Shared/mobile-used |
| API-013 | POST | `/api/map/import` | import_map | **Public** | query bbox | dict | 200 | import_osm_data | PII |
| API-014 | GET | `/api/map/markers` | list_markers | Public | none | list HazardMarkerResponse | 200 | list_markers | PI view/PII lifecycle |
| API-015 | POST | `/api/map/markers` | create_marker | Bearer | HazardMarkerCreate | HazardMarkerResponse | 201 | create_marker | PI |
| API-016 | GET | `/api/map/manual-routes` | list_manual_routes | Bearer/owner | none | list ManualRouteResponse | 200 | list_manual_routes | PI |
| API-017 | POST | `/api/map/manual-routes` | create_manual_route | Bearer | ManualRouteCreate | ManualRouteResponse | 201 | create_manual_route | PI |
| API-018 | DELETE | `/api/map/manual-routes/{route_id}` | delete_manual_route | Bearer/owner | path int | none | 204 | delete_manual_route | PI |
| API-019 | PUT | `/api/map/edges/{edge_id}/override` | override_edge | Admin | query score/forbidden | dict | 200 | override_edge_risk | PII |
| API-020 | PUT | `/api/map/markers/{marker_id}/approve` | approve_marker | Admin | query approved | dict | 200 | approve_hazard_marker | PII |
| API-021 | POST | `/api/map/rebuild` | rebuild_graph | Admin | none | dict | 200 | rebuild_map_graph | PII |
| API-022 | GET | `/api/map/high-risk-edges` | list_high_risk | Admin | query threshold | inferred list | 200 | list_high_risk_edges | PII |
| API-023 | GET | `/api/routes` | list_routes | Bearer/owner | none | list RoutePlanResponse | 200 | list_routes | PII |
| API-024 | POST | `/api/routes/generate` | generate_route | Bearer | RouteGenerateRequest | RoutePlanResponse | 201 | generate_route | PII |
| API-025 | GET | `/api/runs` | list_runs | Bearer/owner | none | list RunResponse | 200 | list_runs | PII |
| API-026 | POST | `/api/runs/start` | start_run | Bearer | RunStart | RunResponse | 201 | start_run | PII |
| API-027 | GET | `/api/runs/{run_id}` | get_run | Bearer/owner | path int | RunResponse | 200 | get_run | PII/shared AI |
| API-028 | GET | `/api/runs/{run_id}/points` | list_run_points | Bearer/owner | path int | list RunPointResponse | 200 | list_run_points | PII |
| API-029 | POST | `/api/runs/{run_id}/points` | add_run_points | Bearer/owner | list RunPointCreate | list response | 201 | add_run_points | PII |
| API-030 | POST | `/api/runs/{run_id}/finish` | finish_run | Bearer/owner | RunFinish | RunResponse | 200 | finish_run | PII substrate/PI AI |
| API-031 | GET | `/api/admin/stats` | get_stats | Admin | none | AdminStatsResponse | 200 | get_stats | Mixed |
| API-032 | GET | `/api/admin/users` | list_users | Admin | none | list AdminUserResponse | 200 | list_users | PI |
| API-033 | PATCH | `/api/admin/users/{user_id}` | update_user | Admin | AdminUserUpdate | AdminUserResponse | 200 | update_user | PI |
| API-034 | GET | `/api/admin/markers` | list_markers | Admin | `status_filter?` | list marker | 200 | list_markers | PII |
| API-035 | DELETE | `/api/admin/markers/{marker_id}` | delete_marker | Admin | path int | dict | 200 | delete_marker | PII |

## Endpoint detail and client usage

| APIs | Source / parameters and bodies | Errors, dependencies and effects | Tests / mobile / mismatch |
|---|---|---|---|
| 003-006 | `auth.py:26-66`; bodies exactly named schemas | 400/401/422/500 described in method catalog; `get_db`; SMTP only forgot | tests `test_auth.py`; mobile `register/login/forgotPassword/resetPassword`; SDD must use `username_or_email` and generic reset behavior |
| 007-010 | `users.py:11-50`; profile/contact bodies | bearer active check; self-selected by token; commits on writes | `/me` mobile-used by `getMe`; contacts backend-only; outside requested features |
| 011-012 | `map.py:35-54` | no auth; may update expired marker statuses/commit; returns graph and pins | `test_map.py`; mobile calls `/base`; graph belongs PII/shared map rendering |
| 013 | `map.py:57-68`; float bbox defaults 18.79/98.94/18.82/98.97 | no auth/validation bounds; Overpass; deletes existing nodes/edges then inserts; failures propagate sanitized 500 | no test/mobile call; serious public destructive PII endpoint |
| 014-015 | `map.py:71-86`; create schema | public list; authenticated create; list excludes removed/expired | create tested/mobile-used. Public listing must not be documented protected |
| 016-018 | `map.py:89-117`; route ID path; create body | active bearer; owner list/delete; create requires >=2 in service; JSON route insert; delete sets referencing run FK null then hard delete | `test_map.py`; all mobile-used by exact same-named RunnaApi methods |
| 019-022 | `map.py:119-167`; query values | bearer then inline role check; graph/marker writes; score/filter not constrained | no mobile calls/tests; PII only |
| 023-024 | `routes.py:12-30` | bearer owner; Dijkstra plan create/read | `test_routes.py`; mobile methods/screens not the Progress I custom-route flow |
| 025-030 | `runs.py:12-79` | bearer/owner; active status validation; point/stat writes; finish calls Gemini | `test_runs.py`; all mobile-used; AI has no standalone endpoint |
| 031 | `admin.py:32-39` | bearer/admin; aggregate reads | mobile dashboard; no backend test; mixed/PII counts |
| 032-033 | `admin.py:42-74`; user ID and optional patch fields | bearer/admin; 404/400; role/user reads and commit | mobile `getAdminUsers`, `updateAdminUser`; no self/last-admin rule |
| 034-035 | `admin.py:77-98`; optional status and ID | bearer/admin; soft remove | mobile-used moderation; PII; no test |

FastAPI/Pydantic commonly returns 422 for invalid request/query/path values. HTTPBearer returns an authentication error when the Authorization header is absent. The global exception handler returns a generic 500 but logs a server traceback and URL.

## Classification and missing Clear/validate endpoints

Public: 001-006, 011-015(list only; creation protected), and dangerously 013. Authenticated/owner: 007-010, 015-018, 023-030. Admin-only: 019-022 and 031-035. Mobile-used are 002-008, 012, 014-018, 023-035 except 019-022; backend/test-only include contacts, import, inline map-admin routes. Implemented but unused client-side includes `/api/map/` alias.

**Clear Current Route Points has no backend endpoint.** `RoutesScreen` clears `_draftPoints` locally with `setState`; no HTTP call or persistence occurs. Also, `/api/map/markers/{id}/validate` is **not implemented**, despite mobile method/test references.
