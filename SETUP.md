# Cruizr App - Complete Setup Guide

## Prerequisites

1. **Git**: [Download Git](https://git-scm.com/downloads)
2. **Flutter SDK**: [Install Flutter](https://docs.flutter.dev/get-started/install)
3. **Android Studio**: [Download Android Studio](https://developer.android.com/studio)

---

## Part 1: Android Studio Setup

### 1.1 Install Android Studio
1. Download and install Android Studio
2. During setup, ensure you install:
   - Android SDK
   - Android SDK Command-line Tools
   - Android SDK Build-Tools
   - Android Emulator

### 1.2 Install Flutter & Dart Plugins
1. Open Android Studio
2. Go to **Settings/Preferences → Plugins**
3. Search and install:
   - **Flutter** plugin
   - **Dart** plugin (usually auto-installed with Flutter)
4. Restart Android Studio

### 1.3 Create an Android Emulator
1. Open Android Studio
2. Go to **Tools → Device Manager** (or click the device icon in toolbar)
3. Click **Create Device**
4. Select a phone (e.g., **Pixel 7**)
5. Click **Next**
6. Select a system image:
   - Recommended: **API 34** (Android 14) with **Google Play**
   - Click **Download** if not already installed
7. Click **Next → Finish**
8. Click the **Play ▶** button to start the emulator

---

## Part 2: Project Setup

### 2.1 Clone and Install
```bash
cd ~
git clone <repository-url> cyclingapp
cd cyclingapp
flutter pub get
```

### 2.2 Verify Flutter Setup
```bash
flutter doctor
```
Ensure no critical errors for Android development.

---

## Part 3: Firebase Configuration (Required)

### 3.1 Android Firebase Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select/create your project
3. Click **Add app → Android**
4. Enter package name: `com.example.cruizr` (check `android/app/build.gradle`)
5. Download `google-services.json`
6. Place it in: `android/app/google-services.json`

### 3.2 Add SHA-1 Fingerprint (for Google Sign-In)
```bash
cd android
./gradlew signingReport
```
Copy the **SHA1** fingerprint from the output, then:
1. Go to Firebase Console → Project Settings → Your Android App
2. Click **Add fingerprint** and paste the SHA-1

### 3.3 Enable Firebase Services
In Firebase Console:
1. **Authentication** → Sign-in method → Enable **Email/Password** and **Google**
2. **Firestore Database** → Create database → Start in **Test mode**
3. **Storage** → Get started → Start in **Test mode**

---

## Part 4: Google Maps API Setup

### 4.1 Enable APIs
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (same as Firebase)
3. Go to **APIs & Services → Library**
4. Enable these APIs:
   - **Maps SDK for Android**
   - **Directions API** (for route generation)

### 4.2 Get API Key
1. Go to **APIs & Services → Credentials**
2. Click **Create Credentials → API Key**
3. Copy your API key
4. (Optional) Restrict the key to your Android app

### 4.3 Configure Android
Your API key should already be in `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY"/>
```

---

## Part 5: Running the App

### 5.1 Start the Emulator
1. Open Android Studio
2. Go to **Tools → Device Manager**
3. Click **Play ▶** on your emulator

### 5.2 Run from Terminal
```bash
cd ~/cyclingapp
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_API_KEY_HERE
```

### 5.3 Run from Android Studio
1. Open the project in Android Studio: **File → Open → select cyclingapp folder**
2. Select your emulator from the device dropdown (top toolbar)
3. Click the **Run ▶** button (green play icon)

> **Note**: To pass the API key in Android Studio:
> 1. Go to **Run → Edit Configurations**
> 2. Add to **Additional run args**: `--dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY`

---

## Part 6: Testing the Features

### Route Generation
1. Sign in to the app
2. Tap the **+** button (Start Activity)
3. Select **Create Route**
4. Tap on the map to add 2+ waypoints
5. The route should follow actual roads (not straight lines!)

### Profile Editing
1. Tap **Profile** in bottom navigation
2. Edit any field (name, activities, privacy settings)
3. Tap **Save** at top right

### Smooth Toggles
1. Go to **Start Activity** screen
2. Toggle **Live Tracking** - observe smooth animation

---

## Troubleshooting

### Emulator Won't Start
```bash
# Check if virtualization is enabled
egrep -c '(vmx|svm)' /proc/cpuinfo
# Should return a number > 0
```
Enable **Intel VT-x** or **AMD-V** in BIOS if needed.

### Gradle Build Errors
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### Google Sign-In Fails
- Ensure SHA-1 fingerprint is added to Firebase Console
- Ensure Google Sign-In is enabled in Firebase Authentication

### Maps Not Loading
- Verify API key is correct in AndroidManifest.xml
- Ensure Maps SDK for Android is enabled in Google Cloud Console
- Check API key restrictions

### Routes Show Straight Lines
- Ensure **Directions API** is enabled in Google Cloud Console
- Check that API key billing is set up (Directions API requires billing)
