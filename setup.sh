#!/usr/bin/env bash
# یک‌بار اجرا کن: پوشه‌های android و ios را می‌سازد و تنظیمات لازم را اعمال می‌کند
set -e

flutter create . --org com.engix --project-name engix --platforms android,ios
rm -f test/widget_test.dart

# همان applicationId اپ قبلی (برای آپدیت روی همان لیست گوگل‌پلی)
for f in android/app/build.gradle android/app/build.gradle.kts; do
  [ -f "$f" ] && sed -i -E 's/(applicationId\s*=?\s*)"com\.engix\.engix"/\1"com.engix.app"/' "$f"
done

# اجازه‌ی اینترنت برای نسخه‌ی release
M=android/app/src/main/AndroidManifest.xml
grep -q 'android.permission.INTERNET' "$M" || \
  sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET" />\n    <application#' "$M"

# نام اپ روی گوشی
sed -i 's#android:label="[^"]*"#android:label="EngiX"#' "$M"

flutter pub get
echo "آماده شد. برای اجرا: flutter run    |    برای ساخت APK: flutter build apk --release"
