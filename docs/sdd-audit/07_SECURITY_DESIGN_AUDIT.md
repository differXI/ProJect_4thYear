# Security design audit

No discovered secret value is reproduced. Configuration defaults are described, not copied as credentials.

## Findings table

| Security ID | Area | Actual Implementation | Source Evidence | Status | Risk | Required SDD Wording | Recommended Code Follow-up |
|---|---|---|---|---|---|---|---|
| SEC-001 | Password hashing | Passlib PBKDF2-SHA256 | `security.py:8-16` | PASS | Low | Passwords stored as PBKDF2 hashes | Consider Argon2id policy/migration |
| SEC-002 | OTP hashing | Same PBKDF2 helper | `auth_service.py:73-77` | PASS | Low | Raw OTP never persisted | Separate context/pepper optional |
| SEC-003 | JWT | HS256 configured; `sub`,`exp` only | `security.py:19-26` | PASS | Medium | Signed access token with subject and expiry | Add issuer/audience/type/jti |
| SEC-004 | Expiration | Default 60 minutes, configurable | `config.py:10`; `security.py:20` | PASS | Low | State configured duration | Validate positive bounds |
| SEC-005 | Decode | PyJWT signature/algorithm/exp validation | `security.py:25-26` | PASS | Low | Invalid token yields 401 | Narrow caught exceptions |
| SEC-006 | Active enforcement | Protected dependency rejects inactive | `auth_service.py:183-185` | PASS | Low | Every protected request rechecks active state | Login should reject inactive before token issuance |
| SEC-007 | Role enforcement | admin service or inline role equality | admin/map routers | PARTIAL | Medium | Admin endpoints recheck DB role | Centralize admin dependency |
| SEC-008 | Ownership | run/manual route services compare user ID; lists filter owner | `map_service.py:291-305`; `run_service.py:37-45` | PASS | Low | Nonowner hidden as 404 | Add denial tests |
| SEC-009 | Enumeration | forgot always fixed 200 after valid schema | `auth.py:42-51` | PASS | Timing still differs | Response content/status identical | Add timing equalization/rate limits |
| SEC-010 | OTP generation | `secrets.randbelow(1_000_000)` six digits | `auth_service.py:72-74` | PASS | Brute force bounded only by DB attempts | CSPRNG six-digit code | Add IP/account throttling |
| SEC-011 | Expiry/reuse/binding/delivery | user-bound, delivered, unused, expiry query; all codes invalidated | `auth_service.py:137-166` | PASS | Low | State exact gates | Add DB index for lookup |
| SEC-012 | Attempt boundary | reject when existing count >=5; wrong attempts committed | `auth_service.py:149-155` | PASS | Low | Five failed attempts allowed then blocked | Clarify boundary in SDD |
| SEC-013 | Timing resistance | Passlib verify; unknown email avoids hash work | auth service | PARTIAL | Account timing signal possible | Do not claim constant overall timing | Dummy hash/rate limit |
| SEC-014 | Atomic reset | user/code locked; password and invalidation one commit | `auth_service.py:125-170` | PASS | Low | Reset update atomic under DB row locks | Concurrency tests on PostgreSQL |
| SEC-015 | Session rollback | get_db only closes; selected auth paths rollback | `deps.py:8-13`; auth service | PARTIAL | Failed sessions may remain poisoned until close | Do not claim global automatic rollback | Add dependency rollback-on-exception |
| SEC-016 | Email failure | false marks code used; exceptions after first commit can leave undelivered unusable row | `auth_service.py:98-123`; email service | PASS | Low | Failed delivery creates no actionable code | Retry/outbox operationally |
| SEC-017 | Sensitive logs | reset logs fixed strings; global logger logs URL+traceback; RunService prints Gemini/errors and stores exception text | auth/main/run service | FAIL | High | Never claim all sensitive errors sanitized | Remove prints/error text; structured redaction |
| SEC-018 | SMTP credentials | settings/env and `smtp.login`; not logged | config/email | PASS | Medium ops | Credentials are environment-supplied | Secret manager/manual verify deployment |
| SEC-019 | Environment defaults | default JWT/admin/database credentials and debug true | `config.py:8-15,31-33`; seed | FAIL | Critical if deployed unset | Defaults are development-only and unsafe | Fail startup outside development; remove default admin password |
| SEC-020 | Hardcoded credentials | insecure defaults exist; actual env not reported | config/seed | FAIL | Critical | No production hardcoded credentials guarantee exists | Require explicit secrets and rotation |
| SEC-021 | CORS | hard-coded 3 origins; allow credentials/methods/headers; config ignored | `main.py:33-43` | PARTIAL | Medium | List actual fixed origins | Use validated `cors_origins`; environment policy |
| SEC-022 | SQL injection | SQLAlchemy expression APIs; Overpass query interpolates floats already parsed | services | PASS | Low | ORM parameterization used | Maintain typed validation |
| SEC-023 | Input validation | Pydantic lengths/severity, but no lat/lng bounds; admin risk/filter/import bounds unconstrained | schemas/map.py; map.py | PARTIAL | Medium | State exact bounds only | Add coordinate/risk/bbox/category enums |
| SEC-024 | Admin restrictions | role schema member/admin; no self-deactivate/demotion or last-admin guard | admin service | FAIL | High | Admin may alter own/last admin account | Add invariants and audit log |
| SEC-025 | Timezones | UTC aware Python and timezone DB columns; SQLite/Postgres behavior needs integration verification | auth/run models | PASS | Medium | Use UTC-aware timestamps | PostgreSQL integration tests |
| SEC-026 | Locks/races | reset uses `FOR UPDATE`; run-point next sequence and registration uniqueness race rely on DB and may 500 | auth/run service | PARTIAL | Medium | Only reset flow is explicitly locked | Unique constraint sequence; catch IntegrityError |
| SEC-027 | Migration metadata | models imported; password reset included; MapNode `osm_id` migration/ORM drift; migration commits/swallowing | `models/__init__.py`; migrations | PARTIAL | High migration reliability | Metadata is imported but drift exists | Clean follow-up revision; test fresh upgrade |
| SEC-028 | Flutter token storage | `shared_preferences` plaintext storage | `auth_controller.dart:23-53` | FAIL | High on compromised device | Token is not secure-keystore protected | Use secure storage |
| SEC-029 | Duplicate prevention | screen `_isLoading/_isActing` disable buttons | auth/routes/hazards/admin screens | PASS | Low | UI guards duplicate actions | Server idempotency for writes |
| SEC-030 | Controller disposal | app removes listener/disposes; screens dispose controllers/map where implemented | `main.dart:34-39`; screens | PASS | Low | Lifecycle disposal implemented | Continue tests |
| SEC-031 | HTTP/TLS | URL compile-time; no pinning/transport enforcement in client | `app_config.dart`; `runna_api.dart` | NEEDS MANUAL VERIFICATION | High if HTTP configured | Production requires HTTPS | Reject non-HTTPS release URL/pinning decision |
| SEC-032 | Gemini response/logging | caller prints insight/error; exception may be persisted and exposed | `run_service.py:223-249` | FAIL | High | AI errors must be generic; no response content logs | Replace with sanitized logger; don't persist exception text |
| SEC-033 | Debug/trace exposure | response generic 500; server traceback logged; debug defaults true may alter behavior | `main.py:26-53`; config | PARTIAL | High production | Production debug false; generic client errors | Fail-safe env config/manual deploy verify |
| SEC-034 | Public import | OSM import requires no authentication and deletes graph | `map.py:57-68`; map service | FAIL | Critical | Endpoint is public in current code (PII) | Require admin; transaction and validation |
| SEC-035 | Logout/revocation | local deletion only; JWT valid until expiry | controller `106-111`; no endpoint | PARTIAL | Medium | Logout clears client token only | Token revocation/short expiry/rotation |
| SEC-036 | Count query integrity | joining runs and pins can multiply both counts | `admin_service.py:50-84` | FAIL | Medium correctness/security decisions | Counts are aggregate projections, potentially inaccurate | distinct/subqueries |

## A. Verified protections

PBKDF2 hashing, CSPRNG OTP, signature/expiry decoding, active-account checks on protected calls, admin/owner checks, enumeration-safe response text, delivery/expiry/reuse/user binding, maximum attempts, reset row locks and atomic credential update, sanitized auth logging, ORM queries, and UI duplicate/disposal guards are implemented.

## B. Unsupported documentation-only claims

Do not claim global session rollback, secure mobile keystore, server-side logout/revocation, constant-time whole-flow forgot handling, environment-driven CORS, production-safe defaults, a standalone AI endpoint, or a protected marker list/import endpoint.

## C. Implementation issues

Critical: public destructive map import; unsafe default secrets/admin password/debug. High: plaintext mobile token, no admin invariants, Gemini/error leakage, migration drift, deployment TLS uncertainty. Medium: login issues inactive token, input gaps, registration/run-point races, no global rollback, CORS drift, multiplied admin counts.

## D. Low-priority observations

JWT lacks issuer/audience/jti; SMTP has no outbox; status/category values are strings rather than enums; no API rate limiting is visible.

## E. Progress II security behavior

Map import/graph admin, route generation, GPS points, pin validation/lifecycle/moderation, and tracking must be placed in a separate Progress II security subsection. Their risks must not be presented as Progress I detailed design except where they underpin PI map display or AI finish flow.
