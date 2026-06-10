# Runna

Runna is a route-centric running platform built for the CMU Software Engineering senior project. It combines manual route creation, collaborative hazard reporting, run tracking, and AI-based performance analysis.

## Stack

- **Mobile:** Flutter (Android / iOS / Web)
- **Backend:** FastAPI
- **Database:** PostgreSQL + PostGIS
- **Maps:** OpenStreetMap tiles
- **AI:** Gemini API (optional; rule-based fallback included)

## Features

| Feature | Description |
|--------|-------------|
| Authentication | Register, login, logout, RBAC (guest / member / admin) |
| Manual routes | Draw and save custom routes on an interactive map |
| Hazard pins | Report, view, confirm, and auto-expire community hazards |
| Run tracking | Distance, duration, pace, step count |
| AI analysis | Post-run insight, reasoning, and recommendations |
| Admin dashboard | User management, stats, hazard moderation |

## Quick start

### 1. Environment

```powershell
Copy-Item .env.example .env
```

Optional: set `GEMINI_API_KEY` in `.env` for Gemini-powered summaries.

### 2. Start backend + database

```powershell
docker compose up --build
```

API docs: [http://localhost:8000/docs](http://localhost:8000/docs)

Migrations run automatically on container start.

### 3. Run the mobile app

```powershell
cd mobile
flutter pub get
flutter run
```

**Android emulator API URL:**

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

**Physical device (replace with your PC IP):**

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000/api
```

## Default accounts

| Role | Email / Username | Password |
|------|------------------|----------|
| Admin | `admin@runna.local` / `runna_admin` | `admin1234` |
| Member | Register in the app | Your choice |

Guests can browse the map and hazard pins without signing in.

## Project structure

```
backend/          FastAPI API, services, migrations
mobile/           Flutter app
docs/             Architecture notes
docker-compose.yml
```

## API overview

- `POST /api/auth/register` — create member account
- `POST /api/auth/login` — obtain JWT
- `GET /api/map/base` — map nodes, edges, hazard pins
- `POST /api/map/manual-routes` — save drawn route
- `POST /api/map/markers` — create hazard pin
- `POST /api/map/markers/{id}/validate` — confirm or dismiss pin
- `POST /api/runs/start` — start run session
- `POST /api/runs/{id}/finish` — finish run + AI analysis
- `GET /api/admin/stats` — admin dashboard stats

## Notes

- Hazard pins expire after `PIN_EXPIRY_HOURS` (default 24) unless confirmed by nearby users.
- AI analysis works without Gemini using built-in rule-based logic.
- Map seed data centers on Chiang Mai University for demo use.
