# Runna Mobile

Flutter client for the Runna senior project.

## Run

```powershell
flutter pub get
flutter run
```

## Configure API

Default: `http://127.0.0.1:8000/api`

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

## Screens

- **Home** — overview and quick actions
- **Routes** — draw and save manual routes
- **Runs** — start/finish runs, view AI insights
- **Hazards** — report and validate community pins
- **Account** — sign in / register / sign out
- **Admin** — visible for admin users only
