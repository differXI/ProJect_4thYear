# Runna Architecture

## Overview

Runna follows a client-server architecture aligned with the senior project proposal.

```
Flutter Mobile App
        |
        | REST / JWT
        v
   FastAPI Backend
        |
        +--> PostgreSQL / PostGIS
        +--> Gemini API (optional)
        +--> OpenStreetMap tiles (client-side)
```

## Subsystems

1. **Authentication & RBAC** — guest browsing, member features, admin moderation
2. **Manual Route Creation** — geospatial route storage as coordinate polylines
3. **Collaborative Hazard Pins** — user reports, validation loop, automatic expiration
4. **Run Tracking** — session lifecycle with distance, duration, pace, steps
5. **AI Performance Analysis** — structured metrics + Gemini or rule-based summaries
6. **Admin Dashboard** — users, stats, hazard moderation

## Data flow (post-run analysis)

1. Mobile finishes a run with metrics
2. Backend calculates pace and compares recent history
3. Analysis service builds structured summary
4. Gemini API generates natural language output when configured
5. Results stored on the run record and returned to the app

## Pin lifecycle

1. Member creates pin with category, severity, location
2. Nearby members confirm ("still there") or dismiss ("resolved")
3. Confirmations extend expiry window
4. Multiple dismissals or timeout mark pin as expired
