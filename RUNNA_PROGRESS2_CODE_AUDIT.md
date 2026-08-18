# Runna Progress II — Current-Code Implementation Audit

Audit date: 2026-08-16  
Scope: current `backend/` and `mobile/` source only. Existing documents, comments, TODOs, and tests were not treated as proof of runtime behavior. Line numbers refer to the audited revision and may move after later edits.

## Audit conventions

- **Implemented** means a callable current-code path was traced through its relevant layers.
- **Partially implemented** means some layers/data structures exist but the stated workflow is incomplete.
- **Unused/dead code** means a type/table/client call exists without a current server execution path.
- **Planned/TODO** is reported only as such and never counted as behavior.
- The repository does not contain the normative text of SRS-123–SRS-151 in the supplied baseline. The matrix therefore maps the numbered requirements in the same order as the expected behaviors listed for URS-16 through URS-21. Where that mapping cannot establish the exact normative claim, the note says so.

## 1. Relevant repository structure

### Backend

| Concern | Current source |
|---|---|
| API composition | `backend/app/main.py` (`app.include_router`, line 45); `backend/app/api/router.py` (prefixes `/api/runs`, `/api/map`, `/api/admin`, lines 11–18) |
| Run endpoints | `backend/app/api/routes/runs.py` |
| Hazard/public map endpoints | `backend/app/api/routes/map.py` |
| Administrator endpoints | `backend/app/api/routes/admin.py` |
| Run business logic | `backend/app/services/run_service.py`, class `RunService` |
| AI integration | `backend/app/services/analysis_service.py`, `AnalysisService`, `AnalysisResult`, `GeminiUnavailableError` |
| Hazard/public listing logic | `backend/app/services/map_service.py`, class `MapService` |
| Administrator hazard logic | `backend/app/services/admin_service.py`, class `AdminService` |
| Authentication dependency | `backend/app/services/auth_service.py`, function `get_current_user` (lines 173–186); DB dependency in `backend/app/api/deps.py`, `get_db` |
| Models | `backend/app/models/run.py`, `hazard_marker.py`, `pin_validation.py`, `user.py`, `manual_route.py`, `route_plan.py`; common timestamps in `models/base.py` |
| DTOs | `backend/app/schemas/run.py`, `backend/app/schemas/map.py`; supporting route schemas in `schemas/manual_route.py` and `schemas/route.py` |
| Initial run/hazard migration | `backend/alembic/versions/20260417_0002_create_gis_and_run_tables.py` |
| AI/pin lifecycle migration | `backend/alembic/versions/20260417_0005_add_run_analysis_and_pin_lifecycle.py` |
| RunPoint/route-plan migration | `backend/alembic/versions/20260615_0005_add_run_points.py` |
| AI/configuration | `backend/app/core/config.py`, `Settings.gemini_api_key` (line 17); `.env` values were not inspected |

### Flutter

| Concern | Current source |
|---|---|
| App navigation | `mobile/lib/main.dart`; `RunsScreen`, `HazardsScreen`, and admin-only `AdminScreen` are pages (lines 62–91) |
| HTTP client | `mobile/lib/core/runna_api.dart`, class `RunnaApi` |
| Shared DTOs | `mobile/lib/core/models.dart`, notably `RunItem`, `RunPointItem`, `RunPointUpload`, `HazardMarkerItem` |
| Controller/state façade | `mobile/lib/features/auth/auth_controller.dart`, class `AuthController` |
| GPS abstraction | `mobile/lib/core/location_service.dart`, class `LocationService` |
| Tracking, finish, history, detail, completed/AI UI | `mobile/lib/features/runs/runs_screen.dart`, `RunsScreen` and private state/widgets including `_RunHistorySheet` |
| Hazard validation UI | `mobile/lib/features/hazards/hazards_screen.dart`, `HazardsScreen` |
| Admin moderation UI | `mobile/lib/features/admin/admin_screen.dart`, `AdminScreen` |

There is no separate run-tracking provider/controller. `_RunsScreenState` owns the GPS subscription, timer, active run, points, distance, and presentation state; `AuthController` only delegates authenticated API calls.

## 2. Data structure audit

### Run

- Source/model/table: `backend/app/models/run.py`, class `Run` (lines 10–32), table `runs`.
- Primary key: integer `id` (line 13).
- Owner: non-null indexed `user_id -> users.id`; `Run.user` / `User.runs` relationship. `User.runs` uses `cascade="all, delete-orphan"` (`models/user.py:26`).
- Optional route links: `manual_route_id -> manual_routes.id` and `route_plan_id -> route_plans.id` (lines 15–16), with relationships but no explicit relationship cascade. `start_run` does not validate that either referenced route belongs to the member.
- Status: unconstrained `String(30)`, default `"active"` (line 17). Executable run code writes/compares only `"active"` and `"finished"` (`run_service.py:55,67,105,127,133,177`). No enum/check constraint exists.
- Timing: nullable timezone-aware `started_at`, `finished_at` (lines 18–19). Service records UTC timestamps.
- Statistics: non-null `distance_km` default 0; `duration_seconds` default 0; nullable `avg_pace_min_per_km`; non-null `step_count` default 0 (lines 20–23).
- AI persistence: nullable text `ai_insight`, `ai_reasoning`, `ai_recommendations` (lines 25–27). Recommendations are persisted as a newline-delimited bullet string, not a JSON array (`run_service.py:217–221`).
- Other relevant field: nullable 255-character `notes`; stale runs receive an auto-close note.
- Relationships: `points` uses `cascade="all, delete-orphan"` (line 32). The database migration creates a foreign key but does not declare database-level `ON DELETE CASCADE`.
- Common timestamps: `created_at`, `updated_at` from `TimestampMixin` (`models/base.py:7–11`). History ordering uses `created_at`, not `started_at`.

### RunPoint

- Source/model/table: `backend/app/models/run.py`, class `RunPoint` (lines 35–48), table `run_points`.
- Primary key: integer `id`.
- Run link: non-null indexed `run_id -> runs.id`; ORM inverse is `Run.points`.
- Coordinates/timing: non-null floats `lat`, `lng`; nullable timezone-aware `recorded_at`.
- Sensor metadata: nullable `accuracy_m`, `speed_mps`, `heading_deg`.
- Ordering: non-null integer `sequence`, default 0. `RunService.add_run_points` queries the current highest sequence and assigns `(current_max or 0)+1+index` in request-list order (`run_service.py:277–307`); reads order ascending (`331–335`).
- Validation: DTO enforces only accuracy/speed >= 0 and heading 0–360 (`schemas/run.py:18–24`). Latitude/longitude geographic bounds are not validated. There is no unique constraint on `(run_id, sequence)`, so concurrent uploads can race and duplicate sequence values.
- Ownership/active checks occur before insertion through `get_run` and `run.status != "active"` (`run_service.py:263–269`). Empty batches return `[]` without a commit.
- Timestamp fallback: server UTC now when `recorded_at` is omitted (`run_service.py:303`).

### HazardMarker (hazard pin)

- Source/table: `backend/app/models/hazard_marker.py`, class `HazardMarker`, table `hazard_markers`.
- Owner and content: integer `id`; non-null `user_id`; `marker_type`, severity, `lat`, `lng`, optional note.
- Status: unconstrained `String(30)`, default `"active"` (line 20). Current executable writes use `"active"` and `"removed"`. `AdminService.get_stats` queries `"expired"`, but no current method assigns it.
- Counts: stored non-null integers `confirm_count` and `dismiss_count`, both default 0 (lines 21–22).
- Expiration: nullable `expires_at` exists (line 23) and is serialized. No current service sets it, compares it with current time, or changes status on expiry. **Automatic expiry: NOT CONFIRMED FROM CURRENT CODE.**
- Removal: soft status change to `"removed"`; the row is not deleted (`AdminService.delete_marker`, lines 106–114).
- Public filtering is inconsistent: `MapService.list_markers` excludes `removed` (lines 207–215), but `MapService.get_base_map` returns every marker without filtering (lines 185–190).
- `validations` uses ORM `cascade="all, delete-orphan"`; no physical marker deletion occurs in the Progress II admin operation.

### PinValidation

- Source/table: `backend/app/models/pin_validation.py`, class `PinValidation`, table `pin_validations`.
- Primary key: integer `id`.
- Links: non-null indexed `marker_id -> hazard_markers.id`, `user_id -> users.id`.
- Value: non-null SQL Boolean `confirmed` (`true` means Still there; Flutter sends `false` for Resolved).
- Uniqueness: named database/model constraint `uq_pin_validation_user` on `(marker_id, user_id)` (line 10; migration lines 35–49).
- Timestamps: inherited `created_at` and `updated_at`.
- Creation/update/count behavior: **NOT CONFIRMED FROM CURRENT CODE.** No router or service imports/queries/writes `PinValidation`; no service recomputes the stored counts. This is currently unused schema/model support.

### Directly related supporting models

- `User` (`backend/app/models/user.py`): authentication owner and role link. `get_current_user` rejects invalid tokens, missing users, and inactive users (`auth_service.py:173–186`). Normal run endpoints require authentication but do not require role name `member`; an authenticated administrator can also call them.
- `ManualRoute` and `RoutePlan`: optional run associations. Flutter's start UI requires a selected manual route (`runs_screen.dart:402–430`) even though backend `RunStart` permits both route IDs to be null. `AuthController.startRun` accepts `routePlanId` but fails to pass it to `RunnaApi.startRun` (`auth_controller.dart:183–193`), so that argument is dead at this layer.

## 3. Backend method audit

Proposed IDs below are audit labels suitable for documentation; they are not claims that such identifiers already exist.

### Run methods

#### P2-RUN-START — `RunService.start_run`

- File: `backend/app/services/run_service.py:49–119`.
- Inputs: authenticated `User`, validated `RunStart` (`manual_route_id?`, `route_plan_id?`, `notes?`).
- Logic/validation: finds **all** same-user runs whose status is `active`. It does not reject a new start and does not validate route ownership/existence explicitly.
- Existing active runs: each is finished at the new run's UTC start instant; server derives distance from stored points, duration from point times (or run timestamps), estimates steps using 0.75 m/step, calculates pace if possible, and appends/replaces notes with an auto-close explanation.
- Effects: inserts one `active` Run with `started_at=now`; commits both stale-run updates and insertion in one commit.
- Return: refreshed `Run`.
- Exceptions: database/FK exceptions are not locally handled; schema validation occurs before service invocation.
- Calls: `_list_run_points`, `_calculate_distance_km`, `_calculate_duration_seconds`, `_estimate_steps`.

#### P2-RUN-POINTS-ADD — `RunService.add_run_points`

- File: `backend/app/services/run_service.py:263–319`.
- Inputs: run ID, authenticated user, list of `RunPointCreate`.
- Validation: `get_run` provides ownership-hiding 404; non-active run produces HTTP 400; DTO constraints as described above.
- Logic/effects: assigns increasing sequences based on current maximum, supplies server time if needed, inserts entire request list, commits and refreshes.
- Return: created `RunPoint` list; empty input returns empty list.
- Calls: `get_run`; SQL maximum-sequence query.

#### P2-RUN-POINTS-LIST — `RunService.list_run_points`

- File: `backend/app/services/run_service.py:323–335`.
- Ownership: `get_run`; then ascending sequence query.
- Return: all owned-run points. No active-only restriction for reading.

#### P2-RUN-FINISH — `RunService.finish_run`

- File: `backend/app/services/run_service.py:123–259`.
- Inputs: run ID, authenticated user, optional non-negative client `distance_km`, `duration_seconds`, `step_count`.
- Validation: owned run or 404; status must be exactly `active` or HTTP 400.
- Processing: sets status/UTC finish time; uses each supplied client value verbatim, otherwise server fallback; always recomputes average pace from selected distance and duration when both positive.
- AI: loads up to five other finished runs ordered by `Run.created_at DESC`, retaining only distance and pace; calls `AnalysisService.analyze`; persists returned fields or error/unavailable strings.
- Effects: one final commit persists finish status/statistics and AI/error fields. Because commit occurs after AI returns/fails and both AI exception branches continue, handled Gemini failure does not discard the run.
- Return: refreshed `Run`.
- Exceptions: HTTP 404/400 above; `GeminiUnavailableError` and other AI exceptions are caught. Database exceptions remain unhandled. Recent-run query exceptions are silently reduced to empty context.

#### P2-RUN-DISTANCE — `_calculate_distance_km` / `_distance_m`

- File: `backend/app/services/run_service.py:347–355,379–391`.
- Uses sequence-ordered adjacent stored points and Haversine distance (Earth radius 6,371,000 m); returns kilometres rounded to three decimals. No accuracy/outlier filter is applied server-side.

#### P2-RUN-DURATION — `_calculate_duration_seconds`

- File: `backend/app/services/run_service.py:359–369`.
- Prefers last minus first stored point `recorded_at`; otherwise finish minus start; clamps negative results to zero and truncates fractional seconds.

#### P2-RUN-STEPS — `_estimate_steps`

- File: `backend/app/services/run_service.py:373–375`.
- Estimates `round(distance_m / 0.75)`. It is used only when the client omits step count (and for auto-closed runs). It is not pedometer-derived.

#### P2-RUN-PACE — inline in `start_run` and `finish_run`

- Files: `run_service.py:77–83,159–165`.
- Formula: `(duration_seconds / 60) / distance_km`; otherwise null. There is no standalone method.

#### P2-RUN-HISTORY — `RunService.list_runs`

- File: `backend/app/services/run_service.py:339–343`.
- Input: authenticated user ID. Filters owner; orders all statuses by `created_at DESC`; returns `[]` naturally for no rows.

#### P2-RUN-GET — `RunService.get_run`

- File: `backend/app/services/run_service.py:37–45`.
- Returns an owned run. Missing and foreign-owned IDs both produce HTTP 404 `Run not found`.

### Hazard validation methods

No backend method or endpoint implements submit/update/count processing. Accordingly, no proposed documentation ID is assigned. `PinValidation`, `HazardMarkerValidate`, counts, Flutter calls, and a test reference exist, but application routing/service behavior is absent. Repeated validation update behavior and confirmation/dismissal calculation are **NOT CONFIRMED FROM CURRENT CODE**.

### AI analysis methods

#### P2-AI-PREPARE — `AnalysisService.analyze` and `_build_structured_summary`

- File: `backend/app/services/analysis_service.py:41–112`.
- Inputs: current distance, duration, steps, average pace, and recent run dictionaries.
- Submitted structured fields: `distance_km` (2 dp), `duration_minutes` (1 dp), `step_count`, `avg_pace_min_per_km` (2 dp), calculated `cadence_spm`, `recent_run_count`, `pace_delta_vs_recent`.
- Recent context does **not** send individual prior runs to Gemini. The service derives only count and mean-pace delta from up to five records. Recent distances are queried but not used in the summary.
- Missing Gemini key raises `GeminiUnavailableError`; there is no local recommendation fallback.

#### P2-AI-CALL — `AnalysisService._call_gemini`

- File: `backend/app/services/analysis_service.py:114–246`.
- Calls Google Generative Language `generateContent` synchronously with `httpx.post`, 30-second timeout, trying four configured model names in order. Prompt requests English JSON containing `insight`, `reasoning`, and three `recommendations`.
- Non-200, parse, empty-candidate, and empty-insight failures move to the next model. After all attempts it raises `GeminiUnavailableError`.

#### P2-AI-PARSE — `AnalysisService._parse_json_response`

- File: `backend/app/services/analysis_service.py:248–277`.
- Strips optional fenced JSON; tries full `json.loads`, then the substring from first `{` through last `}`. `_call_gemini` coerces insight/reasoning to strings and recommendation string-or-list items to non-empty strings. Only non-empty insight is mandatory; no Pydantic/JSON-schema validation or fixed recommendation count is enforced.

#### AI persistence/failure (inside `RunService.finish_run`)

- Success stores insight, reasoning, and a display-formatted newline/bullet string.
- Gemini unavailable stores `ai_insight="[AI unavailable] ..."`, a diagnostic reasoning string, and empty recommendations.
- Unexpected exception stores `ai_insight="[Unexpected AI error] ..."` and empty reasoning/recommendations.
- These are error representations, not genuine fallback coaching recommendations.
- There is no independent AI endpoint; generation is synchronous inside finish.

### Administrator hazard moderation

#### P2-ADMIN-HAZARD-LIST — `AdminService.list_markers`

- File: `backend/app/services/admin_service.py:116–123`.
- Optional exact status filter; otherwise excludes `removed`; orders `created_at DESC`.
- Authorization is enforced by router calling `require_admin`, not inside this list method.

#### P2-ADMIN-HAZARD-REMOVE — `AdminService.delete_marker`

- File: `backend/app/services/admin_service.py:106–114`.
- Looks up marker; 404 if absent; changes `status` to `removed`; commits; returns `None`. It does not delete the database row.

#### P2-ADMIN-AUTH — `AdminService.require_admin`

- File: `backend/app/services/admin_service.py:20–26`.
- Requires loaded role name exactly `admin`; otherwise HTTP 403.

#### P2-PUBLIC-HAZARD-LIST — `MapService.list_markers`

- File: `backend/app/services/map_service.py:207–215`.
- Excludes `removed`; newest `created_at` first. However `get_base_map` at lines 185–190 includes removed rows, so removal filtering is not universal.

`AdminService.approve_hazard_marker` (`admin_service.py:138–148`) and duplicate map-router admin endpoints exist, but they are separate status-toggle/route-management behavior, not the `/api/admin/markers/{id}` removal workflow used by Flutter.

## 4. API endpoint audit

All paths below include the `/api` prefix from `main.py`.

| Method | Endpoint | Router/file | Authentication | Role | Request schema | Response schema | Service method |
|---|---|---|---|---|---|---|---|
| GET | `/api/runs` | `routes/runs.py:list_runs` | Bearer `get_current_user` | Any authenticated active user | None | `list[RunResponse]` | `RunService.list_runs` |
| POST | `/api/runs/start` | `routes/runs.py:start_run` | Bearer | Any authenticated active user | `RunStart` | `RunResponse`, 201 | `RunService.start_run` |
| GET | `/api/runs/{run_id}` | `routes/runs.py:get_run` | Bearer | Any authenticated active user, owner enforced | None | `RunResponse` | `RunService.get_run` |
| GET | `/api/runs/{run_id}/points` | `routes/runs.py:list_run_points` | Bearer | Owner | None | `list[RunPointResponse]` | `RunService.list_run_points` |
| POST | `/api/runs/{run_id}/points` | `routes/runs.py:add_run_points` | Bearer | Owner; run active | `list[RunPointCreate]` | `list[RunPointResponse]`, 201 | `RunService.add_run_points` |
| POST | `/api/runs/{run_id}/finish` | `routes/runs.py:finish_run` | Bearer | Owner; run active | `RunFinish` | `RunResponse` | `RunService.finish_run` |
| GET | `/api/map/markers` | `routes/map.py:list_markers` | None | Public | None | `list[HazardMarkerResponse]` | `MapService.list_markers` |
| GET | `/api/map/` and `/api/map/base` | `routes/map.py:get_base_map*` | None | Public | None | `BaseMapResponse` | `MapService.get_base_map` |
| GET | `/api/admin/markers?status_filter=` | `routes/admin.py:list_markers` | Bearer | Admin | Optional query string | `list[HazardMarkerResponse]` | `AdminService.list_markers` |
| DELETE | `/api/admin/markers/{marker_id}` | `routes/admin.py:delete_marker` | Bearer | Admin | None | Unmodelled JSON `{status, marker_id}` | `require_admin`, `delete_marker` |

- Hazard validation: Flutter calls `POST /api/map/markers/{marker_id}/validate`, but **NO CURRENT BACKEND ENDPOINT EXISTS**.
- AI recommendation: no independent endpoint; it runs internally during `/runs/{id}/finish`.
- Admin removal is also exposed indirectly by `PUT /api/map/markers/{id}/approve?approved=false` (`routes/map.py:133–144`), admin-only, returning unmodelled status JSON. The Flutter moderation UI uses the `/api/admin` DELETE endpoint.
- `GET /api/map/` is a documentation risk because its unfiltered markers differ from `/api/map/markers`.

## 5. Flutter implementation audit

### Start and track run

- Screen/state: `RunsScreen` / `_RunsScreenState` in `mobile/lib/features/runs/runs_screen.dart`.
- User action: the start handler `_startRun` requires a selected manual route, resets local state, and calls `AuthController.startRun(manualRouteId, notes)` (`402–445`). Backend itself does not require a route.
- API: `RunnaApi.startRun` posts to `/runs/start` (`runna_api.dart:254–270`). The controller's `routePlanId` parameter is not forwarded.
- Permission/GPS: `LocationService._ensurePermission` checks service enabled, requests denied permission once, and throws typed messages for denied/deniedForever (`location_service.dart:121–147`). Native stream requests best-navigation accuracy, 2 m distance filter, Android 3-second interval/foreground notification; web polls current position every 3 seconds (`26–115`).
- Stream/state: `_startLocationStream` cancels prior subscription/timer, sets tracking, listens to GPS, and starts a one-second UI timer (`runs_screen.dart:290–331`). Stream errors stop tracking and show the error.
- Filtering: `_shouldRecordPoint` accepts first point and then only points at least 2 m from the last locally accepted point (`137–145`). No accuracy/speed/outlier threshold is used.
- Upload: each accepted location is sent immediately as a list containing one `RunPointUpload`; there is no multi-point batching/retry queue (`333–379`). Failed upload leaves the point in local state and shows `Tracking locally, upload failed`; it is not later resent by confirmed code.
- Path/statistics: accepted points update a tracked polyline and client distance; the timer shows elapsed duration; live UI also derives steps using 0.75 m/step, pace, heading, route progress, and off-route distance. The selected planned route and hazard pins are also drawn.
- Restore: `_loadRuns` takes the first server-ordered active run, restores stored points and elapsed time, but deliberately does not restart GPS; user must tap Resume GPS (`202–274`, UI reference at line 919).

### Finish run

- User action: `_finishRun` cancels GPS/timer before the call (`448–487`).
- Sent values: local `_trackedDistanceKm`; elapsed seconds (forced to at least 1); locally estimated steps `round(distance_m/0.75)` (`462–470`). Thus normal Flutter completion overrides all three backend fallback calculations.
- Error behavior: shows the exception; because tracking was already cancelled and `_isTracking` is not cleared in the catch path, no automatic resume/retry is confirmed.
- Success/navigation: it stays within `RunsScreen` and switches state to an inline `Summary Result` page (`584+`), then reloads history. It displays backend-returned distance, steps, duration, pace, AI insight/reasoning/recommendations. Error-prefixed AI insight is converted to unavailable/error text (`17–35`, `673–694`).

### Run history and detail

- `_loadRuns` calls authenticated `GET /runs`; server ordering is preserved. Flutter performs no sort (`202–230`).
- `_openHistorySheet` opens `_RunHistorySheet` with `_runs` (`499–518`, class at `1056+`). Empty input displays the sheet's empty state; server itself naturally returns `[]`.
- The sheet renders summary cards and expandable inline details including statistics and AI fields (`1129–1212`).
- Although `AuthController.getRun` / `RunnaApi.getRun` exist, the history/detail UI is populated from list results and does not call the particular-run endpoint. Therefore backend detail is implemented, but use by Flutter history detail is **NOT CONFIRMED**.

### Hazard validation

- UI: `HazardsScreen`; `_validatePin(marker, bool)` is called by `Still there` (`true`) and `Resolved` (`false`) buttons (`hazards_screen.dart:108–121,271–279`).
- Client/controller: `AuthController.validateMarker` calls `RunnaApi.validateMarker`, which POSTs `{confirmed: bool}` to `/map/markers/{id}/validate` (`runna_api.dart:157–171`).
- Local behavior: while loading, controls are disabled; on nominal success the screen reloads markers; errors become `_message` text. It does not optimistically alter counts.
- Actual end-to-end status: **FLUTTER UI/CLIENT IMPLEMENTED / BACKEND ENDPOINT NOT CONFIRMED (and absent from current router)**. The action will receive an HTTP failure against this backend.

### AI recommendation

- No separate client API call exists. The finish response's `RunItem` consumes `ai_insight`, `ai_reasoning`, and `ai_recommendations` from backend JSON (`core/models.dart`, `RunItem.fromJson`).
- Immediately after completion, Summary Result displays AI sections; history details also display them. Empty/error-prefixed insight receives explicit no-data/unavailable/error presentation.
- Backend recommendations are a single formatted string and Flutter displays that string, not a structured list.

### Administrator hazard moderation

- UI exists: `AdminScreen` is included only when `AuthController.isAdmin` (`main.dart:76–90`). This is presentation gating in addition to backend authorization.
- Load: `_loadMarkers -> controller.getAdminMarkers -> GET /admin/markers` (`admin_screen.dart:75–83`; `runna_api.dart:382–394`).
- Remove: trash icon calls `_removeMarker -> deleteAdminMarker -> DELETE /admin/markers/{id}` (`admin_screen.dart:113–121,252–255`; `runna_api.dart:397–406`).
- Success refreshes the marker list; failure shows `_actionMessage`. There is no confirmation dialog in current code.

## 6. Progress II requirement verification matrix

Because exact normative SRS sentences are absent, “Evidence” ties each ID to the corresponding baseline item in listed order. This avoids inventing unprovided wording.

| Requirement | Status | Evidence | Notes |
|---|---|---|---|
| SRS-123 | CONFIRMED | `runs.py:start_run`; `RunService.start_run` lines 49–119 | Authenticated user starts an active run; UTC start recorded. Role is not restricted specifically to member. |
| SRS-124 | CONFIRMED | `start_run` lines 51–93 | Existing same-owner active runs are auto-finished, statistically finalized, and annotated. |
| SRS-125 | CONFIRMED | `LocationService.positionStream`; `_startLocationStream`, `_handlePosition` | GPS/location collection exists with permission checks and platform sampling. |
| SRS-126 | CONFIRMED | `RunService.add_run_points` lines 263–319 | Owned active run required; accepted points persisted. |
| SRS-127 | PARTIALLY CONFIRMED | `add_run_points` lines 277–307; `_list_run_points` lines 331–335 | Sequence assigned/read in order, but no uniqueness constraint; race safety not confirmed. |
| SRS-128 | CONFIRMED | `RunService.finish_run` lines 123–165 | Only owned active run; finish timestamp/status persisted. |
| SRS-129 | CONFIRMED | `finish_run` lines 139–155 | Client distance/duration/steps take precedence; stored-point/time/estimated fallbacks exist. |
| SRS-130 | CONFIRMED | `_calculate_distance_km`, `_distance_m` | Server Haversine distance from ordered stored points. Normal Flutter finish sends client distance. |
| SRS-131 | CONFIRMED | `_calculate_duration_seconds`; Flutter `_finishRun` | Point-time then run-time server fallback; normal Flutter sends client timer. |
| SRS-132 | PARTIALLY CONFIRMED | `_estimate_steps` line 373; Flutter line 106 | Step value exists but is distance/0.75 estimate, not measured pedometer steps. |
| SRS-133 | CONFIRMED | `finish_run` lines 159–165,253–259 | Pace and final statistics, including AI/error fields, are committed. |
| SRS-134 | CONFIRMED | `RunService.list_runs` lines 339–343 | Owner-filtered history. |
| SRS-135 | CONFIRMED | same | Ordered by `created_at DESC`, not start/finish time. |
| SRS-136 | CONFIRMED | `runs.py:get_run`; `RunService.get_run` | Particular owned run endpoint; foreign/missing returns same 404. Flutter history does not use it. |
| SRS-137 | CONFIRMED | `list_runs` returns query list; Flutter `_RunHistorySheet` | Empty result is `[]` and UI has empty state. |
| SRS-138 | NOT CONFIRMED | No matching router/service method | Existing-marker validation has client call only. |
| SRS-139 | NOT CONFIRMED | Flutter buttons exist; backend route absent | Still there/Resolved is not end-to-end implemented. |
| SRS-140 | PARTIALLY CONFIRMED | `PinValidation.confirmed: Boolean`; unique migration | Representation/schema confirmed; executable write behavior absent. |
| SRS-141 | NOT CONFIRMED | Unique `(marker_id,user_id)` exists, no service | One-row intent is structural only; repeated update is not implemented. |
| SRS-142 | NOT CONFIRMED | Stored count columns exist, never updated by service | Confirmation/dismissal calculation/update absent. |
| SRS-143 | CONFIRMED | `finish_run` lines 169–215; `_build_structured_summary` | Completed-run statistics prepared; up to five prior finished runs supply aggregated context. |
| SRS-144 | CONFIRMED | `_call_gemini` lines 114–246 | Gemini request and model retry loop implemented. |
| SRS-145 | PARTIALLY CONFIRMED | `_parse_json_response`; `_call_gemini` lines 191–238 | JSON parsed/coerced; non-empty insight required, but no strict result schema or three-tip enforcement. |
| SRS-146 | CONFIRMED | `Run` AI columns; `finish_run` lines 217–255 | AI success or failure representation persists with Run. |
| SRS-147 | PARTIALLY CONFIRMED | `finish_run` exception branches lines 229–255 | Run survives handled Gemini failure, but no real recommendation fallback—only unavailable/error data. |
| SRS-148 | CONFIRMED | `admin.py:delete_marker` lines 89–98; `require_admin` | Bearer authentication plus exact admin role. |
| SRS-149 | CONFIRMED | same; `AdminService.delete_marker` | Marker identified by path integer; absent -> 404. |
| SRS-150 | CONFIRMED | `delete_marker` lines 106–114 | Soft removal via status `removed`; row retained. |
| SRS-151 | PARTIALLY CONFIRMED | `MapService.list_markers` excludes removed; `get_base_map` does not | Normal marker list excludes removed, but public base-map endpoints leak them. |

## 7. Documentation risks

## Documentation Risk R-01

Claim in documentation: Hazard pins automatically expire or move between Active and Expired.  
Actual implementation: `expires_at` and an `expired` stats query exist, but no executable lifecycle logic sets expiry or status.  
Evidence: `models/hazard_marker.py:20–23`; `admin_service.py:34–37`; no expiry reference in services beyond serialization/statistics.  
Recommended documentation action: State **NOT CONFIRMED FROM CURRENT CODE**; describe only nullable storage and the unused stats category.

## Documentation Risk R-02

Claim in documentation: Member validation updates one vote and confirmation/dismissal totals.  
Actual implementation: model, uniqueness constraint, DTO, Flutter call and UI exist; backend endpoint/service behavior is absent.  
Evidence: `models/pin_validation.py`; `schemas/map.py:37–38`; no `/validate` decorator in `routes/map.py`; client `runna_api.dart:157–171`.  
Recommended documentation action: Mark workflow partially scaffolded but not implemented end-to-end; do not document count mutation or repeat-update semantics.

## Documentation Risk R-03

Claim in documentation: Only one active run can exist because a new start is rejected.  
Actual implementation: new start auto-finishes every same-user active run and then inserts the new run.  
Evidence: `run_service.py:51–115`.  
Recommended documentation action: Document auto-close, derived statistics, shared timestamp, and note mutation explicitly.

## Documentation Risk R-04

Claim in documentation: Final statistics are server-calculated from stored RunPoints.  
Actual implementation: optional client values take precedence; current Flutter always sends distance, duration, and estimated steps.  
Evidence: `run_service.py:139–165`; `runs_screen.dart:462–470`.  
Recommended documentation action: Describe client-authoritative normal flow and server fallbacks separately.

## Documentation Risk R-05

Claim in documentation: Step count comes from a device step sensor.  
Actual implementation: both Flutter and backend estimate from distance using a fixed 0.75 m stride.  
Evidence: `runs_screen.dart:106`; `run_service.py:373–375`.  
Recommended documentation action: Call it estimated step count; do not claim pedometer integration.

## Documentation Risk R-06

Claim in documentation: Run history is chronological by start or finish time.  
Actual implementation: server orders `Run.created_at DESC`; Flutter preserves that ordering.  
Evidence: `run_service.py:339–343`; `runs_screen.dart:202–230,499–518`.  
Recommended documentation action: Name `created_at DESC` precisely.

## Documentation Risk R-07

Claim in documentation: AI receives the last five full runs.  
Actual implementation: query retrieves up to five prior finished runs' distance and pace, but Gemini receives only recent count and pace delta; individual histories/distances are not included.  
Evidence: `run_service.py:169–213`; `analysis_service.py:80–112,143–145`.  
Recommended documentation action: Describe aggregated recent-pace context, not full recent-run payload.

## Documentation Risk R-08

Claim in documentation: Gemini failure returns a fallback coaching recommendation.  
Actual implementation: it stores unavailable/error text and empty recommendations; finish still commits.  
Evidence: `run_service.py:229–255`; Flutter formatter `runs_screen.dart:17–35`.  
Recommended documentation action: Document graceful completion with unavailable/error result, not a recommendation fallback.

## Documentation Risk R-09

Claim in documentation: AI output is a structured persisted recommendation object/list.  
Actual implementation: service result is structured temporarily, but persistence/API expose three nullable strings; recommendation list is flattened to bullet-delimited text.  
Evidence: `analysis_service.py:13–17`; `run_service.py:217–221`; `models/run.py:25–27`.  
Recommended documentation action: Use the actual three-string storage contract.

## Documentation Risk R-10

Claim in documentation: Removed hazards are excluded from all member/public map responses.  
Actual implementation: `/map/markers` excludes them, while `/map/` and `/map/base` return all markers.  
Evidence: `map_service.py:185–190,207–215`; `routes/map.py:35–54`.  
Recommended documentation action: Qualify filtering by endpoint and flag the inconsistency in test documentation.

## Documentation Risk R-11

Claim in documentation: Removing a hazard physically deletes it.  
Actual implementation: status is changed to lowercase `removed`; row and validations remain.  
Evidence: `admin_service.py:106–114`.  
Recommended documentation action: Document soft removal and exact stored value.

## Documentation Risk R-12

Claim in documentation: RunPoint order is guaranteed unique.  
Actual implementation: application assigns increasing sequence values, but migration/model has no `(run_id, sequence)` uniqueness and the max-plus-one operation is not concurrency-safe.  
Evidence: `run_service.py:277–307`; migration `20260615_0005_add_run_points.py:68–84`.  
Recommended documentation action: Say “application-assigned sequence used for ordering,” not database-guaranteed unique sequence.

## Documentation Risk R-13

Claim in documentation: Flutter can start either a manual route or route plan.  
Actual implementation: UI requires a manual route, and `AuthController.startRun` drops its `routePlanId` argument.  
Evidence: `runs_screen.dart:402–430`; `auth_controller.dart:183–193`.  
Recommended documentation action: Document the current Flutter manual-route-only start path; backend optional route-plan support is separate.

## Documentation Risk R-14

Claim in documentation: Administrator route management is part of hazard removal.  
Actual implementation: hazard removal is an admin marker status operation. Separate edge override/rebuild/approve endpoints exist, but no Progress-II route deletion/moderation operation participates.  
Evidence: `routes/admin.py:89–98`; `routes/map.py:119–167`.  
Recommended documentation action: Keep route/edge administration outside URS-21 unless separately scoped.

## Documentation Risk R-15

Claim in documentation: A failed point upload is eventually synchronized.  
Actual implementation: Flutter retains the point only in local state and displays an error; no retry queue/batch recovery is present. Finish then sends local totals, which may diverge from stored points.  
Evidence: `runs_screen.dart:333–379,462–470`.  
Recommended documentation action: Do not claim offline synchronization or complete server track persistence.

## 8. Sequence-flow evidence

### 1. Start and Track Run

Member  
→ Flutter `RunsScreen._startRun` (requires selected manual route)  
→ `AuthController.startRun` / `RunnaApi.startRun`  
→ `POST /api/runs/start`, router `start_run`  
→ `RunService.start_run`  
→ Database: auto-finish all owned active Runs; insert active Run with UTC `started_at`; commit  
→ Router returns `RunResponse`  
→ Flutter sets `_activeRun`, calls `_startLocationStream`  
→ `LocationService.positionStream` / Geolocator  
→ `_handlePosition` filters >=2 m and updates local polyline/stats  
→ `POST /api/runs/{id}/points` with one-element list  
→ `RunService.add_run_points` checks ownership/active state, assigns sequence  
→ Database inserts RunPoint(s)  
→ Flutter continues tracking; upload error is displayed while local tracking continues  
→ Member sees live map, duration, distance, estimated steps, pace/heading/progress.

### 2. Finish Run

Member  
→ Flutter `RunsScreen._finishRun` cancels stream/timer and calculates client totals  
→ `AuthController.finishRun` / `RunnaApi.finishRun`  
→ `POST /api/runs/{id}/finish`  
→ router `finish_run`  
→ `RunService.finish_run` verifies owner and active status  
→ Database reads ordered points and up to five prior finished Runs  
→ `AnalysisService.analyze` → Gemini (details in flow 5)  
→ Database commits `finished_at`, `finished`, statistics, AI success/error strings  
→ Router returns `RunResponse`  
→ Flutter sets `_justFinishedRun` and renders Summary Result  
→ Member views statistics and AI/unavailable result.

### 3. View Run History

Member  
→ Flutter `_loadRuns` / `AuthController.getRuns`  
→ `GET /api/runs`  
→ router `list_runs`  
→ `RunService.list_runs(user_id)`  
→ Database filters `user_id`, orders `created_at DESC`  
→ Router returns list (including `[]`)  
→ Flutter `_openHistorySheet` / `_RunHistorySheet` renders list and inline expanded detail  
→ Member views history.  

Independent detail alternative: Member → `AuthController.getRun` → `GET /api/runs/{id}` → `RunService.get_run` → owned Run/404 → Flutter caller. Current history UI use of this alternative is **NOT CONFIRMED FROM CURRENT CODE**.

### 4. Validate Hazard Pin

Member  
→ Flutter `HazardsScreen._validatePin(marker, true|false)`  
→ `AuthController.validateMarker` / `RunnaApi.validateMarker`  
→ attempts `POST /api/map/markers/{id}/validate` with `{confirmed}`  
→ **Router: NOT CONFIRMED FROM CURRENT CODE (route absent)**  
→ Service/Database update: **NOT CONFIRMED FROM CURRENT CODE**  
→ Flutter catches HTTP error and displays `_message`  
→ Member does not receive a confirmed validation result.

### 5. Generate AI Recommendation

Member (finishes run)  
→ Flutter finish request  
→ run router/service as above  
→ `RunService.finish_run` reads up to five previous finished Runs  
→ `AnalysisService.analyze` / `_build_structured_summary`  
→ `_call_gemini` sends aggregate run JSON to Google Generative Language API  
→ `_parse_json_response` and `_call_gemini` build `AnalysisResult`  
→ `RunService.finish_run` flattens recommendations and commits them with Run  
→ router returns `RunResponse`  
→ Flutter Summary Result/history displays AI fields  
→ Member.  

Failure branch: Gemini models fail/missing key → `GeminiUnavailableError` → Run service stores unavailable/error strings and still commits finished Run → Flutter displays unavailable/error message. No independent AI endpoint or real fallback recommendation exists.

### 6. Remove Incorrect Hazard Report

Administrator  
→ Flutter `AdminScreen._removeMarker`  
→ `AuthController.deleteAdminMarker` / `RunnaApi.deleteAdminMarker`  
→ `DELETE /api/admin/markers/{id}`  
→ router `delete_marker`  
→ `AdminService.require_admin` then `AdminService.delete_marker`  
→ Database updates marker `status="removed"` and commits (no row deletion)  
→ router returns `{status:"removed", marker_id}`  
→ Flutter reloads `GET /api/admin/markers`  
→ `AdminService.list_markers` excludes removed by default  
→ Flutter refreshes moderation list  
→ Administrator sees marker removed from that list.

## 9. Final assessment

## Safe to Document

- Authenticated run start, UTC timestamping, active status, and auto-closure of all same-owner active runs.
- GPS permission handling, native stream/web polling, 2 m client acceptance threshold, immediate one-point uploads, local polyline/live statistics.
- RunPoint ownership/active checks, application sequence allocation, ascending retrieval.
- Owned-active finish enforcement; client-first statistics with stored-data fallbacks; Haversine distance, time fallback, fixed-stride step estimate, pace formula.
- Owner-filtered run history ordered by `created_at DESC`, owned detail endpoint, and empty list behavior.
- Synchronous Gemini analysis inside finish, aggregate recent-pace context, permissive JSON parsing, three text-field persistence, and handled failure that still commits the run.
- Admin-only soft hazard removal to exact status `removed`, admin list refresh, and `/map/markers` exclusion.

## Needs Documentation Adjustment

- Treat steps as estimates, not sensor measurements.
- Treat Flutter's normal finish totals as client-authoritative; server calculations are fallbacks.
- Describe stale active runs as auto-finished, not rejected or resumed by the backend.
- Describe history ordering as creation time.
- Describe recent-run AI context as aggregate count/pace delta, not full histories.
- Describe Gemini failure as unavailable/error persistence, not fallback coaching.
- Describe AI recommendations as flattened text.
- Qualify removed-hazard filtering because base-map endpoints remain unfiltered.
- Document Flutter start as manual-route-only despite broader backend DTO/model fields.

## Not Implemented / Not Confirmed

- Backend hazard validation endpoint and service logic.
- PinValidation creation/upsert/repeat-update behavior and count recomputation.
- Automatic hazard expiry or any transition to `expired`.
- Database-guaranteed unique RunPoint sequence or concurrency-safe allocation.
- GPS upload retry/offline synchronization.
- Pedometer-derived step count.
- A genuine non-Gemini fallback recommendation.
- Flutter history detail calling the dedicated run-detail endpoint.
- Universal removal filtering across all public map endpoints.

## Files Required for Further Inspection

None. All current source files needed to assess the requested Progress II paths were inspectable. Runtime database contents, deployed routing, and external Gemini responses were outside this source-code-only audit and were not assumed.
