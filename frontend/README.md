# Zhouyi Flutter App

This is the Flutter frontend for the Liuyao agent project.

## Backend Connection

The app reads backend configuration from Dart defines.

Default local backend URLs:

- Android emulator: `http://10.0.2.2:3000/api/v1`
- Web, Windows, macOS, Linux: `http://localhost:3000/api/v1`

Override the business API URL:

```bash
flutter run --dart-define=BUSINESS_API_BASE_URL=http://localhost:3000/api/v1
```

Override only Liuyao agent API calls:

```bash
flutter run --dart-define=LIUYAO_API_BASE_URL=http://localhost:3000/api/v1
```

## Development Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

`flutter analyze` currently reports existing info-level lint items in older UI files. `flutter test` passes.

## Documentation

- Root setup guide: `../README.md`
- Docs index: `../docs/README.md`
