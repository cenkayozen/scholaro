# Scholaro – Setup Guide

## Overview
Scholaro is a Flutter app (Android + Windows) with Firebase backend.
It requires Flutter SDK and a Firebase project to run.

---

## Step 1 – Install Flutter

1. Download Flutter SDK from: https://docs.flutter.dev/get-started/install/windows
2. Extract to `C:\flutter`
3. Add `C:\flutter\bin` to your system PATH
4. Open a new terminal and run:
   ```
   flutter doctor
   ```
   Fix any issues it reports (especially Android Studio and Android SDK).

---

## Step 2 – Install Android Studio (for Android build)

1. Download from: https://developer.android.com/studio
2. Install Android Studio
3. Open Android Studio → SDK Manager → Install Android SDK (API 34 recommended)
4. Create a virtual device (AVD) for testing, OR connect a physical Android phone with USB debugging enabled

---

## Step 3 – Create a Firebase Project

1. Go to: https://console.firebase.google.com
2. Click **Add project** → Name it `scholaro` (or anything you like)
3. Disable Google Analytics (optional) → **Create project**

### 3a – Enable Authentication
1. In Firebase Console → **Authentication** → **Get started**
2. Under **Sign-in method**, enable:
   - **Email/Password** ✓

### 3b – Enable Firestore Database
1. Go to **Firestore Database** → **Create database**
2. Choose **Production mode** → Select a region close to you → **Done**
3. Go to **Rules** tab and paste the contents of `firestore.rules` from this project

### 3c – Enable Firebase Storage
1. Go to **Storage** → **Get started**
2. Choose **Production mode** → same region → **Done**
3. Under **Rules**, paste:
   ```
   rules_version = '2';
   service firebase.storage {
     match /b/{bucket}/o {
       match /teachers/{teacherId}/{allPaths=**} {
         allow read, write: if request.auth != null && request.auth.uid == teacherId;
       }
       // Students can read their class storage (for portfolio viewing)
       allow read: if request.auth != null;
     }
   }
   ```

---

## Step 4 – Connect Flutter to Firebase (FlutterFire CLI)

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# In the grading_app folder, run:
flutterfire configure --project=YOUR_PROJECT_ID
```

This will:
- Generate `lib/firebase_options.dart` with your real Firebase config
- Configure `android/google-services.json` automatically

> **Note:** Replace the placeholder `lib/firebase_options.dart` with the generated one.

---

## Step 5 – Set Your Firebase Web API Key

Open `lib/utils/app_config.dart` and replace the placeholder:

```dart
static const String firebaseWebApiKey = 'YOUR_FIREBASE_WEB_API_KEY';
```

Find your Web API Key in:
**Firebase Console → Project Settings → General → Web API Key**

This key is used to create student Firebase Auth accounts from the teacher app.

---

## Step 6 – Run the App

### On Android:
```bash
# Make sure a device is connected or emulator is running
flutter run
```

### On Windows:
```bash
flutter run -d windows
```

### Build APK for distribution:
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Build Windows installer:
```bash
flutter build windows --release
# Output: build/windows/x64/runner/Release/
```

---

## How to Use Scholaro

### Teacher Workflow:
1. Open app → Select **Teacher**
2. Register with your email and password
3. Create a new class (e.g. "10-B English")
4. Add students:
   - **Import from PDF**: Upload a PDF with a table containing school numbers and names
   - **Add manually**: Enter name and school number
5. Share each student's username and password (visible in Students list → key icon)
6. Use the **drawer menu** (hamburger ☰) to navigate between:
   - **Homework**: Add assignments, tap cells to cycle grades (+, ½+, −, Absent G, Exempt M)
   - **Participation**: Tap + to give participation credit with date tracking
   - **Quizzes**: Add quiz names, tap scores to enter grades (0–100)
   - **Portfolio**: Upload photos or files per student
   - **Random Picker**: Randomly selects a student and reads their name aloud
   - **Export PDF**: Generate PDF reports for any scale

### Student Workflow:
1. Open app → Select **Student**
2. Enter the username and password given by your teacher
3. View your:
   - Homework grades and completion percentage
   - Participation count and score
   - Quiz scores and average
   - Portfolio files

---

## Grade Mark Legend (Homework)

| Symbol | Meaning        | Counts toward % |
|--------|----------------|-----------------|
| +      | Done           | 1.0             |
| ½+     | Half done      | 0.5             |
| −      | Not done       | 0.0             |
| G      | Absent         | Excluded        |
| M      | Exempt         | Excluded        |

**Completion % = earned points / (total assignments - G - M) × 100**

---

## PDF Import Format

The PDF import works best with tables structured like:
```
1  12345  Ali Veli
2  12346  Fatma Demir
```
Or:
```
12345  Ali Veli
12346  Fatma Demir
```

Photos in PDFs cannot be automatically extracted. Use the camera icon in the student list to add photos manually.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `flutter: command not found` | Add `C:\flutter\bin` to PATH and restart terminal |
| Firebase not initialized | Make sure `flutterfire configure` was run and `firebase_options.dart` is updated |
| Student can't log in | Check that `AppConfig.firebaseWebApiKey` is set correctly |
| PDF import finds no students | The PDF table format may differ; try copying the PDF text to see its structure |
| TTS not working on Windows | Windows SAPI must be installed (comes with Windows by default) |

---

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase config (generated)
├── router/app_router.dart       # All navigation routes
├── models/                      # Data classes
├── services/                    # Firebase, PDF, Storage logic
├── providers/providers.dart     # Riverpod state management
├── utils/                       # Calculators, generators
├── screens/
│   ├── role_selection_screen.dart
│   ├── teacher/                 # All teacher screens
│   └── student/                 # All student screens
└── widgets/                     # Reusable UI components
```
