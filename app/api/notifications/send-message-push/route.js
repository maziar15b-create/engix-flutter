import { NextResponse } from "next/server";
import { getSupabaseAdmin } from "../../../../lib/supabaseAdmin";
import { getFirebaseAdmin } from "../../../../lib/firebaseAdmin";
import admin from "firebase-admin";

export async function POST(req) {
  try {
    const { conversationId, senderId, text } = await req.json();
    if (!conversationId || !senderId) {
      return NextResponse.json({ error: "اطلاعات ناقص است." }, { status: 400 });
    }

    // احراز هویت: باید یک نشست معتبر باشد و دقیقاً متعلق به همان senderId ادعاشده
    // (بدون این بررسی، هرکسی می‌توانست با هر conversationId/senderId دلخواه
    // به این endpoint درخواست بزند و برای اعضای هر گفتگویی نوتیفیکیشن جعلی بفرستد)
    const authHeader = req.headers.get("authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    if (!token) {
      return NextResponse.json({ error: "احراز هویت لازم است." }, { status: 401 });
    }

    const supabaseAdmin = getSupabaseAdmin();

    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);
    if (userError || !userData?.user || userData.user.id !== senderId) {
      return NextResponse.json({ error: "نشست نامعتبر است." }, { status: 401 });
    }

    // مطمئن می‌شویم فرستنده واقعاً عضو همین گفتگو است
    const { data: senderMembership } = await supabaseAdmin
      .from("conversation_members")
      .select("user_id")
      .eq("conversation_id", conversationId)
      .eq("user_id", senderId)
      .maybeSingle();
    if (!senderMembership) {
      return NextResponse.json({ error: "دسترسی غیرمجاز." }, { status: 403 });
    }

    const { data: senderProfile } = await supabaseAdmin
      .from("profiles")
      .select("name")
      .eq("id", senderId)
      .maybeSingle();
    const senderName = senderProfile?.name || "پیام جدید در EngiX";

    // اعضای گفتگو به‌جز خودِ فرستنده را پیدا می‌کنیم
    // (join تو در توی قبلی به‌خاطر مشکل schema cache در دیتابیس خطا
    // می‌داد؛ اینجا با دو کوئری جدا و اتصال دستی جایگزین شده)
    const { data: memberRows, error: membersErr } = await supabaseAdmin
      .from("conversation_members")
      .select("user_id")
      .eq("conversation_id", conversationId)
      .neq("user_id", senderId);

    if (membersErr) throw new Error(membersErr.message);

    const memberIds = (memberRows || []).map((m) => m.user_id);
    let tokens = [];
    if (memberIds.length > 0) {
      const { data: memberProfiles, error: profErr } = await supabaseAdmin
        .from("profiles")
        .select("fcm_token")
        .in("id", memberIds);
      if (profErr) throw new Error(profErr.message);
      tokens = (memberProfiles || []).map((p) => p.fcm_token).filter(Boolean);
    }

    if (tokens.length === 0) {
      // کسی توکن فعال ندارد (مثلاً همه از قبل توی اپ نصب‌شده لاگین نکرده‌اند)
      return NextResponse.json({ sent: 0 });
    }

    getFirebaseAdmin();

    const message = {
      notification: {
        title: senderName || "پیام جدید در EngiX",
        body: (text || "").slice(0, 120) || "یک پیام جدید دریافت کردید.",
      },
      data: { conversationId: String(conversationId) },
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

    // توکن‌های نامعتبر/منقضی‌شده را از پروفایل کاربر پاک می‌کنیم تا دفعه‌ی بعد
    // دوباره تلاش بی‌فایده برایشان انجام نشود.
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
    console.error("send-message-push error:", e.message);
    // این خطا هرگز نباید ارسال خود پیام را متوقف کند، پس فقط لاگ می‌کنیم
    return NextResponse.json({ error: e.message }, { status: 200 });
  }
}
