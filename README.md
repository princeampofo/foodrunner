# 🍔 FoodRunner

A comprehensive food delivery application built with Flutter and Firebase, featuring real-time order tracking, driver assignment, and multi-role user management.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Firebase Setup](#firebase-setup)
- [Running the App](#running-the-app)
- [Known Issues & Limitations](#known-issues--limitations)
- [Future Improvements](#future-improvements)

## 🎯 Overview

FoodRunner is a multi-platform food delivery application that connects customers, restaurants, and delivery drivers in real-time. The app provides a complete end-to-end delivery experience with live tracking, automated driver assignment, and comprehensive order management.

## ✨ Features

### For Customers
- Browse restaurants and menus
- Add items to cart with customization options
- Real-time order tracking with live driver location
- Order history and reordering
- Rate and review orders
- Multiple delivery address management

### For Restaurants
- Manage menu items (add, edit, delete)
- Real-time order notifications
- Order status management (accept, prepare, ready)
- Sales analytics and earnings tracking
- Order history with filtering

### For Drivers
- Online/Offline status toggle
- Automated order assignment based on proximity
- Turn-by-turn navigation to restaurant and customer
- Live location tracking during deliveries
- Earnings tracking (daily and total)
- Delivery history and performance metrics

## 🛠 Tech Stack

- **Framework:** Flutter 3.9.2
- **Backend:** Firebase
  - Authentication (Email/Password)
  - Cloud Firestore (Database)
  - Firebase Messaging (Push notifications - configured but not implemented)
- **State Management:** Provider
- **Maps & Location:**
  - Google Maps Flutter
  - Geolocator
  - GeoFlutterFire Plus
  - Geocoding
  - Flutter Polyline Points
- **Additional Packages:**
  - cached_network_image
  - image_picker
  - intl
  - uuid
  - url_launcher

## 📦 Prerequisites

Before you begin, ensure you have the following installed:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.9.2 or higher)
- [Dart SDK](https://dart.dev/get-dart) (3.9.2 or higher)
- [Android Studio](https://developer.android.com/studio) (for Android development)
- [Xcode](https://developer.apple.com/xcode/) (for iOS development, macOS only)
- [Firebase CLI](https://firebase.google.com/docs/cli) (for Firebase setup)
- [Google Maps API Key](https://developers.google.com/maps/documentation/android-sdk/get-api-key)

## 📥 Installation

1. **Clone the repository and navigate to the project directory:**
   ```bash
   cd /foodrunner
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify Flutter installation:**
   ```bash
   flutter doctor
   ```
   Fix any issues reported by Flutter Doctor.

## 🔥 Firebase Setup

### 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" and follow the setup wizard
3. Enable Google Analytics (optional but recommended)

### 2. Configure Firebase for Flutter

**For Android:**
1. In Firebase Console, add an Android app
2. Register your app with package name: `com.example.foodrunner`
3. Download `google-services.json`
4. Place it in `android/app/`

**For iOS:**
1. In Firebase Console, add an iOS app
2. Register your app with bundle ID: `com.example.foodrunner`
3. Download `GoogleService-Info.plist`
4. Place it in `ios/Runner/`

**For Web:**
1. In Firebase Console, add a Web app
2. Copy the Firebase configuration
3. Update `web/index.html` with your config

### 3. Enable Firebase Services

In Firebase Console, enable the following:

- **Authentication:**
  - Email/Password sign-in method

- **Firestore Database:**
  - Create a database in development mode

### 4. Configure FlutterFire

1. Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. Configure Firebase for your Flutter project:
   ```bash
   flutterfire configure
   ```
   Select your Firebase project and platforms.

### 5. Google Maps API Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Enable the following APIs:
   - Maps SDK for Android
   - Maps SDK for iOS
   - Directions API
   - Geocoding API
   - Places API

3. Create API credentials and restrict them appropriately

4. **For Android:**
   Add your API key to `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_ANDROID_API_KEY"/>
   ```

5. **For iOS:**
   Add your API key to `ios/Runner/AppDelegate.swift`:
   ```swift
   GMSServices.provideAPIKey("YOUR_IOS_API_KEY")
   ```

## 🚀 Running the App

### Run on Android Emulator

1. Start an Android emulator from Android Studio or via command:
   ```bash
   flutter emulators --launch <emulator_id>
   ```

2. Run the app:
   ```bash
   flutter run
   ```

### Run on iOS Simulator (macOS only)

1. Start iOS simulator:
   ```bash
   open -a Simulator
   ```

2. Run the app:
   ```bash
   flutter run
   ```

### Run on Physical Device

1. Enable USB debugging (Android) or Developer mode (iOS)
2. Connect your device
3. Run:
   ```bash
   flutter run
   ```

### Build Release Version

**Android APK:**
```bash
flutter build apk --release
```
**iOS:**
```bash
flutter build ios --release
```

## ⚠️ Known Issues & Limitations

### Critical Issues

#### 1. **Driver Assignment**
**Problem:** Driver assignment happens on the client side, making it vulnerable to app refreshes since Future.delay() is used in broadcasting order requests. A better approach would be to implement this server-side using Cloud Functions to ensure reliability and consistency.

#### 2. **Simulation service**
**Problem:** The driver simulation service is also client-side, meaning if the app is closed or refreshed, the simulation stops. A better approach would be to implement this server-side using Cloud Functions.

#### 3. **No Push Notifications Implementation**
**Problem:** While Firebase Messaging is configured in dependencies, push notifications are not implemented yet.

## 🔮 Future Improvements

1. **Implement Cloud Functions for driver assignment** (fixes race condition)
2. **Add push notifications** for real-time updates
3. **Improve background location tracking** for drivers
4. **Implement proper error handling** and retry logic

## 📄 License

This project is created for educational purposes as part of the Mobile Application Development course.

## 👨‍💻 Author

Prince Ampofo
- GitHub: [@princeampofo](https://github.com/princeampofo)
