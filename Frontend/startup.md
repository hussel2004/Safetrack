# SafeTrack - Android Startup Guide

This guide will walk you through setting up and running the SafeTrack GPS tracking Flutter application on Android using Android Studio.

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation Steps](#installation)
3. [Android Studio Setup](#android-studio-setup)
4. [Running the Application](#running-the-application)
5. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before you begin, ensure you have the following installed on your system:

### Required Software

| Software | Minimum Version | Download Link |
|----------|----------------|---------------|
| **Flutter SDK** | 3.0.0+ | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| **Android Studio** | Latest | [developer.android.com](https://developer.android.com/studio) |
| **JDK** | 17 | [Oracle](https://www.oracle.com/java/technologies/downloads/) or [OpenJDK](https://openjdk.org/) |
| **Git** | Latest | [git-scm.com](https://git-scm.com/downloads) |

### Android SDK Components

Ensure these Android SDK components are installed via Android Studio SDK Manager:

- Android SDK Platform (API 34)
- Android SDK Build-Tools (latest)
- Android SDK Command-line Tools
- Android Emulator (if you don't have a physical device)

### System Requirements

- **Operating System**: Windows 10/11, macOS 10.14+, or Linux
- **RAM**: 8 GB minimum (16 GB recommended)
- **Disk Space**: 10 GB free space
- **Android Device** (optional): Physical device with Android 5.0 (API 21) or higher

---

## Installation

### 1. Verify Flutter Installation

Open a terminal/command prompt and run:

```powershell
flutter doctor
```

This command checks your environment and displays a report. You should see:
- ✅ Flutter (Channel stable, 3.0.0+)
- ✅ Android toolchain
- ✅ Android Studio

> [!IMPORTANT]
> If any checks fail, follow the instructions provided by `flutter doctor` to resolve issues before proceeding.

### 2. Navigate to Project Directory

```powershell
cd c:\Users\j-store\Desktop\SafeTrackF\Frontend
```

### 3. Get Flutter Dependencies

Install all required Flutter packages:

```powershell
flutter pub get
```

This command reads the [pubspec.yaml](file:///c:/Users/j-store/Desktop/SafeTrackF/Frontend/pubspec.yaml) file and downloads all dependencies including:
- `provider` (State management)
- `google_fonts` (Custom fonts)
- `flutter_animate` (Animations)
- `flutter_map` (Map visualization)
- `latlong2` (GPS coordinates)

### 4. Verify Android Configuration

Check that the Android SDK path is correctly set:

```powershell
type android\local.properties
```

You should see:
```properties
sdk.dir=C:\\Users\\j-store\\AppData\\Local\\Android\\Sdk
flutter.sdk=C:\\flutter
```

---

## Android Studio Setup

### 1. Open Project in Android Studio

1. Launch **Android Studio**
2. Click **Open** or **File → Open**
3. Navigate to `c:\Users\j-store\Desktop\SafeTrackF\Frontend`
4. Click **OK**

> [!TIP]
> Android Studio will automatically detect this as a Flutter project and configure the necessary plugins.

### 2. Install Flutter and Dart Plugins

If not already installed:

1. Go to **File → Settings → Plugins** (Windows/Linux) or **Android Studio → Preferences → Plugins** (macOS)
2. Search for "**Flutter**"
3. Click **Install**
4. The Dart plugin will be installed automatically
5. Restart Android Studio

### 3. Configure Device/Emulator

#### Option A: Physical Android Device

1. Enable **Developer Options** on your Android device:
   - Go to **Settings → About Phone**
   - Tap **Build Number** 7 times
   - Go back to **Settings → Developer Options**
   - Enable **USB Debugging**

2. Connect your device via USB
3. Accept the "Allow USB Debugging" prompt on your device
4. In Android Studio, your device should appear in the device dropdown

#### Option B: Android Emulator

1. Open **AVD Manager**: **Tools → Device Manager**
2. Click **Create Device**
3. Select a device definition (e.g., **Pixel 5**)
4. Select a system image (API 34 recommended)
5. Click **Finish**
6. Start the emulator by clicking the ▶ (Play) button

---

## Running the Application

### Method 1: Using Android Studio

1. **Select Device**: In the device dropdown at the top, select your connected device or emulator
2. **Run the App**: Click the green ▶ (Run) button or press `Shift + F10`
3. Android Studio will:
   - Build the app
   - Install it on your device/emulator
   - Launch the app automatically

### Method 2: Using Terminal/Command Line

#### Run in Debug Mode

```powershell
flutter run
```

If multiple devices are connected, you'll be prompted to select one. Alternatively, specify the device:

```powershell
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

#### Run in Release Mode

```powershell
flutter run --release
```

> [!NOTE]
> Release mode provides better performance but removes debugging features like hot reload.

### Method 3: Build APK

To create an installable APK:

```powershell
# Debug APK
flutter build apk --debug

# Release APK (smaller, optimized)
flutter build apk --release
```

The APK will be located at:
```
Frontend\build\app\outputs\flutter-apk\app-release.apk
```

You can manually install this on any Android device.

---

## App Features & Permissions

When you first launch SafeTrack, the app will request the following permissions:

| Permission | Purpose | Required |
|------------|---------|----------|
| **Location (Fine)** | Precise GPS tracking | ✅ Yes |
| **Location (Coarse)** | Approximate location fallback | ✅ Yes |
| **Internet** | Communication with backend | ✅ Yes |

> [!IMPORTANT]
> You must grant location permissions for the GPS tracking features to work properly.

---

## Troubleshooting

### Issue: `flutter doctor` Shows Android Toolchain Issues

**Solution:**
1. Open Android Studio
2. Go to **Tools → SDK Manager**
3. Ensure the following are installed:
   - Android SDK Platform (API 34)
   - Android SDK Build-Tools
   - Android SDK Command-line Tools
4. Accept licenses: `flutter doctor --android-licenses`

---

### Issue: "Developer Mode Required" Error (Windows)

**Error Message:**
```
Error: Building with plugins requires symlink support.
Please enable Developer Mode in your system settings.
```

**Solution:**
1. Open **Settings → Update & Security → For Developers**
2. Enable **Developer Mode**
3. Restart your computer
4. Run `flutter clean` then try again

---

### Issue: Device Not Detected

**Solution:**

**For Physical Devices:**
1. Ensure USB debugging is enabled
2. Try a different USB cable or port
3. Install device drivers (manufacturer-specific)
4. Run `adb devices` to check connection

**For Emulators:**
1. Ensure Intel HAXM or AMD virtualization is enabled in BIOS
2. Restart the emulator
3. Try creating a new AVD with a different API level

---

### Issue: Build Fails with Gradle Errors

**Solution:**
1. Clean the project:
   ```powershell
   flutter clean
   ```

2. Remove build artifacts:
   ```powershell
   cd android
   ./gradlew clean
   cd ..
   ```

3. Get dependencies again:
   ```powershell
   flutter pub get
   ```

4. Rebuild:
   ```powershell
   flutter run
   ```

---

### Issue: "Insufficient Storage" on Emulator

**Solution:**
1. Open **AVD Manager**
2. Edit the emulator
3. Click **Show Advanced Settings**
4. Increase **Internal Storage** (e.g., 4096 MB)
5. Wipe data and restart

---

### Issue: Hot Reload Not Working

**Solution:**
1. Ensure you're running in debug mode (not release)
2. Save the file after making changes
3. Press `r` in the terminal or click the lightning bolt ⚡ in Android Studio
4. If still not working, try hot restart with `R` or full restart

---

### Issue: App Crashes on Startup

**Checklist:**
1. Check Android Studio's **Logcat** for error details
2. Ensure all permissions are granted in device settings
3. Verify minimum Android version is 5.0 (API 21) or higher
4. Try uninstalling and reinstalling the app
5. Clear app data: **Settings → Apps → SafeTrack → Storage → Clear Data**

---

## Project Structure Reference

```
Frontend/
├── android/                   # Android-specific configuration
│   ├── app/
│   │   ├── build.gradle.kts  # Build configuration (minSdk: 21, targetSdk: 34)
│   │   └── src/
│   │       └── main/
│   │           ├── AndroidManifest.xml  # Permissions & app metadata
│   │           └── kotlin/.../MainActivity.kt
│   ├── build.gradle.kts      # Root Gradle configuration
│   └── gradle.properties     # Gradle JVM settings
├── lib/                       # Dart source code
│   ├── main.dart             # App entry point
│   ├── screens/              # UI screens
│   ├── services/             # Business logic (GPS, Auth, etc.)
│   ├── models/               # Data models
│   └── theme.dart            # App styling
└── pubspec.yaml              # Flutter dependencies
```

---

## Quick Reference Commands

```powershell
# Check Flutter environment
flutter doctor

# Get dependencies
flutter pub get

# Run app
flutter run

# List devices
flutter devices

# Clean build cache
flutter clean

# Build release APK
flutter build apk --release

# Run tests
flutter test

# Check for updates
flutter upgrade
```

---

## Additional Resources

- **Flutter Documentation**: [docs.flutter.dev](https://docs.flutter.dev/)
- **Android Developer Guide**: [developer.android.com](https://developer.android.com/)
- **Flutter Android Setup**: [flutter.dev/docs/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows)
- **Troubleshooting**: [flutter.dev/docs/testing/debugging](https://docs.flutter.dev/testing/debugging)

---

## Need Help?

If you encounter issues not covered in this guide:

1. Check the Flutter logs: Run with `flutter run -v` for verbose output
2. Review Android Studio's Logcat for detailed crash reports
3. Consult the [Flutter GitHub Issues](https://github.com/flutter/flutter/issues)
4. Stack Overflow: [stackoverflow.com/questions/tagged/flutter](https://stackoverflow.com/questions/tagged/flutter)

---

**Last Updated**: February 10, 2026  
**App Version**: 1.0.0  
**Flutter Version**: 3.38.9  
**Minimum Android Version**: 5.0 (API 21)  
**Target Android Version**: 14 (API 34)
