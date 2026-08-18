# Data structures

All attribute tables below use the required columns. Safe examples are synthetic. `TimestampMixin` supplies timezone-aware `created_at` and `updated_at` server timestamps unless stated.

## A. Progress I structures

### `Role` — `backend/app/models/role.py:8-16`

SQLAlchemy model; bases `TimestampMixin, Base`; table `roles`; migration `20260417_0001`. One-to-many `users` with `back_populates=role`; non-null user FK points child-to-parent; no ORM cascade, so role deletion is database-restricted while users exist.

| Name | Type | Description | Example |
|---|---|---|---|
| id | int | Indexed primary key | 2 |
| name | varchar(50) | Unique, non-null role name | `member` |
| description | varchar(255) nullable | Role explanation | `Standard user` |
| created_at / updated_at | datetime | Server timestamps | `2026-07-17T10:00:00Z` |

### `User` — `backend/app/models/user.py:8-33`

SQLAlchemy model, table `users`, migration `20260417_0001`. Unique/indexed username and email; indexed nullable province and non-null `role_id -> roles.id`. Many-to-one Role; one-to-many contacts, hazards, manual routes, route plans, runs, reset codes, all configured `all, delete-orphan`. ORM deletion of a loaded user cascades children; reset-code FK also has DB `ON DELETE CASCADE`; other DB FKs have no on-delete clause.

| Name | Type | Description | Example |
|---|---|---|---|
| id | int | Indexed primary key | 42 |
| first_name | varchar(100) | Required | `Nina` |
| last_name | varchar(100) | Required | `Miles` |
| username | varchar(50) | Required, unique, indexed | `nina_runner` |
| email | varchar(255) | Required, unique, indexed | `nina@example.com` |
| password_hash | varchar(255) | PBKDF2 hash; never serialize | `[REDACTED]` |
| province | varchar(100) nullable | Indexed profile value | `Chiang Mai` |
| is_active | bool | Python default true | true |
| role_id | int FK | Required/indexed role | 2 |

### `PasswordResetCode` — `backend/app/models/password_reset_code.py:9-31`

SQLAlchemy model, table `password_reset_codes`; does not use `TimestampMixin`; migration `20260715_0006`. Many-to-one User/back-populates; FK is indexed, non-null and `ON DELETE CASCADE`.

| Name | Type | Description | Example |
|---|---|---|---|
| id | int | Primary key | 7 |
| user_id | int FK | Bound account | 42 |
| code_hash | varchar(255) | PBKDF2 OTP hash, never raw | `[REDACTED]` |
| expires_at | datetime | Required expiry | `2026-07-17T10:10:00Z` |
| used_at | datetime nullable | Consumption/invalidation time | null |
| delivered_at | datetime nullable | Successful delivery gate | `2026-07-17T10:00:05Z` |
| attempt_count | int | Default 0; accepted only while `<5` | 0 |
| created_at | datetime | Server timestamp | `2026-07-17T10:00:00Z` |

### `ManualRoute` — `backend/app/models/manual_route.py:10-39`

SQLAlchemy model, table `manual_routes`; migrations `0002` and `0005`. Many-to-one User. User ORM relationship cascades delete-orphan. Runs optionally reference it without ORM back-reference; service delete sets those FKs null before hard delete.

| Name | Type | Description | Example |
|---|---|---|---|
| id | int | Indexed primary key | 12 |
| user_id | int FK | Required/indexed owner | 42 |
| name | varchar(150) | Required | `Campus Loop` |
| path_json | varchar(8000) | JSON array of raw `{lat,lng}` objects | `[{"lat":18.80,"lng":98.95}]` |
| snapped_path_json | varchar(16000) nullable | JSON array of snapped `{lat,lng}` objects | null |
| distance_km | float | Required, default 0 | 3.2 |
| validation_json | varchar(1000) nullable | JSON object with risky/forbidden/snapped/warnings | `{"risky_edges":0}` |

`validation` property returns parsed JSON. Empty data yields integer counters and empty string warning; malformed JSON is returned in `total_warnings`. API serialization uses Pydantic from-attributes and this property. `manual_route_to_response` instead directly `json.loads` and is apparently unused.

### `HazardMarker` — `backend/app/models/hazard_marker.py:10-31`

SQLAlchemy model, table `hazard_markers`; migrations `0002/0005`. Many-to-one User; one-to-many validations with delete-orphan. Required child FKs mean hard user/marker ORM deletions cascade configured children; normal admin “delete” is soft status=`removed`.

| Name | Type | Description | Example |
|---|---|---|---|
| id | int | Indexed PK | 9 |
| user_id | int FK | Required/indexed creator | 42 |
| marker_type | varchar(50) | Category string | `construction` |
| severity | int | Default 1; create schema restricts 1..5 | 3 |
| lat / lng | float | Coordinates; no range validation | `18.804`, `98.955` |
| note | varchar(255) nullable | Optional note | `Work near crossing` |
| status | varchar(30) | Default `active`; unconstrained DB string | `active` |
| confirm_count / dismiss_count | int | Default 0; PII lifecycle counters | 0 |
| expires_at | datetime nullable | PII lifecycle expiry | null |

### Progress I Pydantic schemas

All derive `BaseModel`. Response models noted below use `ConfigDict(from_attributes=True)`.

| Class (source) | Purpose and validation | Attributes (`Name: Type`) | Related APIs |
|---|---|---|---|
| `UserRegister` (`schemas/auth.py:4-10`) | Registration; names 1..100, username 3..50, valid email, password 8..128 | `first_name:str`, `last_name:str`, `username:str`, `email:EmailStr`, `password:str` | POST register |
| `LoginRequest` (`auth.py:12-15`) | Login | `username_or_email:str(3..255)`, `password:str(8..128)` | POST login |
| `ForgotPasswordRequest` (`auth.py:17-19`) | Valid-email request | `email:EmailStr` | POST forgot |
| `ResetPasswordRequest` (`auth.py:21-32`) | Six digits; passwords 8..128 and model-validator equality | `email`, `code`, `new_password`, `confirm_password` | POST reset |
| `TokenResponse` (`auth.py:38-43`) | Bearer result | `access_token:str`, `token_type:str='bearer'` | login |
| `GenericMessageResponse` (`auth.py:34-36`) | Enumeration-safe message | `message:str` | reset flows |
| `UserResponse` (`schemas/user.py:4-16`) | Current/registered account, ORM serialization | id, names, username, email, nullable province, active, role IDs/name | register, `/me` |
| `AdminUserUpdate` (`user.py:38-41`) | Optional active and role; role regex member/admin | `is_active:bool?`, `role_name:str?` | PATCH admin user |
| `AdminUserResponse` (`user.py:24-35`) | Admin projection | id/names/username/email/active/role plus counts default 0 | admin users |
| `AdminStatsResponse` (`user.py:43-51`) | Mixed dashboard counts | seven ints | admin stats |
| `ManualRoutePoint` (`manual_route.py:4-7`) | Point DTO; no coordinate bounds | `lat:float`, `lng:float` | manual route create |
| `ManualRouteCreate` (`manual_route.py:9-12`) | Name 1..150; list length not schema-constrained (service requires 2) | `name:str`, `points:list[ManualRoutePoint]` | POST manual routes |
| `ManualRouteValidation` (`manual_route.py:14-18`) | Validation projection/defaults | three ints and `total_warnings:str` | route response |
| `ManualRouteResponse` (`manual_route.py:20-30`) | ORM/property serialization | id, owner, name, JSON strings, distance, validation | manual routes |
| `HazardMarkerCreate` (`schemas/map.py:29-35`) | Type 1..50, severity 1..5, note <=255; coordinates unbounded | marker fields | POST markers |
| `HazardMarkerResponse` (`map.py:41-54`) | Pin projection | IDs/type/severity/coords/note/status/counters/ISO expiry string | map/pin/admin |
| `BaseMapResponse` (`map.py:57-60`) | Aggregate | nodes, edges, markers | GET map |

UC/URS/SRS IDs are not reliably encoded in source; mappings are `Needs document confirmation` except feature names.

## B. Progress II structures

| Structure | Type/source | Key attributes and behavior |
|---|---|---|
| `MapNode` | ORM `models/map_node.py:8-20` | table `map_nodes`: indexed id, nullable name, lat/lng, boolean default false; migration also adds `osm_id` absent from ORM |
| `MapEdge` | ORM `models/map_edge.py:8-23` | node FKs, road metadata, speed/length/risk, forbidden, JSON-string geometry; no relationships/cascades configured |
| `RoutePlan` | ORM `models/route_plan.py:8-29` | generated-route fields and JSON-string path; owner relationship; migration `0003/0004` |
| `Run` | ORM `models/run.py:10-32` | user and nullable route FKs, status/times/stats/AI text; points delete-orphan; migrations `0002/0005/20260615_0005` |
| `RunPoint` | ORM `models/run.py:35-50` | run FK, sequence, coords, optional telemetry/time; no unique `(run,sequence)` constraint |
| `PinValidation` | ORM `models/pin_validation.py:8-19` | marker/user FKs and confirmed; unique `(marker_id,user_id)`; marker delete-orphan |
| `RouteGenerateRequest`, `RoutePlanResponse` | Pydantic `schemas/route.py:4-28` | generated route input/output |
| `RunStart`, `RunFinish`, `RunPointCreate/Response`, `RunResponse` | Pydantic `schemas/run.py:6-61` | tracking, point and statistics/AI projections |
| `HazardMarkerValidate` | Pydantic `schemas/map.py:37-39` | `confirmed:bool`; disconnected because endpoint is missing |

`ai_insight` is Progress I output but physically embedded in the shared/PII `Run` and `RunResponse`; `ai_reasoning` is displayed with it; recommendation presentation is Progress II.

## C. Shared structures

| Structure | Type/source | Purpose |
|---|---|---|
| `Base` | SQLAlchemy declarative base `db/base.py:4-5` | Metadata root |
| `TimestampMixin` | mixin `models/base.py:7-11` | server-created and on-update timestamps |
| `Settings` | Pydantic settings `core/config.py:5-51` | environment/config DTO; defaults include insecure development secrets |
| `AnalysisResult` | dataclass `services/analysis_service.py:13-18` | `insight`, `reasoning`, `recommendations:list[str]` |
| `EmergencyContact` and schemas | ORM/DTO `models/emergency_contact.py`; `schemas/contact.py` | profile-adjacent feature outside requested PI list |

## Flutter models and controller state

All are in `mobile/lib/core/models.dart`; JSON factories use casts/defaults and parse timestamps where present.

| Structure | Scope | Attributes / serialization |
|---|---|---|
| `HealthResponse` | Shared | status; `fromJson` |
| `AuthToken` | PI | accessToken/tokenType from snake_case JSON |
| `UserProfile` | PI/shared | account and role fields; `fromJson` |
| `RoutePoint` | PI/shared | lat/lng; `toJson`; transient draft point, not a DB model |
| `ManualRouteItem` | PI | id/name/path/snapped path/distance/validation; parses JSON-string paths |
| `HazardMarkerItem` | PI/shared | pin fields, label getter, ISO expiry parse |
| `BaseMapData`, `MapNodeItem`, `MapEdgeItem` | Shared/PII | aggregate and graph DTOs; edge geometry JSON parsed |
| `RunItem`, `RunPointItem`, `RunPointUpload` | PII/shared AI | tracking/stats/AI; upload `toJson` |
| `RoutePlanItem` | PII | generated-route DTO and path JSON parser |
| `AdminStats`, `AdminUserItem` | PI/shared | admin dashboard/user projections |

`AuthController` (`auth_controller.dart:7-280`) is the important controller state object: `_api`, `_token`, `_currentUser`, `_isRestoring`; getters expose authentication/admin state. It extends `ChangeNotifier`, persists token under `runna_access_token`, restores through `/me`, and clears invalid sessions. Screen-specific `_isLoading`, draft point, lists and errors reside in individual State objects rather than separate controllers.

## D. Unused/apparently disconnected

- `HazardMarkerValidate`: referenced by tests/mobile but no backend validate route.
- `manual_route_to_response`: no call found; route handlers use `model_validate`.
- `Settings.cors_origins`: validator exists, middleware ignores it.
- `MapNode.osm_id`: migration/service concern not represented by ORM.
- No persistent `RoutePoint` exists for manual routes; raw and snapped points are JSON strings. Do not add one to the SDD.
