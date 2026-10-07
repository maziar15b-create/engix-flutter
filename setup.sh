#!/usr/bin/env bash
# یک‌بار اجرا کن: پوشه‌های android و ios را می‌سازد و تنظیمات لازم را اعمال می‌کند
set -e

flutter create . --org com.engix --project-name engix --platforms android,ios
rm -f test/widget_test.dart

# همان applicationId اپ قبلی (برای آپدیت روی همان لیست گوگل‌پلی)
for f in android/app/build.gradle android/app/build.gradle.kts; do
  [ -f "$f" ] && sed -i -E 's/(applicationId\s*=?\s*)"com\.engix\.engix"/\1"com.engix.app"/' "$f"
done

# مجوزهای اینترنت و موقعیت مکانی (GPS پروژه)
M=android/app/src/main/AndroidManifest.xml
for perm in INTERNET ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION RECORD_AUDIO POST_NOTIFICATIONS; do
  grep -q "android.permission.$perm" "$M" || \
    sed -i "s#<application#<uses-permission android:name=\"android.permission.$perm\" />\n    <application#" "$M"
done

# کانال پیش‌فرض نوتیفیکیشن (همان channelId که سرور می‌فرستد)
grep -q "default_notification_channel_id" "$M" || \
  perl -0pi -e 's#(<application[^>]*>)#$1\n        <meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="engix_default" />#' "$M"

# فایربیس: کپی google-services.json و افزودن پلاگین
cp -f google-services.json android/app/google-services.json
if [ -f android/settings.gradle.kts ]; then
  grep -q "google-services" android/settings.gradle.kts || \
    sed -i 's#id("org.jetbrains.kotlin.android") version#id("com.google.gms.google-services") version "4.4.2" apply false\n    id("org.jetbrains.kotlin.android") version#' android/settings.gradle.kts
  grep -q "google-services" android/app/build.gradle.kts || \
    sed -i 's#id("dev.flutter.flutter-gradle-plugin")#id("dev.flutter.flutter-gradle-plugin")\n    id("com.google.gms.google-services")#' android/app/build.gradle.kts
  sed -i -E 's/minSdk\s*=\s*flutter\.minSdkVersion/minSdk = 23/' android/app/build.gradle.kts
fi

# نام اپ روی گوشی
sed -i 's#android:label="[^"]*"#android:label="EngiX"#' "$M"

# رفع خطای compileSdk پلاگین‌ها (file_picker و ...): همه را روی ۳۶ می‌بریم
if [ -f android/build.gradle.kts ]; then
  cat > /tmp/sdkfix.kts <<'EOT'
subprojects {
    afterEvaluate {
        (extensions.findByName("android") as? com.android.build.gradle.BaseExtension)?.compileSdkVersion(36)
    }
}

EOT
  cat /tmp/sdkfix.kts android/build.gradle.kts > /tmp/build_new.kts
  mv /tmp/build_new.kts android/build.gradle.kts
elif [ -f android/build.gradle ]; then
  cat > /tmp/sdkfix.gradle <<'EOT'
subprojects {
    afterEvaluate { p ->
        if (p.hasProperty('android')) {
            p.android.compileSdkVersion 36
        }
    }
}

EOT
  cat /tmp/sdkfix.gradle android/build.gradle > /tmp/build_new.gradle
  mv /tmp/build_new.gradle android/build.gradle
fi

flutter pub get
echo "آماده شد. برای اجرا: flutter run    |    برای ساخت APK: flutter build apk --release"
