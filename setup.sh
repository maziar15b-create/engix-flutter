#!/usr/bin/env bash
# یک‌بار اجرا کن: پوشه‌های android و ios را می‌سازد و تنظیمات لازم را اعمال میکند
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

# رفع خطای compileSdk پلاگین‌ها (file_picker و ...): همه را روی ۳۶ می‌بریم
if [ -f android/build.gradle.kts ]; then
  cat > /tmp/sdkfix.kts <<'EOF'
subprojects {
    afterEvaluate {
        (extensions.findByName("android") as? com.android.build.gradle.BaseExtension)?.compileSdkVersion(36)
    }
}

EOF
  cat /tmp/sdkfix.kts android/build.gradle.kts > /tmp/build_new.kts
  mv /tmp/build_new.kts android/build.gradle.kts
elif [ -f android/build.gradle ]; then
  cat > /tmp/sdkfix.gradle <<'EOF'
subprojects {
    afterEvaluate { p ->
        if (p.hasProperty('android')) {
            p.android.compileSdkVersion 36
        }
    }
}

EOF
  cat /tmp/sdkfix.gradle android/build.gradle > /tmp/build_new.gradle
  mv /tmp/build_new.gradle android/build.gradle
fi

flutter pub get
echo "آماده شد. برای اجرا: flutter run    |    برای ساخت APK: flutter build apk --release"
