# Project Setup Guide

Welcome to the Cruizr project! Follow these steps to get the app running on your local machine.

## Prerequisites

Before you begin, ensure you have the following installed:

1.  **Git**: [Download Git](https://git-scm.com/downloads)
2.  **Flutter SDK**: [Install Flutter](https://docs.flutter.dev/get-started/install)
    *   Ensure `flutter doctor` runs without major issues.
3.  **Visual Studio Code** (Recommended) or Android Studio.
    *   Install the **Flutter** and **Dart** extensions.

## Installation

1.  **Clone the repository**:
    ```bash
    git clone <repository-url>
    cd cyclingapp
    ```

2.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```

## Firebase Configuration (Critical)

This project uses Firebase for authentication. Since configuration files containing API keys are often git-ignored for security or might be missing from the repo, you need to ensure they are present.

### Android
Check if `android/app/google-services.json` exists.
*   **If missing**: You need to obtain the `google-services.json` file from the Firebase Console for the Android app and place it in `android/app/`.

### iOS
Check if `ios/Runner/GoogleService-Info.plist` exists.
*   **If missing** (Likely):
    1.  Go to the Firebase Console.
    2.  Download `GoogleService-Info.plist` for the iOS app.
    3.  Open the project in Xcode (`open ios/Runner.xcworkspace`).
    4.  Drag and drop data `GoogleService-Info.plist` into the `Runner` folder within Xcode. Ensure "Copy items if needed" is checked.

### Web (Optional)
If running on web, ensure `lib/firebase_options.dart` is present and configured. If not, you may need to run `flutterfire configure`.

### Enable Features
1.  **Authentication**: Go to the Firebase Console -> Build -> Authentication -> Sign-in method.
    *   Enable **Email/Password**.
    *   Enable **Google** (if using Google Sign-In).
2.  **Firestore Database**: Go to Build -> Firestore Database -> Create Database.
    *   Start in **Test Mode** (for development) or set appropriate security rules.
3.  **Storage**: Go to Build -> Storage -> Get Started.
    *   Start in **Test Mode** (for development) to allow image uploads.

## Running the App

1.  **Launch an Emulator/Simulator** or connect a physical device.
2.  **Run the app**:
    ```bash
    flutter run
    ```

## Common Issues

*   **CocoaPods (iOS)**: If you encounter issues on iOS, try running:
    ```bash
    cd ios
    rm -rf Pods
    rm Podfile.lock
    pod install
    cd ..
    ```
*   **Firebase Auth Errors**: Ensure your SHA-1 fingerprint is added to the Firebase Console for Android Google Sign-In to work.
