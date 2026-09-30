import admin from "firebase-admin";

// ⚠️ فقط سمت سرور استفاده شود (Route Handlers). این فایل با کلید سرویس‌اکانت
// فایربیس کار می‌کند که دسترسی کامل به ارسال نوتیفیکیشن دارد.

let app = null;

export function getFirebaseAdmin() {
  if (app) return app;

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  // کلید خصوصی معمولاً با \n literal داخل env variable ذخیره می‌شود، باید تبدیلش کنیم
  const privateKey = (process.env.FIREBASE_PRIVATE_KEY || "").replace(/\\n/g, "\n");

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error(
      "متغیرهای FIREBASE_PROJECT_ID، FIREBASE_CLIENT_EMAIL، FIREBASE_PRIVATE_KEY روی سرور تنظیم نشده‌اند."
    );
  }

  app = admin.apps.length
    ? admin.app()
    : admin.initializeApp({
        credential: admin.credential.cert({ projectId, clientEmail, privateKey }),
      });

  return app;
}
