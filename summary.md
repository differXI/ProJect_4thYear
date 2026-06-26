# Runna Project Progress 1 Summary

This summary is based on the source code, tests, README files, architecture notes, and the PDF documents in the project folder. It is written for a Progress 1 presentation, so it focuses on what has been built, how it works, where each part lives, and what still has problems or inaccuracies.

## 1. Project Overview

Runna is a route-centric running application. The main idea is not only to track running performance like Strava or Nike Run Club, but also to make running safer by combining:

- Manual route creation on a real map.
- GPS run tracking with distance, duration, pace, steps, and run history.
- Community hazard pins for unsafe roads, construction, poor lighting, obstacles, accidents, and similar issues.
- AI-based post-run insight using Gemini.
- Admin tools for monitoring users, runs, routes, and hazard pins.

The project is split into:

- `mobile/`: Flutter mobile/web client.
- `backend/`: FastAPI backend API.
- `backend/alembic/`: database migrations.
- `docs/architecture.md`: short architecture explanation.
- PDFs: proposal, SRS, test record, traceability record, and presentation slides.

Current deployed links listed in `README.md`:

- Web frontend: `https://runna-sand.vercel.app/`
- Backend API: `https://runna-backend.onrender.com`
- Swagger docs: `https://runna-backend.onrender.com/docs`

## 2. Technologies Used

Frontend:

- Flutter
- Dart
- `flutter_map` for map rendering
- OpenStreetMap tiles
- `geolocator` for GPS location
- `http` for API calls
- `shared_preferences` for saving JWT token locally

Backend:

- FastAPI
- Python 3.10
- SQLAlchemy ORM
- Pydantic schemas
- Alembic migrations
- JWT authentication with PyJWT
- Password hashing with Passlib
- Optional Gemini API call through `httpx`

Database:

- PostgreSQL/PostGIS in Docker/deployment idea
- SQLite in-memory for tests
- Current ORM stores geometry mostly as JSON strings, not true PostGIS geometry columns yet.

Infrastructure:

- `docker-compose.yml` runs PostGIS database and FastAPI backend.
- `.github/workflows/build_apk.yml` builds Android APK with Flutter and points the app to the Render backend.

## 3. High-Level Architecture

The architecture is:

```text
Flutter App
  |
  | REST API + JWT token
  v
FastAPI Backend
  |
  +-- PostgreSQL/PostGIS database
  +-- Gemini API for AI run analysis
  +-- OpenStreetMap tiles on frontend map
```

Main API prefix is `/api`, configured in `backend/app/main.py` and `backend/app/api/router.py`.

Important route groups:

- `/api/health`
- `/api/auth`
- `/api/me`
- `/api/map`
- `/api/routes`
- `/api/runs`
- `/api/admin`

## 4. Main Completed Progress 1 Work

### 4.1 Authentication and Roles

Status: mostly completed and implemented.

What it does:

- User can register.
- User can log in with username or email.
- Backend returns JWT access token.
- Frontend stores token in `shared_preferences`.
- App restores session on startup by calling `/api/me`.
- Roles exist: guest, member, admin.
- Admin screen only appears for users whose role is `admin`.

Important files:

- `backend/app/api/routes/auth.py`: API endpoints for register and login.
- `backend/app/services/auth_service.py`: register/login logic and current-user lookup.
- `backend/app/services/security.py`: password hashing, password verification, JWT create/decode.
- `backend/app/services/seed_service.py`: seeds roles and default admin account.
- `backend/app/models/user.py`: user database model.
- `backend/app/models/role.py`: role database model.
- `backend/app/schemas/auth.py`: register/login request and token response schemas.
- `backend/app/schemas/user.py`: user response/admin user schemas.
- `mobile/lib/features/auth/auth_controller.dart`: login/logout/session restore state.
- `mobile/lib/features/auth/auth_screen.dart`: login/register/account UI.
- `mobile/lib/core/runna_api.dart`: API calls for auth.

Important functions:

- `AuthService.register()`: checks duplicate username/email, hashes password, assigns member role, saves user.
- `AuthService.login()`: verifies credentials and returns JWT token.
- `get_current_user()`: reads bearer token, decodes JWT, loads active user.
- `hash_password()` / `verify_password()`: password security functions.
- `create_access_token()` / `decode_access_token()`: JWT functions.
- `AuthController.restoreSession()`: reloads saved token and validates it through backend.
- `AuthController.login()` / `logout()`: frontend authentication state.

Presentation explanation:

When a user logs in, Flutter sends username/email and password to FastAPI. FastAPI checks the database, verifies the hashed password, creates a JWT token, and sends it back. Flutter stores this token and includes it in the `Authorization: Bearer ...` header for protected actions like saving routes, tracking runs, and creating hazard pins.

### 4.2 Map and Manual Route Creation

Status: partially completed and working for Progress 1.

What it does:

- Guest/member/admin can view base map.
- Backend seeds a small demo graph around CMU.
- User can tap points on the map to draw a manual route.
- Route is saved with coordinate list.
- Backend calculates approximate distance.
- Backend attempts simple snapping/validation against seeded map edges.
- Saved routes can be listed and deleted.

Important files:

- `backend/app/api/routes/map.py`: map, marker, and manual route endpoints.
- `backend/app/services/map_service.py`: seeded map, manual route save, distance calculation, snapping/validation.
- `backend/app/models/map_node.py`: map node model.
- `backend/app/models/map_edge.py`: map edge model.
- `backend/app/models/manual_route.py`: saved manual route model.
- `backend/app/schemas/map.py`: map node/edge/hazard schemas.
- `backend/app/schemas/manual_route.py`: manual route input/output schemas.
- `mobile/lib/features/routes/routes_screen.dart`: map UI and manual route drawing.
- `mobile/lib/core/models.dart`: `BaseMapData`, `MapNodeItem`, `MapEdgeItem`, `ManualRouteItem`, `RoutePoint`.
- `mobile/lib/core/runna_api.dart`: `getBaseMap()`, `createManualRoute()`, `getManualRoutes()`, `deleteManualRoute()`.

Important functions:

- `MapService.ensure_seed_map()`: creates demo CMU nodes, road edges, and sample hazard markers.
- `MapService.get_base_map()`: returns nodes, edges, and markers to frontend.
- `MapService.create_manual_route()`: receives points, calculates distance, stores route JSON, creates validation JSON.
- `MapService.list_manual_routes()`: gets user saved routes.
- `MapService.delete_manual_route()`: deletes a saved route and unlinks related runs.
- `RoutesScreen._handleMapTap()`: adds tapped map coordinate to current route.
- `RoutesScreen._saveRoute()`: sends drawn points to backend.
- `RoutesScreen._deleteRoute()`: deletes saved route.

Presentation explanation:

The user taps points on the Flutter map. Each tap creates a latitude/longitude point. When saving, the frontend sends the point list to the backend. The backend stores `path_json`, calculates route distance, tries to snap points to nearby road edges, creates validation warnings, and saves the route under the logged-in user.

### 4.3 Route Generation

Status: implemented as a prototype, but not the main completed Progress 1 feature.

What it does:

- Authenticated user can request a generated route.
- Backend uses seeded map graph and a risk-weighted Dijkstra-like method.
- Stores route plan with path JSON, estimated minutes, safety level, and summary.

Important files:

- `backend/app/api/routes/routes.py`
- `backend/app/services/route_service.py`
- `backend/app/models/route_plan.py`
- `backend/app/schemas/route.py`
- `mobile/lib/core/runna_api.dart`
- `mobile/lib/core/models.dart`

Important functions:

- `RouteService.generate_route()`: creates a route plan from start label, distance, type, environment.
- `RouteService._resolve_anchor()`: maps labels like `CMU Main Gate` to coordinates.
- `RouteService._dijkstra_risk_route()`: risk-weighted graph route selection.
- `RouteService.list_routes()`: lists generated routes for a user.

Problem to mention:

This route generation is approximate. It uses a small seeded graph, fixed known locations, and simple risk math. It is useful for demonstration, but it is not yet a full production route planner.

### 4.4 GPS Run Tracking

Status: implemented and central to Progress 1.

What it does:

- User selects a saved manual route.
- User starts a run.
- Backend creates active run record.
- Flutter streams GPS positions.
- Flutter filters points by distance and uploads them to backend.
- User finishes run.
- Backend calculates/stores distance, duration, pace, steps, and AI fields.
- Run history can be viewed.
- If user starts a new run while old one is active, backend auto-closes old active runs.

Important files:

- `backend/app/api/routes/runs.py`: run endpoints.
- `backend/app/services/run_service.py`: run lifecycle, distance, duration, pace, steps, AI call.
- `backend/app/models/run.py`: `Run` and `RunPoint` models.
- `backend/app/schemas/run.py`: run and run point schemas.
- `mobile/lib/features/runs/runs_screen.dart`: running screen, GPS tracking, live metrics, history, summary.
- `mobile/lib/core/location_service.dart`: GPS permission and position stream wrapper.
- `mobile/lib/core/runna_api.dart`: run API calls.
- `mobile/lib/core/models.dart`: `RunItem`, `RunPointItem`, `RunPointUpload`.

Important functions:

- `RunService.start_run()`: creates active run and auto-closes stale active runs.
- `RunService.add_run_points()`: saves GPS points in sequence.
- `RunService.finish_run()`: closes run, calculates stats, requests AI insight.
- `RunService._calculate_distance_km()`: calculates route distance from GPS points.
- `RunService._calculate_duration_seconds()`: calculates elapsed time.
- `RunService._estimate_steps()`: estimates steps from distance using 0.75m stride assumption.
- `RunService._distance_m()`: Haversine distance formula.
- `RunsScreen._startRun()`: starts run from selected route.
- `RunsScreen._startLocationStream()`: starts GPS stream.
- `RunsScreen._handlePosition()`: receives GPS updates and uploads points.
- `RunsScreen._finishRun()`: sends final stats and displays summary.
- `RunsScreen._trackedDistanceKm`: calculates live local distance.

Presentation explanation:

When a run starts, the app creates an active run on the backend. The phone GPS then streams positions. The app only records a new point when the user has moved enough distance, then uploads that point. When finishing, backend calculates distance, duration, average pace, estimated steps, and tries to generate an AI insight.

### 4.5 AI Run Analysis

Status: partially implemented.

What it does:

- Backend collects run stats: distance, duration, steps, pace, recent runs.
- If `GEMINI_API_KEY` is configured, backend calls Gemini.
- Gemini is instructed to return JSON with insight, reasoning, and recommendations.
- Result is saved on the `runs` table.
- Frontend displays AI summary after finishing a run.

Important files:

- `backend/app/services/analysis_service.py`
- `backend/app/services/run_service.py`
- `backend/app/models/run.py`
- `backend/app/schemas/run.py`
- `mobile/lib/features/runs/runs_screen.dart`

Important functions:

- `AnalysisService.analyze()`: requires Gemini API key and starts analysis.
- `AnalysisService._build_structured_summary()`: calculates structured metrics such as pace delta and cadence.
- `AnalysisService._call_gemini()`: calls Gemini model endpoint and parses response.
- `AnalysisService._parse_json_response()`: handles JSON response, including markdown code block cleanup.
- `RunService.finish_run()`: calls `AnalysisService` and stores AI output.
- `_formatAiStatusMessage()` in `runs_screen.dart`: formats AI success/error messages for display.

Important accuracy note:

The architecture docs and PDFs say there is a Gemini fallback/rule-based analysis. In the actual code, if Gemini is missing or fails, the backend stores an `[AI unavailable]` or `[Unexpected AI error]` message. It does not currently generate a real rule-based coaching fallback. So the fallback is planned/documented, but not fully implemented.

### 4.6 Hazard Pin System

Status: partially implemented.

What works:

- Users can create hazard pins.
- Users and guests can view hazard pins.
- Pins have category/type, severity, note, status, confirm count, dismiss count, and expiration field.
- Frontend has UI to report pins.
- Admin can list and remove pins.

Important files:

- `backend/app/api/routes/map.py`: marker create/list endpoints.
- `backend/app/services/map_service.py`: marker create/list logic.
- `backend/app/models/hazard_marker.py`: hazard marker table.
- `backend/app/models/pin_validation.py`: validation/vote table model.
- `backend/app/schemas/map.py`: marker schemas.
- `mobile/lib/features/hazards/hazards_screen.dart`: hazard map/list/create/validate UI.
- `mobile/lib/features/routes/routes_screen.dart`: displays hazard pins on route map.
- `mobile/lib/features/runs/runs_screen.dart`: displays hazards during run.
- `mobile/lib/core/runna_api.dart`: marker API calls.

Important functions:

- `MapService.create_marker()`: saves a new hazard pin.
- `MapService.list_markers()`: returns active/non-removed pins.
- `HazardsScreen._createPin()`: frontend hazard creation.
- `HazardsScreen._validatePin()`: frontend calls validation endpoint.
- `AdminService.delete_marker()`: marks marker as removed.
- `AdminService.approve_hazard_marker()`: admin approve/remove helper.

Current major problem:

The frontend and tests call:

```text
POST /api/map/markers/{marker_id}/validate
```

But `backend/app/api/routes/map.py` does not implement this endpoint. The data model `PinValidation` exists, and the schema `HazardMarkerValidate` exists, but the route/service method to update `confirm_count` and `dismiss_count` is missing.

Presentation-safe explanation:

Hazard creation and viewing are implemented. The confirmation/dismiss lifecycle is designed in the database and UI, but the backend validation endpoint still needs to be completed for Progress 2 or before final demo.

### 4.7 Admin Dashboard

Status: partially completed and working for key admin actions.

What it does:

- Admin-only route protection.
- Admin can view platform stats.
- Admin can list users.
- Admin can activate/deactivate users.
- Admin can change member/admin role.
- Admin can list hazard markers.
- Admin can remove hazard markers.
- Extra backend-only map admin operations exist for edge override, marker approval, graph rebuild, high-risk edges.

Important files:

- `backend/app/api/routes/admin.py`: admin endpoints.
- `backend/app/services/admin_service.py`: admin logic.
- `backend/app/schemas/user.py`: admin response/update schemas.
- `mobile/lib/features/admin/admin_screen.dart`: admin UI.
- `mobile/lib/features/auth/auth_controller.dart`: admin API wrappers.
- `mobile/lib/core/runna_api.dart`: admin API calls.

Important functions:

- `AdminService.require_admin()`: checks user role.
- `AdminService.get_stats()`: counts users, runs, pins, routes.
- `AdminService.list_users()`: returns users with run/pin counts.
- `AdminService.update_user()`: toggles active status or role.
- `AdminService.list_markers()`: lists pins for moderation.
- `AdminService.delete_marker()`: marks pin as removed.
- `AdminScreen._loadStats()`, `_loadUsers()`, `_loadMarkers()`: load dashboard data.
- `AdminScreen._toggleUser()`, `_changeRole()`, `_removeMarker()`: admin actions.

Known issue:

`AdminService.list_users()` uses two outer joins and `count(Run.id)` + `count(HazardMarker.id)` in one query. If a user has multiple runs and multiple pins, counts can multiply because of join duplication. For accurate production stats, this should use distinct counts or subqueries.

## 5. Database Schema Overview

Main models:

- `Role`: `guest`, `member`, `admin`.
- `User`: account info, password hash, province, active status, role.
- `EmergencyContact`: contact details linked to user.
- `MapNode`: map graph node with lat/lng.
- `MapEdge`: road segment with class, speed, length, risk score, geometry JSON.
- `HazardMarker`: user-created hazard pin.
- `PinValidation`: user vote/validation for marker.
- `ManualRoute`: user-drawn route stored as JSON path.
- `RoutePlan`: generated/prototype route plan.
- `Run`: running session with stats and AI fields.
- `RunPoint`: GPS points uploaded during a run.

Important migration files:

- `20260417_0001_create_auth_tables.py`: roles, users, emergency contacts.
- `20260417_0002_create_gis_and_run_tables.py`: map nodes/edges, hazard markers, manual routes, runs.
- `20260417_0003_create_route_plans.py`: route plans.
- `20260417_0004_add_route_geometry.py`: route geometry fields.
- `20260417_0005_add_run_analysis_and_pin_lifecycle.py`: manual route validation, run AI fields, pin lifecycle fields, pin validations.
- `20260615_0005_add_run_points.py`: run points, route plan link, extra compatibility fields.

Migration caution:

`20260615_0005_add_run_points.py` uses `safe_add_column()` and catches exceptions because there were migration conflicts/duplicate columns. This helps deployment survive, but it is not as clean as a normal Alembic migration chain.

## 6. How Main User Flows Work

### Flow A: Register/Login

1. User enters form in `AuthScreen`.
2. `AuthController` calls `RunnaApi.register()` or `RunnaApi.login()`.
3. Backend route in `auth.py` calls `AuthService`.
4. Backend stores user or verifies password.
5. Login returns JWT.
6. Flutter stores JWT in shared preferences.
7. Protected requests include `Authorization: Bearer <token>`.

### Flow B: Create Manual Route

1. User opens Routes tab.
2. `RoutesScreen._load()` gets base map and existing manual routes.
3. User taps map; `_handleMapTap()` adds `RoutePoint`.
4. User taps Save route.
5. `_saveRoute()` calls `createManualRoute()`.
6. Backend `MapService.create_manual_route()` calculates distance, snapping, validation, and saves route.
7. Saved route appears in list.

### Flow C: Start and Finish Run

1. User selects saved manual route in Runs tab.
2. `_startRun()` calls backend `/api/runs/start`.
3. Backend `RunService.start_run()` creates active run.
4. `_startLocationStream()` starts GPS stream.
5. `_handlePosition()` uploads GPS point to `/api/runs/{run_id}/points`.
6. UI updates map polyline, timer, distance, pace, and route progress.
7. User taps finish.
8. `_finishRun()` sends final distance/duration/steps to backend.
9. Backend `RunService.finish_run()` calculates stats and AI insight.
10. UI displays run summary and AI result.

### Flow D: Hazard Pin

1. User opens Hazards tab.
2. Taps map to choose location.
3. Selects category and severity.
4. `_createPin()` calls `/api/map/markers`.
5. Backend `MapService.create_marker()` saves marker.
6. Marker appears on Hazards, Routes, and Runs maps.
7. Planned validation flow is `Still there` / `Resolved`, but backend endpoint is missing right now.

### Flow E: Admin Management

1. Admin logs in.
2. `main.dart` shows Admin tab only if `controller.isAdmin`.
3. Admin tab calls `/api/admin/stats`, `/api/admin/users`, `/api/admin/markers`.
4. Admin can toggle users, change roles, and remove hazard pins.
5. Backend checks role using `AdminService.require_admin()`.

## 7. File Guide: Which File Tells About What

Root:

- `README.md`: project overview, deployment links, main features, technologies.
- `docker-compose.yml`: local database/backend runtime.
- `.env.example`: expected environment variables.
- `docs/architecture.md`: concise architecture and subsystem explanation.

Backend core:

- `backend/app/main.py`: creates FastAPI app, CORS, startup seed, root endpoint.
- `backend/app/api/router.py`: connects all API route modules.
- `backend/app/api/deps.py`: database session dependency.
- `backend/app/core/config.py`: environment settings.
- `backend/app/db/session.py`: SQLAlchemy engine/session.
- `backend/app/db/base.py`: SQLAlchemy base class.

Backend route files:

- `auth.py`: register/login.
- `users.py`: current profile and emergency contacts.
- `map.py`: base map, markers, manual routes, admin map controls.
- `routes.py`: generated route plans.
- `runs.py`: run start/finish/points/history.
- `admin.py`: admin stats/users/markers.
- `health.py`: health check.

Backend service files:

- `auth_service.py`: auth business logic.
- `security.py`: JWT and password helpers.
- `seed_service.py`: seeds roles/admin/map.
- `map_service.py`: seeded map, hazard markers, manual route logic.
- `route_service.py`: prototype route generation.
- `run_service.py`: run lifecycle and metrics.
- `analysis_service.py`: Gemini AI analysis.
- `admin_service.py`: admin statistics and moderation.
- `user_service.py`: profile and emergency contact logic.

Mobile core:

- `mobile/lib/main.dart`: app startup, navigation tabs, admin tab visibility.
- `mobile/lib/core/app_config.dart`: API base URL.
- `mobile/lib/core/runna_api.dart`: all HTTP calls.
- `mobile/lib/core/models.dart`: Dart data models matching backend JSON.
- `mobile/lib/core/location_service.dart`: GPS permissions and stream.
- `mobile/lib/core/theme.dart`: colors, theme, reusable card/title widgets.

Mobile feature screens:

- `auth_screen.dart`: login/register/account UI.
- `auth_controller.dart`: auth state and API facade.
- `home_screen.dart`: dashboard and quick actions.
- `routes_screen.dart`: map route drawing and saved route list.
- `runs_screen.dart`: GPS run tracking, live metrics, finish summary, AI display, history.
- `hazards_screen.dart`: hazard pin create/list/validate UI.
- `admin_screen.dart`: admin dashboard.

Tests:

- `backend/tests/test_auth.py`: register/login.
- `backend/tests/test_health.py`: health endpoint.
- `backend/tests/test_map.py`: base map, manual route, marker, expected marker validation.
- `backend/tests/test_routes.py`: route generation/list.
- `backend/tests/test_runs.py`: run start/finish and GPS points.
- `mobile/test/widget_test.dart`: auth screen render test.

PDFs/docs:

- `Runna Route-Centric Running Application.pdf`: Progress 1 presentation slides.
- `Runna_Software Requirement Specification_V.1.0.0 (5).pdf`: SRS, use cases, requirements, progress percentages.
- `Runna_Test Record_V.1.0.0 (4).pdf`: test plan and test records.
- `Runna_Traceability Record_V.1.0.0 (4).pdf`: maps requirements to use cases, UI, methods, and tests.
- `Runna_Project_extracted.txt`: extracted project proposal text.

## 8. Progress 1 Completion Snapshot

Based on code and PDFs:

| Feature | Claimed/Documented Progress 1 | Actual Code Status |
| --- | ---: | --- |
| Authentication and roles | 100% | Implemented: register, login, JWT, roles, admin visibility |
| Manual route creation | 50% | Implemented: map view, tap route, save/list/delete; route editing is basic |
| GPS run tracking | 40%-50% depending document context | Implemented: start, stream points, finish, history, stats |
| Hazard pin system | 60% | Create/view/admin remove works; confirm/dismiss endpoint missing |
| AI run summary | 65% | Gemini call implemented; real fallback analysis not implemented |
| Admin dashboard | 35% | Stats/users/role toggle/pin remove implemented; route admin incomplete |

## 9. Testing and Verification Results

Backend test command attempted:

```powershell
.\.venv\Scripts\python.exe -m pytest -q
```

Result:

- Backend tests did not start.
- Import error: `tests/conftest.py` imports `PinValidation` from `app.models`, but `backend/app/models/__init__.py` does not export `PinValidation`.

Specific issue:

- `backend/app/models/pin_validation.py` exists.
- `backend/app/models/__init__.py` imports/exports many models, but not `PinValidation`.
- Because of this, pytest fails before running actual tests.

Flutter test command attempted:

```powershell
C:\Users\User\.puro\envs\stable\flutter\bin\flutter.bat test
```

Result:

- Flutter test ran but failed.
- Error: `No Material widget found`.
- Cause: `mobile/test/widget_test.dart` renders `AuthScreen` directly under `MaterialApp`, but `AuthScreen` contains `TextField`/`TextFormField` and needs a `Scaffold` or `Material` ancestor in the test.
- This is mostly a test setup issue, not necessarily an app runtime issue, because the real app in `main.dart` wraps pages inside a `Scaffold`.

Other expected future failure:

- If backend tests get past the import error, `test_map.py` likely fails because it tests `/api/map/markers/{marker_id}/validate`, which is missing in backend routes.

## 10. Problems, Inaccuracies, and Risks

### Problem 1: Missing hazard validation backend endpoint

Frontend and tests expect:

```text
POST /api/map/markers/{marker_id}/validate
```

But backend does not implement it.

Impact:

- `Still there` and `Resolved` buttons in Hazards screen cannot work correctly.
- Confirm/dismiss counts will not update.
- Hazard lifecycle is incomplete.
- Test record and presentation say validation exists, but actual backend is missing the endpoint.

### Problem 2: `PinValidation` model is not exported

`backend/tests/conftest.py` imports `PinValidation` from `app.models`, but `backend/app/models/__init__.py` does not include it.

Impact:

- Backend tests cannot run.
- Easy fix: import `PinValidation` in `backend/app/models/__init__.py` and add it to `__all__`.

### Problem 3: AI fallback is documented but not real yet

Docs/slides say fallback/rule-based analysis exists. Actual code stores an unavailable/error message when Gemini fails.

Impact:

- Users do not receive useful offline/fallback coaching advice.
- Presentation should say Gemini integration is implemented, but fallback rule engine still needs completion.

### Problem 4: OSM import code references missing dependency and missing model column

`MapService.import_osm_data()` imports `overpy`, but `overpy` is not in `backend/requirements.txt`.

It also creates `MapNode(osm_id=...)`, but `backend/app/models/map_node.py` does not define `osm_id`, even though migration `20260615_0005_add_run_points.py` tries to add the column.

Impact:

- `/api/map/import` is likely broken.
- Current app works because it uses seeded map data, not real OSM import.

### Problem 5: Manual route snapping/risk validation is approximate

In `MapService.create_manual_route()`:

- Snapping uses edge midpoint, not real nearest-point-on-polyline geometry.
- Distance uses rough latitude/longitude conversion.
- Risky edge counting checks any high-risk edge after a point is near any edge, not necessarily the actual snapped edge.
- Buffer comment says 5m but code uses `0.005` degrees, which is much larger than 5m.

Impact:

- Good for prototype/demo.
- Not accurate enough for production route safety validation.

### Problem 6: Route generation math is approximate

`RouteService._dijkstra_risk_route()` uses a rough cost/distance calculation and may return short/simple paths.

Impact:

- Generated route feature is a prototype.
- Manual route creation is stronger for Progress 1.

### Problem 7: Admin user counts may be inaccurate

`AdminService.list_users()` joins users to runs and hazard markers in one query. Counts can multiply if a user has multiple runs and multiple pins.

Impact:

- Admin dashboard counts per user may be inflated.
- Use distinct counts or subqueries later.

### Problem 8: Password reset is documented but not implemented

SRS/traceability mentions password reset under authentication. Actual backend/mobile code does not include password reset endpoints/screens.

Impact:

- For presentation, do not claim password reset is finished unless separately implemented elsewhere.

### Problem 9: SRS details do not always match implementation

Examples:

- SRS says JWT expiration is 24 hours. Code default is `ACCESS_TOKEN_EXPIRE_MINUTES=60`.
- SRS says password hashing applies salt factor 10. Code uses `pbkdf2_sha256`, not bcrypt cost factor 10.
- SRS says route persistence uses GeoJSON LineString. Code stores JSON arrays of points in string columns.
- SRS says spatial queries fetch hazard pins in map bounding box. Code currently returns all non-removed markers.

Impact:

- Documents describe target design more than exact current implementation.
- Presentation should separate "implemented now" from "planned/final requirement".

### Problem 10: Mobile widget test setup is wrong

`mobile/test/widget_test.dart` should wrap `AuthScreen` in `Scaffold` or `Material`.

Impact:

- Flutter test currently fails even though app runtime structure has `Scaffold` in `main.dart`.

## 11. What You Can Say in Progress 1 Presentation

Short version:

Runna Progress 1 delivered the main app foundation: Flutter frontend, FastAPI backend, JWT auth, user roles, manual route creation, GPS run tracking, run history, Gemini AI integration, hazard pin creation/viewing, and admin monitoring. The system already connects frontend and backend through real REST APIs and stores data through SQLAlchemy models and migrations.

More detailed version:

- We built the client-server architecture.
- The mobile app can register/login users and restore sessions.
- The map screen displays OpenStreetMap tiles and seeded route graph data.
- Members can draw routes by tapping map points and save them.
- Members can start a run, stream GPS points, finish the run, and view distance/pace/steps.
- The backend can call Gemini to generate post-run insights.
- Members can create hazard pins and see them on maps.
- Admins can manage users and remove hazard pins.
- Tests and documents exist, but some tests currently reveal incomplete backend integration.

Be honest about incomplete parts:

- Hazard validation confirm/dismiss is designed but missing backend endpoint.
- AI fallback is not fully rule-based yet.
- OSM import and route generation are prototype-level.
- Some SRS claims describe final goals rather than exact current code.

## 12. Best Demo Path

For a stable Progress 1 demo:

1. Open app/web.
2. Register or log in.
3. Show Home screen stats.
4. Go to Routes and show map.
5. Tap points and save a manual route.
6. Go to Runs and start a run from saved route.
7. Show tracking UI, distance/timer/map.
8. Finish run and show summary/AI section.
9. Go to Hazards and create a hazard pin.
10. Log in as admin and show admin dashboard stats/users/pins.

Avoid depending on:

- Hazard `Still there` / `Resolved` validation until backend endpoint is implemented.
- `/api/map/import` OSM import endpoint.
- Fully accurate generated route planning.
- Automated tests passing without fixes.

## 13. Suggested Fixes Before Presentation

Highest priority:

1. Export `PinValidation` in `backend/app/models/__init__.py` so backend tests can start.
2. Implement `/api/map/markers/{marker_id}/validate`.
3. Fix `mobile/test/widget_test.dart` by wrapping `AuthScreen` in `Scaffold`.
4. Decide how to present AI fallback honestly: either implement rule fallback or say fallback is currently an error-safe response.

Medium priority:

1. Add `overpy` to requirements or disable/document `/api/map/import`.
2. Add `osm_id` to `MapNode` model if using OSM import.
3. Fix admin count query with distinct counts.
4. Improve manual route snapping accuracy.
5. Align SRS wording with actual implementation.

## 14. Progress 1 Function List Cheat Sheet

Authentication:

- `AuthService.register()` creates users.
- `AuthService.login()` authenticates users.
- `get_current_user()` protects routes.
- `create_access_token()` creates JWT.
- `AuthController.restoreSession()` restores login in Flutter.

Routes and map:

- `MapService.ensure_seed_map()` creates demo map data.
- `MapService.get_base_map()` returns map nodes/edges/markers.
- `MapService.create_manual_route()` saves user-drawn route.
- `MapService.delete_manual_route()` deletes route.
- `RouteService.generate_route()` creates prototype generated route.

Runs:

- `RunService.start_run()` starts active run.
- `RunService.add_run_points()` saves GPS points.
- `RunService.finish_run()` finishes run and calculates stats.
- `RunService._calculate_distance_km()` calculates distance.
- `RunService._estimate_steps()` estimates steps.
- `RunsScreen._handlePosition()` receives and uploads GPS location.

AI:

- `AnalysisService.analyze()` begins AI analysis.
- `AnalysisService._build_structured_summary()` prepares metrics.
- `AnalysisService._call_gemini()` calls Gemini.
- `AnalysisService._parse_json_response()` parses Gemini output.

Hazards:

- `MapService.create_marker()` creates hazard pin.
- `MapService.list_markers()` lists hazard pins.
- `HazardsScreen._createPin()` frontend pin creation.
- `HazardsScreen._validatePin()` frontend validation call, currently blocked by missing backend endpoint.

Admin:

- `AdminService.require_admin()` checks role.
- `AdminService.get_stats()` dashboard totals.
- `AdminService.list_users()` user list.
- `AdminService.update_user()` active/role changes.
- `AdminService.delete_marker()` removes marker.

