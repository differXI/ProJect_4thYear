# Required document corrections

Claims are summarized from the comparison targets where identifiable; if wording/version is unclear, “current claim” records the common documented implication requiring confirmation.

| Document Section | Current Claim | Actual Implementation | Required Correction | Severity |
|---|---|---|---|---|
| Login request | Email-only login | Field is `username_or_email`; lookup accepts exact username or email | Replace contract and diagrams | Major |
| Login active check | Login rejects inactive | Login can issue token; protected `/me` rejects inactive | Describe two-step behavior; recommend fix | Major |
| User model | Different/minimal fields | id, first/last, username, email, password_hash, province?, active, role_id, timestamps | Use exact ORM/migration fields | Major |
| Role model | Role embedded/string | Separate roles table: id/name unique/description?/timestamps | Correct ERD/cardinality | Major |
| Route points | Persistent RoutePoint rows | Manual route raw/snapped points are JSON strings | Remove invented model/table | Critical |
| Route JSON | Unspecified geometry | raw array `{lat,lng}`; snapped same shape; validation object parsed by property | Document exact structures/parser fallback | Major |
| Validation/snapping | Either absent or generated-route algorithm | Manual-route save performs nearest-edge snapping/validation; Dijkstra belongs PII | Separate these algorithms/scopes | Major |
| Clear Points | Backend deletion endpoint | Only `_draftPoints.clear()` local state; no API/DB | Make client-only alternative flow | Critical |
| Route deletion | Generic delete | Owner check; 404 for missing/nonowner; run FKs set null; hard delete/commit | Correct sequence and delete semantics | Major |
| Hazard fields | Different category/status structure | marker_type, severity 1..5, coords, optional note, status/counters/expiry | Use exact fields; lifecycle fields PII | Major |
| Hazard listing | Protected | `/api/map/markers` is public | Correct access control | Critical |
| Hazard validation | Implemented | Mobile/test/schema reference endpoint but backend route missing | Mark disconnected PII, not implemented | Critical |
| AI endpoint | Standalone generate API | No standalone API; run finish invokes analysis synchronously | Redraw sequence around finish endpoint | Critical |
| AI fields | One summary/recommendation object | Three nullable text columns: insight/reasoning/recommendations | Correct persistence/response | Major |
| AI recommendations | Progress I | Presentation explicitly PII per scope | Exclude from PI detailed design | Major |
| Admin response | Basic user list | includes role_name plus run_count/pin_count; query can multiply counts | Correct schema and flag count defect | Major |
| Admin update restrictions | Protected invariants | admin can activate/deactivate and assign member/admin, including self/last admin | Remove unsupported safeguards | Critical |
| API prefix | Other/versioned prefix | Actual global prefix `/api`; root `/` outside | Correct every path | Critical |
| Map aliases | One endpoint | Both `/api/map/` and `/api/map/base`; mobile uses `/base` | Record alias/client usage | Minor |
| Password reset fields | Different names/OTP shape | email, six-digit `code`, new_password, confirm_password | Correct DTOs | Major |
| Attempt boundary | Block on fifth submitted attempt ambiguously | Wrong attempts increment through 5; future calls blocked when stored count >=5 | State exact boundary | Major |
| Reset delivery | Created code always usable | Only delivered_at non-null accepted; failed delivery marks used | Correct state machine | Major |
| Reset atomicity | One transaction including email | Prepare commit, SMTP, delivery-state commit; reset credential change is atomic separately | Correct transaction boundaries | Major |
| Session rollback | Dependency automatically rolls back | `get_db` only closes; specific auth methods rollback | Remove global rollback claim | Major |
| Timezones | Naive/local | Python uses UTC-aware for auth/run; DB timezone columns; server defaults | State actual UTC use and integration caveat | Minor |
| CORS | Environment-driven | Middleware hard-codes three origins; parsed setting unused | Correct and flag drift | Major |
| JWT/logout | Logout invalidates token server-side | Client clears shared_preferences only; JWT remains valid until expiry | Correct logout sequence | Critical |
| Password algorithm | bcrypt/other | PBKDF2-SHA256 Passlib | Correct security design | Major |
| OTP algorithm | raw/encrypted OTP | PBKDF2-SHA256 hash, CSPRNG six digits | Correct reset design | Major |
| Admin authorization | One shared role dependency | admin router uses service check; map-admin uses inline equality | Describe both actual patterns | Minor |
| Gemini logging | Sanitized/no logs | run service prints insight and exception, persists some exception text | Do not claim sanitization | Critical |
| Exception exposure | Stack trace returned | global handler returns generic 500 but logs traceback/URL; debug default true | Correct response/log distinction | Major |
| Deployment secrets | Safe required env | insecure development defaults exist for JWT/admin/DB; actual secrets not reported | Mark unsafe defaults and production requirement | Critical |
| Progress scope | Tracking/history/GPS/pin lifecycle/moderation/Dijkstra/OSM mixed into PI | Those are PII, though code exists and some underpins PI | Move to separate PII inventory | Critical |
| Tests | Full PI coverage | No admin/RBAC/ownership/AI service tests; map test expects missing validation route | Correct verification claims | Major |
| Migration consistency | Clean linear schema | Linear heads, but 20260615 revision repeats columns, commits/swallow exceptions; ORM/migration drift | Add migration limitations | Major |

Existing SRS/SDD/Test Plan/Traceability/Test Record should use source and executed verification as evidence. Any requirement ID assignment that cannot be matched unambiguously must remain `Needs document confirmation`, not guessed.
