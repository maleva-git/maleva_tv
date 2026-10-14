# Release Build Instructions

## Step 1: Generate Keystore (Run this command in Command Prompt)

```cmd
cd /d "C:\Program Files\Android\Android Studio\jbr\bin"
keytool -genkey -v -keystore "d:\Code\malevatvapp\maleva_tv\android\app\upload-keystore.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

When prompted, enter:
- Password: <your keystore password>
- Re-enter password: <your keystore password>
- First and last name: Maleva TV
- Organizational unit: IT
- Organization: Maleva
- City: Your City
- State: Your State
- Country code: MY
- Is this correct? y
- Key password: <your keystore password>

## Step 2: Build Release APK

No key is needed: on first start the TV asks once for an employee user name and password
(like maleva_app) and stays signed in after that.

```cmd
cd /d "d:\Code\malevatvapp\maleva_tv"
flutter build apk --release
```

## Step 3: Build Release App Bundle (Recommended for Play Store)

```cmd
cd /d "d:\Code\malevatvapp\maleva_tv"
flutter build appbundle --release
```

The signed files will be located at:
- APK: `build\app\outputs\flutter-apk\app-release.apk`
- App Bundle: `build\app\outputs\bundle\release\app-release.aab`

Upload the .aab file to Play Store for better optimization.
## Desktop: Mac and Windows

The same board (sign-in once, Vessel Planning grid, search) runs as a desktop app. The keyboard works
like the TV remote: arrows, Page Up/Down, Enter (pause / auto), Escape (Back), typing searches.

### Mac (build on a Mac)

```bash
flutter build macos --release
```

The app is `build/macos/Build/Products/Release/Maleva Vessel Board.app`. To copy it to another Mac, zip it:

```bash
ditto -c -k --keepParent "build/macos/Build/Products/Release/Maleva Vessel Board.app" Maleva-Vessel-Board-macOS.zip
```

The app is not signed with an Apple developer account, so the first time on another Mac:
right-click the app → **Open** → **Open**. After that it opens normally.

### Windows (build on a Windows PC)

Flutter cannot build Windows apps on a Mac. On the Windows PC, once:

1. Install Flutter (same version as on the Mac) and add it to PATH.
2. Install **Visual Studio 2022** (Community is fine) with the workload **"Desktop development with C++"**.
3. Run `flutter doctor` - the "Visual Studio" line must show a tick.

Then, in the `maleva_tv` folder:

```cmd
flutter build windows --release
```

The app is the whole folder `build\windows\x64\runner\Release\` (`maleva_tv.exe` plus its `.dll` files and
the `data` folder). Copy or zip that **whole folder**; the `.exe` alone does not start. Windows may show
"Windows protected your PC" the first time: **More info** → **Run anyway**.
