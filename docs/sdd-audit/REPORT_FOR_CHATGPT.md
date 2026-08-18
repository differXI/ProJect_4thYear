# Runna SDD rewrite handoff

This is the consolidated source-of-truth handoff. Detailed evidence is in the nine sibling reports; do not use older documents to override it.

## 1-5. Repository, technologies, startup, prefix, routers

Repository: `backend/app/{api,core,db,models,schemas,services}`, seven Alembic versions, five backend test modules; `mobile/lib/{core,features}` with six screens and two test files; deployment/config at backend Docker/requirements and Flutter pubspec/workflows.

Backend is FastAPI + Uvicorn, SQLAlchemy 2, PostgreSQL/psycopg, Alembic, Pydantic v2 settings, Passlib, PyJWT, SMTP, overpy, Gemini. Mobile is Flutter/Dart with http, shared_preferences, flutter_map/OSM tiles and geolocator. Exact pinned versions are in `backend/requirements.txt`, `mobile/pubspec.lock`, and SDK constraint in `pubspec.yaml`; cite those files rather than guessing.

`app.main:app` runs lifespan → `SessionLocal` → `seed_initial_data` → close → serve. CORS and a generic exception handler are installed. `api_router` mounts at **`/api`**. Child routers: health `/health`, auth `/auth`, users `/me`, map `/map`, runs `/runs`, generated routes `/routes`, admin `/admin`. Root `/` is outside the prefix.

## 6. Final endpoints

There are 35 registered operations including root: `/`; `/api/health`; auth register/login/forgot-password/reset-password; GET/PUT `/api/me`; contact list/create; map `/` and `/base`, import, marker list/create, manual-route list/create/delete, edge override, marker approve, rebuild, high-risk edges; generated route list/generate; run list/start/get/point list/add/finish; admin stats/user list/update/marker list/delete. Exact method/path/auth/status/schema table: `04_REST_API_CATALOG.md`.

Notably absent: logout, Clear Points, standalone AI generation, and marker validation. Mobile/tests call the absent marker validation endpoint.

## 7-10. Model, schema, Flutter, service/method catalogs

ORM models: Role, User, EmergencyContact, HazardMarker, ManualRoute, MapNode, MapEdge, PinValidation, RoutePlan, Run, RunPoint, PasswordResetCode. There is **no manual RoutePoint table**. Data attributes, nullability, indexes, uniqueness, FKs, cascade and migration mapping are in `02_DATA_STRUCTURES.md`.

Pydantic: six auth DTOs; contact create/response; manual route point/create/validation/response; map node/edge/hazard create/validate/response/base; route generate/response; run start/finish/point create/point response/run response; user/user update/admin user response/update/stats. `HazardMarkerValidate` is disconnected.

Flutter DTOs: HealthResponse, AuthToken, UserProfile, RunItem, RunPointItem/Upload, RoutePoint (transient DTO), RoutePlanItem, MapNodeItem, MapEdgeItem, HazardMarkerItem, BaseMapData, ManualRouteItem, AdminStats, AdminUserItem. State is a global `AuthController extends ChangeNotifier` plus StatefulWidget-local state. Screens: Home, Auth, Routes, Runs, Hazards, Admin.

Services: AuthService, EmailService, MapService, RouteService, RunService, AnalysisService, AdminService, UserService, seed/security functions. Every router/dependency/service/security/startup/serializer/mobile method and exact line range is cataloged in `03_METHOD_CATALOG.md`.

## 11-12. Relationships and migration history

Role 1:N User; User 1:N contacts/hazards/manual routes/route plans/runs/reset codes; Marker 1:N validations; MapNode referenced twice by edges; ManualRoute and RoutePlan optionally referenced by Runs; Run 1:N RunPoint. User relationships mostly use ORM delete-orphan. Reset code has DB CASCADE. Manual-route deletion explicitly sets run references null before hard delete. Full matrix: `06_RELATIONSHIP_SUMMARY.md`.

Linear revisions: `20260417_0001` auth/contact; `0002` graph/hazard/manual route/run; `0003` RoutePlan; `0004` route geometry; `0005` manual snapping/validation + run AI/lifecycle/PinValidation; `20260615_0005` run points/route references and repeated additions; `20260715_0006` reset codes. The 20260615 migration commits inside upgrade and swallows broad failures; `osm_id`/ORM drift exists.

## 13-18. Actual feature designs

- Authentication: register checks username/email and assigns member; PBKDF2-SHA256. Login accepts `username_or_email`, verifies PBKDF2 and emits HS256 JWT `sub`/`exp`. Protected dependency decodes, loads and enforces active. Logout only clears client memory/shared_preferences.
- Password reset: generic forgot response; lock active user; CSPRNG six digits; PBKDF2 hash; invalidate prior; commit; SMTP; mark delivered or invalidate. Reset locks active user/latest delivered/unexpired/unused record, permits while attempts `<5`, commits wrong count, or atomically hashes password/invalidates codes.
- Custom route: draft taps local; Clear local only. Save raw point array; service requires two, calculates distance, snaps/validates against graph and stores raw/snapped/validation JSON strings. Delete is owner-only 404 concealment, sets run FK null and hard deletes.
- Hazards: public listing; authenticated create with category string, severity 1..5, coordinate, optional note. Lifecycle/validation/moderation are PII.
- AI: no independent endpoint. Finish-run computes metrics, invokes deterministic/Gemini analysis, persists insight/reasoning/recommendations, returns RunResponse; Runs UI displays. Recommendation presentation is PII by instructed scope.
- Admin users: admin-only list and patch active/role member/admin. No self/last-admin safeguard. Joined counts may multiply.

## 19-20. Sequences and matrices

Exactly ten complete PlantUML and Mermaid specifications are in `05_SEQUENCE_DIAGRAM_SPECIFICATIONS.md`: Register, Login, Request Reset, Reset, Save Custom Route, Delete Route, Create Pin, View Pins, Generate AI Summary, Manage Users. Use-case/URS/SRS, DB, router-service-model, mobile-backend and scope matrices are in `06_RELATIONSHIP_SUMMARY.md`. Unknown document IDs are deliberately marked `Needs document confirmation`.

## 21. Security findings

PASS: PBKDF2, CSPRNG OTP, JWT signature/expiry, protected active check, admin/owner checks, enumeration-safe text, reset binding/delivery/expiry/reuse/attempt locks, ORM queries, UI loading/disposal.

Critical/high: public destructive OSM import; unsafe development default JWT/admin/DB credentials and debug true; token in shared_preferences; admin may demote/deactivate self/last admin; Gemini/error prints and exception text; migration drift; production TLS requires manual verification. Partial: no global rollback, timing difference, missing input bounds/rate limits, no server logout, hard-coded CORS ignoring settings. Full table: `07_SECURITY_DESIGN_AUDIT.md`.

## 22. Test coverage

Backend tests cover health, register/login/reset extensively, a custom route create/delete and pin create plus **missing validation route**, generated route happy path, run start/finish/points. Mobile tests cover password-reset UI and a smoke/health path. Missing: admin/RBAC denial, ownership denial, AI/Gemini unit behavior, email integration, OSM/import, CORS/config, logout persistence security, migration fresh-upgrade integration. Executed results must be appended/consulted from final verification status, not assumed.

## 23-24. Progress I versus II

Progress I detailed design: Registration, Login, local Logout, Forgot/Reset, RBAC, view map, manual custom route save/local clear/delete, hazard create/view/core fields, AI run insight/reasoning trigger/display, admin user management.

Progress II inventory only: run tracking/stats/history/GPS points; pin confirm/dismiss/lifecycle; AI recommendation presentation; admin hazard moderation; route/map-edge admin; Dijkstra generation/RoutePlan; OSM import. Component-by-component mapping: `08_PROGRESS_SCOPE_MAPPING.md`.

## 25. Corrections to current SDD

Highest severity corrections: `/api` paths; `username_or_email`; exact User/Role; no persistent route points; Clear Points local; route hard delete with run set-null; marker list public; marker validation missing; AI triggered by finish rather than standalone; local-only logout; admin lacks invariants; reset delivery/attempt/transaction details; PBKDF2; CORS hard-coded; unsafe defaults; Gemini logging; Progress II separation. Full correction table: `09_DOCUMENT_CORRECTIONS.md`.

## 26. Open questions requiring manual confirmation

1. Which exact UC/URS/SRS identifiers correspond to each named feature? Source does not encode them.
2. Which existing SDD/SRS/Test Plan/Traceability/Test Record versions are authoritative comparison editions if multiple copies exist?
3. Is production guaranteed to override all insecure defaults, set debug false, use HTTPS, and protect SMTP/Gemini/JWT credentials?
4. Is missing marker validation intentionally removed or an implementation regression?
5. Should PI “AI Run Summary” include reasoning but exclude recommendations exactly as the scope statement implies?
6. Is public map import intentional? It is currently destructive and unauthenticated.
7. Are PostgreSQL migrations known to upgrade cleanly from an empty database despite duplicate-safe migration logic?

## 27. Recommended SDD rewrite order

1. Freeze PI/PII boundary and requirement IDs.
2. Correct architecture, `/api` router tree, session/startup/deployment.
3. Replace data design/ERD with actual models and JSON route structures.
4. Rewrite auth/RBAC/reset/logout.
5. Rewrite map/manual route/local-clear/delete.
6. Rewrite pin create/view only; quarantine lifecycle.
7. Describe finish-triggered AI and separate recommendations.
8. Rewrite admin user management and explicitly omit moderation.
9. Insert the ten verified sequences and relationship matrices.
10. Add security limitations and verification evidence without claiming unimplemented safeguards.
