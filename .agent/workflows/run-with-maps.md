---
description: How to run the Cruizr app with Google Maps
---

# Running Cruizr with Google Maps

The app uses `--dart-define` to securely pass the Google Maps API key at build time.

## Prerequisites (Google Cloud Console)

Your API key must have these APIs enabled:
1. **Maps SDK for Android** - for Android app
2. **Maps SDK for iOS** - for iOS app  
3. **Maps JavaScript API** - for web/Chrome

For web development, you may need to add `localhost` to the allowed referrers:
1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Click on your API key
3. Under "Application restrictions", choose "HTTP referrers"
4. Add: `http://localhost:*` and `http://127.0.0.1:*`

## Running on Android

// turbo-all

```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIzaSyBgaA-tr-3kyOaQtMmEogM6Nxdz7MozwqQ
```

## Running on iOS (requires Mac)

```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIzaSyBgaA-tr-3kyOaQtMmEogM6Nxdz7MozwqQ
```

## Running on Chrome/Web

```bash
flutter run -d chrome
```

> Note: For web, the API key is in `web/index.html`. Make sure the Maps JavaScript API is enabled.

## Building for Release

### Android APK
```bash
flutter build apk --dart-define=GOOGLE_MAPS_API_KEY=AIzaSyBgaA-tr-3kyOaQtMmEogM6Nxdz7MozwqQ
```

### iOS (requires Mac)
```bash
flutter build ios --dart-define=GOOGLE_MAPS_API_KEY=AIzaSyBgaA-tr-3kyOaQtMmEogM6Nxdz7MozwqQ
```

## VS Code Launch Configuration

Add to `.vscode/launch.json`:
```json
{
  "configurations": [
    {
      "name": "Cruizr (Debug)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "args": [
        "--dart-define=GOOGLE_MAPS_API_KEY=AIzaSyBgaA-tr-3kyOaQtMmEogM6Nxdz7MozwqQ"
      ]
    }
  ]
}
```

## Environment Variable (More Secure)

For CI/CD, use an environment variable:
```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY
```

