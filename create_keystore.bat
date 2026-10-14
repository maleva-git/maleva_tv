@echo off
cd /d "d:\Code\malevatvapp\maleva_tv\android\app"
set /p KEYSTORE_PASSWORD=Keystore password: 
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload -storepass %KEYSTORE_PASSWORD% -keypass %KEYSTORE_PASSWORD% -dname "CN=Maleva TV, OU=IT, O=Maleva, L=KL, ST=Selangor, C=MY"
pause