# Robomos Poke - customer app

The Flutter app customers use to order: menu, bowl builder, cart, checkout, live order tracking,
reviews, saved bowls, points and their account. Every screen talks to the RoboKitchen API through
`lib/services/` (`robokitchen_api.dart` has one method per endpoint); `lib/app_state.dart` holds the
latest copy of what the server returned.

## Run

Start the backend first (from the project root):

```bash
MONGODB_URL=mongomock:// SEED_ON_STARTUP=true uvicorn app.main:app --port 8000
```

Then, in this folder:

```bash
flutter pub get
flutter run -d chrome          # any localhost port is allowed by CORS outside production
flutter test                   # widget tests against an in-memory fake of the API
flutter analyze
```

Demo customer: `customer@robokitchen.com` / `Customer123`.

## Which server it talks to

* Chrome, Windows, iOS simulator: `http://localhost:8000/api/v1`
* Android emulator: `http://10.0.2.2:8000/api/v1`
* Anything else: `flutter run --dart-define=API_BASE_URL=https://your-server/api/v1`

Opening the web build at `/?table=CODE` (a table's QR code) skips the table number screen, and
`/reset-password?token=...` (the reset email link) opens the new-password screen.
