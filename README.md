# Real-Time Emergency Reporting and Alert App

Flutter + Firebase mobile app for emergency incident reporting with SOS, media uploads, contact-only push notifications, location capture, and offline queue sync.

## Features Implemented

- Email/password authentication with Firebase Auth
- User profile storage in Firestore (`users` collection)
- FCM token capture and update on register/login/token refresh
- Home screen with large SOS bell (double-tap to trigger)
- Incident reporting with:
  - Photo capture/upload
  - Audio recording
  - Description text
  - Severity selection (RED/ORANGE/YELLOW/GREEN)
  - GPS coordinates
- Firestore report storage (`reports` collection)
- Firebase Storage upload for images/audio
- Firebase Cloud Function that sends SOS notifications only to registered emergency contacts
- Offline queue:
  - If internet is unavailable, reports are queued locally
  - Auto-sync runs in background and uploads when internet returns
- My Reports screen with:
  - Severity color badge
  - Date/time
  - Status
  - Embedded map preview (Google Maps)

## Firestore Data Shape

### `users`

```text
users/{uid}
  id
  name
  email
  mobile
  fcmToken
  emergencyContacts
  createdAt
```

### `reports`

```text
reports/{reportId}
  id
  userId
  description
  imageUrl
  audioUrl
  latitude
  longitude
  severity
  status
  createdAt
  type
```

## Project Structure

```text
lib
 ├── firebase
 │   ├── fcm_background_handler.dart
 │   └── firebase_constants.dart
 ├── models
 │   ├── app_user.dart
 │   ├── emergency_report.dart
 │   ├── queued_action.dart
 │   └── submission_result.dart
 ├── screens
 │   ├── auth_gate.dart
 │   ├── home_screen.dart
 │   ├── login_screen.dart
 │   ├── my_reports_screen.dart
 │   ├── register_screen.dart
 │   └── report_incident_screen.dart
 ├── services
 │   ├── auth_provider.dart
 │   ├── auth_service.dart
 │   ├── location_service.dart
 │   ├── notification_service.dart
 │   ├── offline_queue_service.dart
 │   ├── report_service.dart
 │   └── storage_service.dart
 ├── widgets
 │   ├── report_card.dart
 │   └── severity_badge.dart
 ├── firebase_options.dart
 └── main.dart
```

## Required Packages

This project uses:

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `firebase_messaging`
- `firebase_storage`
- `image_picker`
- `geolocator`
- `permission_handler`
- `record`
- `provider`
- `google_maps_flutter`

Additional utility packages:

- `path_provider`
- `shared_preferences`

## Firebase Setup (Android + iOS)

1. Create Firebase project
- Open Firebase Console and create a project.
- Enable:
  - Authentication (Email/Password)
  - Cloud Firestore
  - Cloud Messaging
  - Storage

2. Add Android app
- Use package id from this app: `com.example.disaster_reporting_app`
- Download `google-services.json`
- Place it in: `android/app/google-services.json`

3. Add iOS app
- Use iOS bundle id from Xcode project.
- Download `GoogleService-Info.plist`
- Add it to `ios/Runner/` via Xcode.

4. Generate FlutterFire config

```bash
flutterfire configure
```

This updates `lib/firebase_options.dart`.

5. Cloud Messaging setup
- Android:
  - Ensure `com.google.gms.google-services` plugin is applied (already configured).
- iOS:
  - In Xcode, enable Push Notifications and Background Modes > Remote notifications.
  - Upload APNs key/certificate in Firebase Console.

6. Google Maps setup
- Create a Google Maps API key.
- Put key in:
  - `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY`)
  - iOS AppDelegate as needed for Google Maps SDK configuration.

## SOS Notification Flow

1. Flutter writes a new `reports/{reportId}` document with `type: SOS`.
2. A Firestore-triggered Cloud Function loads the reporting user.
3. The function reads `users/{userId}.emergencyContacts`.
4. It finds matching users by `mobile`, collects their `fcmToken` values, and sends a multicast push through Firebase Admin SDK.
5. The Flutter app only receives and handles notifications. It does not call FCM HTTP endpoints or store a server key.

Deploy the backend after installing the Functions dependencies:

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

## Run the App

```bash
flutter pub get
flutter run
```

## Offline Queue Behavior

If internet is unavailable when creating SOS/incident:

`Internet unavailable. Report will be sent when connection returns.`

Queued items are stored locally and periodically retried.
