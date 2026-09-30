import { NextResponse } from "next/server";
import { getSupabaseAdmin } from "../../../../lib/supabaseAdmin";
import { getFirebaseAdmin } from "../../../../lib/firebaseAdmin";
import admin from "firebase-admin";

// نسخه‌ی عمومیِ send-message-push: برای هر نوع نوتیفیکیشن (اطلاعیه، دعوت به
// پروژه، گزارش جدید، دستور کار و ...) نه فقط پیام‌رسان. هر جایی در کد که
// notifyUser() صدا زده می‌شود، این route هم صدا زده می‌شود تا واقعاً به
// گوشیِ گیرنده push برسد (نه فقط یک ردیف در جدول notifications).
export async function POST(req) {
  try {
    const body = await req.json();
    const { userIds, title, body: messageBody, data } = body;
    const targetIds = Array.isArray(userIds) ? userIds : userIds ? [userIds] : [];

    if (targetIds.length === 0 || !title) {
      return NextResponse.json({ error: "اطلاعات ناقص است." }, { status: 400 });
    }

    // احراز هویت: فقط کاربرِ واقعاً لاگین‌کرده اجازه دارد از این endpoint استفاده کند
    const authHeader = req.headers.get("authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    if (!token) {
      return NextResponse.json({ error: "احراز هویت لازم است." }, { status: 401 });
    }

    const supabaseAdmin = getSupabaseAdmin();
    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);
    if (userError || !userData?.user) {
      return NextResponse.json({ error: "نشست نامعتبر است." }, { status: 401 });
    }

    const { data: profiles, error: profErr } = await supabaseAdmin
      .from("profiles")
      .select("fcm_token")
      .in("id", targetIds);
    if (profErr) throw new Error(profErr.message);

    const tokens = (profiles || []).map((p) => p.fcm_token).filter(Boolean);
    if (tokens.length === 0) {
      return NextResponse.json({ sent: 0 });
    }

    getFirebaseAdmin();

    const message = {
      notification: {
        title: String(title).slice(0, 120),
        body: String(messageBody || "").slice(0, 200),
      },
      data: data ? Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])) : {},
      // صریحاً صدا و کانال پیش‌فرض را مشخص می‌کنیم تا روی اندروید همیشه صدا/لرزش
      // و نمایش روی نوار اعلان‌ها اتفاق بیفتد، حتی اگر برنامه در پس‌زمینه/بسته باشد
      android: {
        priority: "high",
        notification: { sound: "default", channelId: "engix_default", defaultVibrateTimings: true },
      },
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
      },
      tokens,
    };

    const result = await admin.messaging().sendEachForMulticast(message);

    const invalidTokens = [];
    result.responses.forEach((r, i) => {
      if (!r.success && ["messaging/invalid-registration-token", "messaging/registration-token-not-registered"].includes(r.error?.code)) {
        invalidTokens.push(tokens[i]);
      }
    });
    if (invalidTokens.length > 0) {
      await supabaseAdmin.from("profiles").update({ fcm_token: null }).in("fcm_token", invalidTokens);
    }

    return NextResponse.json({ sent: result.successCount, failed: result.failureCount });
  } catch (e) {
    console.error("send-push error:", e.message);
    return NextResponse.json({ error: e.message }, { status: 200 });
  }
}
