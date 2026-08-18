# Method catalog

Line ranges are exact for the audited checkout. Repeated framework details are stated explicitly rather than inferred from documents.

## Router layer

### MD-ROUTER-001 `register`
| Field | Description |
|---|---|
| Source File | `backend/app/api/routes/auth.py:26-30` |
| Class / Module | `app.api.routes.auth` |
| Layer | Router |
| Signature | `register(payload: UserRegister, db: Session = Depends(get_db)) -> UserResponse` |
| Purpose | Register and serialize a member. |
| Parameters | `payload`: validated registration; `db`: request session. |
| Return | `UserResponse` |
| Validation | Pydantic; uniqueness/service role check. |
| Database Reads | users, roles |
| Database Writes | one user |
| Transaction Behavior | service commit/refresh; no router rollback |
| Authorization | Public |
| External Calls | none |
| Logging | none |
| Exceptions | service 400 duplicate, 500 missing role; validation 422 |
| Side Effects | Account and password hash created |
| Related API | POST `/api/auth/register` |
| Related Models/Schemas | User, Role, UserRegister, UserResponse |
| Progress Scope | Progress I |
| Related Requirement | Registration; identifiers need document confirmation |
| Documentation Notes | Member role is assigned server-side. |

### MD-ROUTER-002 `login`
| Field | Description |
|---|---|
| Source File | `backend/app/api/routes/auth.py:33-39` |
| Class / Module | auth router |
| Layer | Router |
| Signature | `login(payload: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse` |
| Purpose | Authenticate username or email and return bearer JWT. |
| Parameters | payload; session |
| Return | TokenResponse |
| Validation | 3..255 identifier, password 8..128; PBKDF2 verification |
| Database Reads | users |
| Database Writes | none |
| Transaction Behavior | no transaction |
| Authorization | Public |
| External Calls | none |
| Logging | none |
| Exceptions | service raises 401; router's `None` branch is unreachable |
| Side Effects | JWT issued |
| Related API | POST `/api/auth/login` |
| Related Models/Schemas | LoginRequest, TokenResponse, User |
| Progress Scope | Progress I |
| Related Requirement | Login; IDs need confirmation |
| Documentation Notes | Field is `username_or_email`, not email-only. Login does not itself reject inactive users; subsequent `/me` does. |

### MD-ROUTER-003 `forgot_password`
| Field | Description |
|---|---|
| Source File | `backend/app/api/routes/auth.py:42-51` |
| Class / Module | auth router |
| Layer | Router |
| Signature | `forgot_password(payload: ForgotPasswordRequest, db: Session = Depends(get_db)) -> GenericMessageResponse` |
| Purpose | Request enumeration-safe reset delivery. |
| Parameters | valid email; session |
| Return | fixed generic message |
| Validation | EmailStr; service active-user gate |
| Database Reads | users/reset codes |
| Database Writes | invalidate and create/reset delivery state |
| Transaction Behavior | service commits twice/rolls back; router swallows all errors |
| Authorization | Public |
| External Calls | SMTP when enabled |
| Logging | sanitized fixed error only |
| Exceptions | all service exceptions caught |
| Side Effects | possible email |
| Related API | POST `/api/auth/forgot-password` |
| Related Models/Schemas | ForgotPasswordRequest, PasswordResetCode |
| Progress Scope | Progress I |
| Related Requirement | Forgot Password; IDs need confirmation |
| Documentation Notes | Always HTTP 200 after schema validation. |

### MD-ROUTER-004 `reset_password`
| Field | Description |
|---|---|
| Source File | `backend/app/api/routes/auth.py:54-66` |
| Class / Module | auth router |
| Layer | Router |
| Signature | `reset_password(payload: ResetPasswordRequest, db: Session = Depends(get_db)) -> GenericMessageResponse` |
| Purpose | Consume a delivered OTP and replace password. |
| Parameters | email, six-digit code, matching new/confirm passwords; session |
| Return | success message |
| Validation | schema and locked service checks |
| Database Reads | users/reset codes |
| Database Writes | password hash, all unused codes used_at; wrong-attempt count |
| Transaction Behavior | commit; rollback on exception |
| Authorization | Public |
| External Calls | none |
| Logging | sanitized error |
| Exceptions | 400 generic; 422 schema |
| Side Effects | credential changes |
| Related API | POST `/api/auth/reset-password` |
| Related Models/Schemas | ResetPasswordRequest, User, PasswordResetCode |
| Progress Scope | Progress I |
| Related Requirement | Reset Password; IDs need confirmation |
| Documentation Notes | Fifth wrong attempt is committed; valid verification is blocked when count is already 5. |

### Router method index

Each entry is a distinct real method. “Auth” includes active-user enforcement through `get_current_user`; owner checks are in services.

| ID | Method; source | Signature / actual behavior | Reads/Writes; transaction | Authorization; scope |
|---|---|---|---|---|
| MD-ROUTER-005 | `healthcheck`; `health.py:6-8` | `async () -> dict[str,str]`; status | none | Public; Shared |
| MD-ROUTER-006 | `get_me`; `users.py:11-16` | current user serialization | User read | Auth; Shared |
| MD-ROUTER-007 | `update_me`; `users.py:19-27` | `UserUpdate` profile | User write; commit/refresh | Auth/self; Shared |
| MD-ROUTER-008 | `list_emergency_contacts`; `users.py:30-37` | list contacts | contacts read | Auth/self; Shared |
| MD-ROUTER-009 | `create_emergency_contact`; `users.py:40-50` | create contact | insert; commit/refresh | Auth/self; Shared |
| MD-ROUTER-010 | `get_base_map`; `map.py:35-43` | aggregate nodes/edges/markers | reads | Public; Shared |
| MD-ROUTER-011 | `get_base_map_alias`; `map.py:46-54` | same as preceding | reads | Public; Shared |
| MD-ROUTER-012 | `import_map`; `map.py:57-68` | bbox query, destructive OSM import | deletes/inserts; router commit | **Public**; PII; external Overpass |
| MD-ROUTER-013 | `list_markers`; `map.py:71-75` | active/nonexpired public pins | markers read/update expiry | Public; PI view/PII lifecycle |
| MD-ROUTER-014 | `create_marker`; `map.py:78-86` | create active pin | marker insert commit/refresh | Auth; PI |
| MD-ROUTER-015 | `list_manual_routes`; `map.py:89-96` | owned list | routes read | Auth/owner list; PI |
| MD-ROUTER-016 | `create_manual_route`; `map.py:99-107` | save raw/snapped JSON | graph reads, route insert commit | Auth; PI |
| MD-ROUTER-017 | `delete_manual_route`; `map.py:110-117` | owner delete | route/run update/delete commit | Auth/owner; PI |
| MD-ROUTER-018 | `override_edge`; `map.py:119-131` | update risk/forbidden | edge write commit | Admin inline; PII |
| MD-ROUTER-019 | `approve_marker`; `map.py:133-144` | status active/removed | marker write commit | Admin inline; PII |
| MD-ROUTER-020 | `rebuild_graph`; `map.py:146-155` | ensure seed | graph reads/maybe inserts | Admin inline; PII |
| MD-ROUTER-021 | `list_high_risk`; `map.py:157-167` | threshold list | edges read | Admin inline; PII |
| MD-ROUTER-022 | `list_routes`; `routes.py:12-19` | generated plans | route_plans read | Auth/owner; PII |
| MD-ROUTER-023 | `generate_route`; `routes.py:22-30` | Dijkstra-like plan | graph read/plan insert commit | Auth; PII |
| MD-ROUTER-024 | `list_runs`; `runs.py:12-19` | owned history | runs read | Auth/owner; PII |
| MD-ROUTER-025 | `start_run`; `runs.py:22-30` | auto-close existing then create | runs/points write commit | Auth; PII |
| MD-ROUTER-026 | `get_run`; `runs.py:33-41` | owned run | run read | Auth/owner; PII/shared AI |
| MD-ROUTER-027 | `list_run_points`; `runs.py:44-52` | owned points | run/points read | Auth/owner; PII |
| MD-ROUTER-028 | `add_run_points`; `runs.py:55-64` | append sequence points | read max/insert commit | Auth/owner; PII |
| MD-ROUTER-029 | `finish_run`; `runs.py:67-79` | statistics + AI | reads/writes run; commit | Auth/owner; PI AI over PII |
| MD-ROUTER-030 | `get_stats`; `admin.py:32-39` | aggregate dashboard | all counts | Admin; mixed |
| MD-ROUTER-031 | `list_users`; `admin.py:42-49` | admin user projections | joins users/runs/pins | Admin; PI |
| MD-ROUTER-032 | `update_user`; `admin.py:52-74` | active/role patch | user/role; commit | Admin; PI |
| MD-ROUTER-033 | `list_markers`; `admin.py:77-86` | moderation list | markers read | Admin; PII |
| MD-ROUTER-034 | `delete_marker`; `admin.py:89-98` | soft remove | marker update commit | Admin; PII |
| MD-ROUTER-035 | `root`; `main.py:56-58` | app message | none | Public; Shared |
| MD-ROUTER-036 | `unhandled_exception_handler`; `main.py:47-53` | sanitized 500, traceback log | none | Shared |

## Dependencies, security, DB, startup, serializers

| ID | Exact method; source | Signature / purpose | Transactions, errors, calls | Scope / notes |
|---|---|---|---|---|
| MD-DEP-001 | `get_db`; `api/deps.py:8-13` | `() -> Generator[Session,None,None]`; yield and close | no rollback | Shared; SDD must not claim rollback |
| MD-DEP-002 | `get_current_user`; `auth_service.py:173-186` | credentials+db -> User | decode JWT, int sub, DB get; 401 invalid/inactive | Shared auth |
| MD-SEC-001 | `hash_password`; `security.py:11-12` | str -> PBKDF2-SHA256 hash | CPU only | Shared |
| MD-SEC-002 | `verify_password`; `security.py:15-16` | plaintext/hash -> bool | Passlib constant-time implementation assumption | Shared |
| MD-SEC-003 | `create_access_token`; `security.py:19-22` | subject -> HS256 JWT | `sub`,`exp` only | PI |
| MD-SEC-004 | `decode_access_token`; `security.py:25-26` | token -> dict | PyJWT validates signature/exp | PI |
| MD-DB-001 | `run_migrations_offline`; `alembic/env.py:19-29` | configure literal offline migration | Alembic transaction | Shared |
| MD-DB-002 | `run_migrations_online`; `alembic/env.py:32-43` | NullPool engine migration | Alembic transaction | Shared |
| MD-START-001 | `lifespan`; `main.py:16-23` | async context startup seed | closes session, no catch | Shared |
| MD-START-002 | `seed_initial_data`; `seed_service.py:11-59` | roles/admin/map seed | several commits; defaults are insecure | Shared |
| MD-SER-001 | `user_to_response`; `serializers.py:9-20` | User -> UserResponse | touches role lazy relation | PI/shared |
| MD-SER-002 | `manual_route_to_response`; `serializers.py:23-39` | route -> response | unguarded JSON parse | PI, apparently unreferenced |

## Service methods

| ID | Exact method; source | Parameters / return | Actual reads, writes, authorization, exceptions, external calls |
|---|---|---|---|
| MD-AUTH-001 | `AuthService.__init__`; `auth_service.py:22-24` | db, optional email service | dependency assignment |
| MD-AUTH-002 | `register`; `:26-48` | UserRegister -> User | queries users/role; hashes; insert commit/refresh; 400/500 |
| MD-AUTH-003 | `login`; `:50-60` | LoginRequest -> TokenResponse | user lookup/verify/JWT; 401; no active check |
| MD-AUTH-004 | `forgot_password`; `:62-123` | email -> None | locks active user; invalidates/creates/flushes/commits; SMTP; second commit; rollback |
| MD-AUTH-005 | `reset_password`; `:125-170` | ResetPasswordRequest -> bool | locks user/code; attempt commit or atomic password/code commit; rollback |
| MD-EMAIL-001 | `send_password_reset_code`; `email_service.py:11-42` | recipient/code/minutes -> bool | SMTP STARTTLS/login/send; sanitized logs; catches OS/SMTP errors |
| MD-MAP-001 | `ensure_seed_map`; `map_service.py:28-75` | -> None | seed graph and demo markers; commit |
| MD-MAP-002 | `ensure_real_map`; `:77-78` | -> None | alias to seed, misleading name |
| MD-MAP-003 | `import_osm_data`; `:80-183` | bbox -> None | Overpass; deletes graph/inserts; PII; service transaction finalized by router |
| MD-MAP-004 | `get_base_map`; `:185-190` | -> tuple | calls marker lifecycle update and reads graph |
| MD-MAP-005 | `create_marker`; `:192-205` | user,payload -> marker | insert active; commit/refresh |
| MD-MAP-006 | `list_markers`; `:207-215` | -> list | expiry status update/commit then nonremoved list |
| MD-MAP-007 | `create_manual_route`; `:217-289` | user,payload -> ManualRoute | requires >=2; calculates/snaps/warnings; JSON insert commit; 400 |
| MD-MAP-008 | `list_manual_routes`; `:291-294` | user_id -> list | owned ordered query |
| MD-MAP-009 | `delete_manual_route`; `:296-305` | user,route_id -> None | 404 hides nonowner; sets run FK null, hard delete, commit |
| MD-MAP-010 | `_edge`; `:307-325` | nodes/road values -> MapEdge | builds geometry JSON |
| MD-ADMIN-001 | `require_admin`; `admin_service.py:20-26` | User -> None | 403 unless role admin |
| MD-ADMIN-002 | `get_stats`; `:28-48` | -> dict | seven aggregate reads |
| MD-ADMIN-003 | `list_users`; `:50-84` | -> list[dict] | outer joins; **counts can be multiplied by run×pin join** |
| MD-ADMIN-004 | `update_user`; `:86-104` | id,payload -> User | role lookup/user update commit; no self/last-admin guard |
| MD-ADMIN-005 | `delete_marker`; `:106-114` | id -> None | soft remove commit |
| MD-ADMIN-006 | `list_markers`; `:116-123` | filter -> list | status filter is unconstrained |
| MD-ADMIN-007 | `override_edge_risk`; `:125-136` | id,score,forbidden -> edge | no score validation; commit |
| MD-ADMIN-008 | `approve_hazard_marker`; `:138-148` | id,approved -> marker | active/removed commit |
| MD-ADMIN-009 | `list_high_risk_edges`; `:150-158` | threshold -> list | read |
| MD-ADMIN-010 | `rebuild_map_graph`; `:160-163` | -> dict | only ensures seed |
| MD-ROUTE-001 | `generate_route`; `route_service.py:20-69` | user,request -> RoutePlan | graph/Dijkstra and insert commit; PII |
| MD-ROUTE-002 | `_build_preview_path`; `:71-85` | coords/distance/type -> points | deterministic geometry |
| MD-ROUTE-003 | `list_routes`; `:87-89` | user -> list | owner query |
| MD-ROUTE-004..008 | helpers; `:91-165` | map load, anchor, nearest node, Dijkstra, risk | graph reads; PII |
| MD-RUN-001..010 | `RunService` methods; `run_service.py:29-391` | get/start/finish/points/list/calculations | owner checks; commits; Gemini on finish; PII except AI result |
| MD-AI-001 | `AnalysisService.analyze`; `analysis_service.py:41-62` | metrics/history -> AnalysisResult | local summary then Gemini depending config |
| MD-AI-002 | `_build_structured_summary`; `:64-112` | data -> AnalysisResult | deterministic insight/reasoning/recommendations |
| MD-AI-003 | `_call_gemini`; `:114-247` | dict -> AnalysisResult | Google API; parses response; prints/logging concern in caller |
| MD-AI-004 | `_parse_json_response`; `:249-255` | text -> dict | strips fences/JSON decode |

## Flutter methods

`RunnaApi` methods map one-to-one to endpoints: `getHealth` 22-28, `register` 30-52, `login` 54-70, `forgotPassword` 72-81, `resetPassword` 83-102, `getMe` 104-113, map/pin 115-171, manual routes 173-213, runs 215-305, generated routes 307-340, admin 342-406, `_ensureSuccess` 408-428. They JSON-encode bodies, add bearer headers, decode DTOs, and throw `RunnaApiException`; no retries/timeouts/TLS pinning.

`AuthController` methods at 23-280 restore/persist/clear session, wrap every API call, update cached route/run/admin lists, notify listeners on auth changes, and require a token for protected calls. `logout` (106-111) is purely local. Screen actions are distinct: Auth `_handleLogin` 66-85, `_handleRegister` 87-110, `_showForgotPassword` 112-298; Routes `_load` 46-67, `_handleMapTap` 69-77, `_goToMyLocation` 80-115, `_saveRoute` 117-139, `_deleteRoute` 141-155, `_polylinePoints` 157-160; Hazards `_load` 52-67, `_handleMapTap` 69-71, `_createPin` 73-106, `_validatePin` 108-124; Admin `_load` 35-51, `_loadStats` 53-62, `_loadUsers` 64-73, `_loadMarkers` 75-84, `_toggleUser` 86-97, `_changeRole` 99-111, `_removeMarker` 113-124. Loading flags disable duplicate UI actions and mounted checks protect async state.

## Static-reference and test discrepancies

- Defined/apparently unused: `manual_route_to_response`, `ensure_real_map`, `Settings.parse_cors_origins` output, unused `os` import, commented admin dependency.
- Missing route: mobile/tests call `POST /api/map/markers/{id}/validate`; no decorator implements it. `HazardMarkerValidate` is unused server-side.
- All router modules listed in `api/router.py` are registered; all models are imported through `app.models` for Alembic metadata.
- Services lacking direct tests: AdminService, UserService, EmailService integration, AnalysisService, seed, security helpers, OSM import. Existing tests exercise some indirectly.
- `test_map.py:47-53` disagrees with implementation due to the absent validate endpoint.
