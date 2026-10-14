# Manual Keystore Creation

## Step 1: Open Command Prompt as Administrator

## Step 2: Run this command (copy and paste exactly):
```cmd
cd /d "C:\Program Files\Android\Android Studio\jbr\bin" && keytool.exe -genkey -v -keystore "d:\Code\malevatvapp\maleva_tv\android\app\upload-keystore.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias upload -storepass <your keystore password> -keypass <your keystore password> -dname "CN=Maleva TV, OU=IT, O=Maleva, L=KL, ST=Selangor, C=MY"
```

## Step 3: After keystore is created, build the app:
```cmd
cd /d "d:\Code\malevatvapp\maleva_tv"
flutter build appbundle --release
```

## Alternative: Use Android Studio
1. Open Android Studio
2. Go to Build > Generate Signed Bundle/APK
3. Create new keystore with these details:
   - Keystore path: d:\Code\malevatvapp\maleva_tv\android\app\upload-keystore.jks
   - Password: <your keystore password>
   - Alias: upload
   - Key password: <your keystore password>