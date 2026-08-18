# Runna source-code audit: project overview

Audit basis: current source, Alembic migrations, tests, and configuration inspected 2026-07-17. Existing documents are comparison material only. Paths and line numbers refer to the audited checkout.

## Actual architecture

Runna is a Flutter client calling a synchronous FastAPI REST API. FastAPI route functions obtain a request-scoped SQLAlchemy `Session`; service classes contain most persistence logic; SQLAlchemy 2 declarative models target PostgreSQL through psycopg. Alembic owns schema history. Flutter uses one application-wide `AuthController extends ChangeNotifier`, direct stateful-screen state, an HTTP `RunnaApi`, `shared_preferences` token persistence, `flutter_map`/OpenStreetMap tiles, geolocator, SMTP for reset mail, Overpass/overpy for optional import, and Google Gemini for run analysis.

Startup is `app.main:app`: FastAPI lifespan opens a session, calls `seed_initial_data`, closes it, then serves. Seeding creates roles, a configured/default admin, a demo road graph and possibly demo hazards. `api_router` is mounted at `/api`; its seven child prefixes are `/health`, `/auth`, `/me`, `/map`, `/runs`, `/routes`, and `/admin`. Root `/` is outside `/api`.

Sessions are created by `SessionLocal(autocommit=False, autoflush=False)` and closed by `get_db`; the dependency does **not** roll back automatically. Services explicitly commit, refresh and sometimes roll back. CORS is hard-coded in `main.py`; parsed `settings.cors_origins` is unused.

## Component catalog

| Component | Source File | Main Responsibility | Connected Components | Progress Scope |
|---|---|---|---|---|
| FastAPI application | `backend/app/main.py:16-58` | Startup seed, CORS, exception envelope, root, `/api` mount | router, settings, session, seed | Shared |
| Central router | `backend/app/api/router.py:11-18` | Registers all backend routers | seven route modules | Shared |
| DB lifecycle | `backend/app/api/deps.py:8-13`; `db/session.py:6-7` | Yield/close sessions; engine/session factory | every service | Shared |
| Authentication | `api/routes/auth.py:26-66`; `services/auth_service.py:21-186` | Register, login, reset, bearer identity | User, Role, reset code, email, JWT | Progress I |
| User/profile | `api/routes/users.py:11-50` | Current profile and emergency contacts | UserService | Shared; contacts outside stated PI |
| Map/manual route/hazard | `api/routes/map.py:35-167`; `services/map_service.py:24-325` | Public map/pins; owned saved routes; admin graph/moderation | map models, ManualRoute, HazardMarker | Mixed PI/PII |
| Generated routes | `api/routes/routes.py:12-30`; `services/route_service.py:16-165` | Dijkstra-like generated route plans | graph, RoutePlan | Progress II |
| Runs and AI | `api/routes/runs.py:12-79`; `services/run_service.py:27-391`; `analysis_service.py:14-255` | Tracking, points, statistics, finish-time Gemini summary | Run, RunPoint, Gemini | AI summary PI; tracking substrate PII |
| Admin | `api/routes/admin.py:32-98`; `services/admin_service.py:16-163` | Stats, users, marker moderation | User/Role/Run/Marker/Route | User management PI; rest PII/shared |
| Flutter app shell | `mobile/lib/main.dart:12-124` | Owns controller and six-tab navigation | all screens | Shared |
| Flutter state | `mobile/lib/features/auth/auth_controller.dart:7-280` | Token/current user and API facade | shared_preferences, RunnaApi | Shared |
| Flutter transport | `mobile/lib/core/runna_api.dart:7-438` | JSON HTTP calls and error extraction | backend `/api` | Shared |
| Route UI | `mobile/lib/features/routes/routes_screen.dart:10-363` | Map, local points, save/list/delete | controller/manual-route API | Progress I |
| Hazard UI | `mobile/lib/features/hazards/hazards_screen.dart:9-293` | Public pins and authenticated creation; also validation UI | map/pin APIs | PI plus PII validation |
| Run UI | `mobile/lib/features/runs/runs_screen.dart:56-1140` | GPS tracking, history, statistics and AI display | geolocator/run APIs | AI display PI; remainder PII |
| Admin UI | `mobile/lib/features/admin/admin_screen.dart:7-306` | Users plus stats and moderation | admin APIs | Mixed PI/PII |
| ORM metadata | `backend/app/db/base.py:4-5`; `models/__init__.py:1-29` | Declarative registry and model imports | Alembic env | Shared |
| Alembic | `backend/alembic/env.py:1-49`; `versions/*.py` | Seven linear revisions | PostgreSQL | Shared |
| Backend tests | `backend/tests/*.py` | Auth/reset, health, map, generated routes, runs | TestClient/SQLite | Mixed |
| Mobile tests | `mobile/test/*.dart` | Reset UI and smoke widget | mocked HTTP | Progress I/shared |

## Implemented flows

- Authentication: registration assigns `member`; login accepts `username_or_email`, issues HS256 JWT with only `sub` and `exp`; every protected call reloads the user and rejects inactive accounts. Logout is client-only: token/profile are cleared from memory and `shared_preferences`; no server revocation endpoint exists.
- Roles: `get_current_user` authenticates. Admin routes then call `AdminService.require_admin`, while four map-admin endpoints compare `current_user.role.name` inline. There is no reusable member dependency; any active authenticated user, including admin, can call member operations.
- Reset: a six-digit `secrets.randbelow` value is PBKDF2-hashed. Existing codes are invalidated, the new record committed, SMTP attempted, then `delivered_at` is set or the record invalidated. Reset locks user/latest code, requires active user, delivered/unexpired/unused code and fewer than five failed attempts, then hashes the new password and invalidates all outstanding codes in one commit.
- Custom route: taps accumulate only in `_draftPoints`; Clear Points empties that local list and has no API. Save posts name plus raw `{lat,lng}` points. Backend requires at least two points, calculates distance, performs nearest-edge snapping/validation, persists raw/snapped/validation JSON strings, and returns the owned record. Delete checks owner, sets referencing `runs.manual_route_id` to null, then hard-deletes.
- Hazards: public map/pin list returns non-removed, non-expired markers; authenticated create persists category, 1-5 severity, coordinates, optional note and active status. Confirmation/dismissal lifecycle exists but is Progress II.
- AI: there is no independent “generate summary” endpoint. Finishing a run synchronously invokes `AnalysisService.analyze`; structured local text is produced and Gemini may refine it. Three text fields are saved and returned in `RunResponse`; Runs UI displays them. Recommendations are also generated/displayed, but that presentation is explicitly Progress II.
- Admin users: admin lists users and patches `is_active` and/or role (`member|admin`). UI toggles active and changes role. No self-protection, last-admin protection, audit record, or token revocation exists.

## Deployment, tests, and versions

`backend/Dockerfile` runs Python/Uvicorn; `requirements.txt` pins FastAPI, Uvicorn, SQLAlchemy, psycopg, Alembic, Pydantic settings, Passlib, PyJWT, email-validator, pytest/httpx, google-generativeai and overpy. Flutter dependencies/SDK constraints are in `mobile/pubspec.yaml`; the API URL is compile-time `API_BASE_URL` with a Render default. Root and backend environment examples exist; actual `.env` values were not reproduced.

Tests use SQLite with foreign keys and dependency override. Coverage is concentrated on password reset and happy-path map/run routes; no backend admin, RBAC denial, ownership denial, email integration, Gemini parsing, import, or exception-handler tests exist.

## Disconnected, incomplete, or risky modules

- `ensure_real_map` only aliases seed-map creation. `manual_route_to_response` appears unused. `HazardMarkerValidate` and mobile `validateMarker` target `/map/markers/{id}/validate`, but no registered backend decorator implements it; `test_map.py` expects this missing route.
- `MapNode` migration adds `osm_id`, but the ORM model shown has no `osm_id`; OSM service construction must be checked against this mismatch. Map import is public and destructive (clears edges/nodes), although it belongs to Progress II.
- `settings.cors_origins` is parsed but ignored. `admin_service.py` imports `os` unused. `map.py` duplicates `Depends` and contains a commented dependency import.
- RoutePlan/Dijkstra and OSM code are Progress II and must not be used to describe the Progress I custom-route flow.
- Migration `20260615_0005` performs commits and broad exception swallowing inside migration operations; it also repeats columns introduced in `20260417_0005`.

## Document mismatch summary

The implementation uses `/api`, `username_or_email`, JSON-string route points (not a RoutePoint table), client-only Clear Points, public marker listing, owner-only hard deletion with run references set null, finish-run-triggered AI, and PBKDF2 for both passwords and OTPs. Any existing SDD statement to the contrary must be replaced. Progress II tracking, validation/lifecycle, moderation, graph management, Dijkstra, and OSM content must be separated.
