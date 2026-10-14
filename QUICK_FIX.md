# Quick Fix for Play Store Upload

## Option 1: Use Debug Signing (Temporary)
Your app is now configured to use debug signing for release builds.

Run this command:
```cmd
flutter build appbundle --release
```

This will create a signed APK that Play Store will accept.

## Option 2: Create Keystore Manually
1. Open Command Prompt as Administrator
2. Find your Java installation:
   ```cmd
   dir "C:\Program Files\Java" /b
   ```
3. Use the Java version found (replace jdk-XX with your version):
   ```cmd
   "C:\Program Files\Java\jdk-XX\bin\keytool.exe" -genkey -v -keystore "d:\Code\malevatvapp\maleva_tv\android\app\upload-keystore.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

## Build Command
```cmd
cd /d "d:\Code\malevatvapp\maleva_tv"
flutter build appbundle --release
```

The .aab file will be at: `build\app\outputs\bundle\release\app-release.aab`