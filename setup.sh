#!/usr/bin/env bash
# یک‌بار اجرا کن: پوشه‌های android و ios را می‌سازد و تنظیمات لازم را اعمال میکند
set -e

flutter create . --org com.engix --project-name engix --platforms android,ios
rm -f test/widget_test.dart

# همان applicationId اپ قبلی (برای آپدیت روی همان لیست گوگلپلی)
for f in android/app/build.gradle android/app/build.gradle.kts; do
  [ -f "$f" ] && sed -i -E 's/(applicationId\s*=?\s*)"com\.engix\.engix"/\1"com.engix.app"/' "$f"
done

# مجوزها: اینترنت، اعلان، لوکیشن، ضبط صدا، مخاطبین
M=android/app/src/main/AndroidManifest.xml
for p in INTERNET POST_NOTIFICATIONS ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION RECORD_AUDIO READ_CONTACTS; do
  grep -q "android.permission.$p" "$M" || \
    sed -i "s#<application#<uses-permission android:name=\"android.permission.$p\" />\n    <application#" "$M"
done

# نام اپ روی گوشی
sed -i 's#android:label="[^"]*"#android:label="EngiX"#' "$M"

# کانال پیش‌فرض نوتیفیکیشن (همان channelId که سرور در پوش می‌فرستد)
grep -q "default_notification_channel_id" "$M" || \
  perl -0pi -e 's#(<application[^>]*>)#$1\n        <meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="engix_default" />#' "$M"

# ───── Firebase (اعلان پوش) ─────
# فایل google-services.json را از پروژه‌ی وب بردار و کنار همین فایل (ریشه‌ی پروژه) بگذار
if [ -f google-services.json ]; then
  cp google-services.json android/app/google-services.json
else
  echo "هشدار: google-services.json در ریشه‌ی پروژه پیدا نشد؛ اعلان پوش کار نخواهد کرد."
fi

# پلاگین google-services در settings (Kotlin DSL یا Groovy)
for f in android/settings.gradle.kts android/settings.gradle; do
  if [ -f "$f" ] && ! grep -q 'com.google.gms.google-services' "$f"; then
    if [[ "$f" == *.kts ]]; then
      sed -i '/id("org.jetbrains.kotlin.android")/a\    id("com.google.gms.google-services") version "4.4.2" apply false' "$f"
    else
      sed -i '/id "org.jetbrains.kotlin.android"/a\    id "com.google.gms.google-services" version "4.4.2" apply false' "$f"
    fi
  fi
done

# پلاگین در ماژول app + حداقل SDK برابر ۲۴ (لازم برای Firebase)
for f in android/app/build.gradle.kts android/app/build.gradle; do
  if [ -f "$f" ] && ! grep -q 'com.google.gms.google-services' "$f"; then
    if [[ "$f" == *.kts ]]; then
      sed -i '/id("dev.flutter.flutter-gradle-plugin")/a\    id("com.google.gms.google-services")' "$f"
    else
      sed -i '/id "dev.flutter.flutter-gradle-plugin"/a\    id "com.google.gms.google-services"' "$f"
    fi
  fi
  [ -f "$f" ] && sed -i -E 's/minSdk(Version)?(\s*=\s*|\s+)flutter\.minSdkVersion/minSdk\2 24/' "$f"
done

flutter pub get

# آیکن و Splash از لوگوی assets/icon/icon.png و assets/images/logo.png
dart run flutter_launcher_icons
dart run flutter_native_splash:create

echo "آماده شد. برای اجرا: flutter run    |    برای ساخت APK: flutter build apk --release"
