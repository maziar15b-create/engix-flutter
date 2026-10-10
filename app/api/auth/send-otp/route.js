import { NextResponse } from "next/server";
import crypto from "crypto";
import { getSupabaseAdmin } from "../../../../lib/supabaseAdmin";

export const maxDuration = 30;

function normalizePhone(p) {
  return (p || "")
    .replace(/[۰-۹]/g, (d) => String("۰۱۲۳۴۵۶۷۸۹".indexOf(d)))
    .replace(/[٠-٩]/g, (d) => String("٠١٢٣٤٥٦٧٨٩".indexOf(d)))
    .replace(/\D/g, "")
    .slice(-10);
}

const BYPASS_PHONE = process.env.OTP_BYPASS_PHONE || null;
const BYPASS_CODE = process.env.OTP_BYPASS_CODE || null;

const COOLDOWN_SECONDS = 60;
const MAX_REQUESTS_PER_WINDOW = 8;
const WINDOW_MINUTES = 60;
const CODE_TTL_MINUTES = 5;

async function sendSms(fullPhone, code) {
  const params = new URLSearchParams({
    receptor: fullPhone,
    token: code,
    template: process.env.KAVENEGAR_TEMPLATE || "otpverify",
  });
  const url = `https://api.kavenegar.com/v1/${process.env.KAVENEGAR_API_KEY}/verify/lookup.json?${params.toString()}`;

  let lastErr = null;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(10000) });
      let data = null;
      try {
        data = await res.json();
      } catch (_) {}
      if (res.ok && data && data.return && data.return.status === 200) return;
      if (data && data.return && data.return.status && data.return.status < 500) {
        throw new Error(data.return.message || "ارسال پیامک ناموفق بود.");
      }
      lastErr = new Error((data && data.return && data.return.message) || "ارسال پیامک ناموفق بود.");
    } catch (e) {
      if (e && e.name !== "TimeoutError" && e.name !== "TypeError" && e.name !== "AbortError") throw e;
      lastErr = new Error("سرویس پیامک پاسخ نداد. دوباره تلاش کنید.");
    }
  }
  throw lastErr || new Error("ارسال پیامک ناموفق بود.");
}

export async function POST(req) {
  let insertedId = null;
  const supabaseAdmin = (() => {
    try {
      return getSupabaseAdmin();
    } catch (e) {
      return null;
    }
  })();
  try {
    if (!supabaseAdmin) throw new Error("پیکربندی سرور ناقص است.");
    const { phone } = await req.json();
    const normalized = normalizePhone(phone);
    if (normalized.length !== 10) {
      return NextResponse.json({ error: "شماره موبایل معتبر نیست." }, { status: 400 });
    }
    const fullPhone = "0" + normalized;
    const isBypass = !!BYPASS_PHONE && !!BYPASS_CODE && normalized === BYPASS_PHONE;

    if (!isBypass) {
      const { data: lastReq } = await supabaseAdmin
        .from("otp_requests")
        .select("created_at, expires_at, consumed")
        .eq("phone", fullPhone)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (lastReq) {
        const secondsSinceLast = (Date.now() - new Date(lastReq.created_at).getTime()) / 1000;
        const stillValid = !lastReq.consumed && new Date(lastReq.expires_at).getTime() > Date.now();
        if (secondsSinceLast < COOLDOWN_SECONDS && stillValid) {
          return NextResponse.json({ success: true, alreadySent: true });
        }
        if (secondsSinceLast < COOLDOWN_SECONDS) {
          const wait = Math.ceil(COOLDOWN_SECONDS - secondsSinceLast);
          return NextResponse.json({ error: `لطفاً ${wait} ثانیه دیگر دوباره تلاش کنید.` }, { status: 429 });
        }
      }

      const windowStart = new Date(Date.now() - WINDOW_MINUTES * 60 * 1000).toISOString();
      const { count: recentCount } = await supabaseAdmin
        .from("otp_requests")
        .select("id", { count: "exact", head: true })
        .eq("phone", fullPhone)
        .gte("created_at", windowStart);

      if ((recentCount || 0) >= MAX_REQUESTS_PER_WINDOW) {
        return NextResponse.json(
          { error: "تعداد درخواست‌های شما بیش از حد مجاز است. کمی بعد دوباره تلاش کنید." },
          { status: 429 }
        );
      }
    }

    const code = isBypass ? BYPASS_CODE : crypto.randomInt(100000, 1000000).toString();
    const codeHash = crypto.createHash("sha256").update(code).digest("hex");
    const expiresAt = new Date(Date.now() + (isBypass ? 60 : CODE_TTL_MINUTES) * 60 * 1000).toISOString();

    const { data: inserted, error: dbErr } = await supabaseAdmin
      .from("otp_requests")
      .insert({ phone: fullPhone, code_hash: codeHash, expires_at: expiresAt })
      .select("id")
      .single();
    if (dbErr) throw new Error("خطای موقت سرور. دوباره تلاش کنید.");
    insertedId = inserted?.id || null;

    if (!isBypass) {
      await sendSms(fullPhone, code);
    }

    return NextResponse.json({ success: true });
  } catch (e) {
    if (insertedId && supabaseAdmin) {
      try {
        await supabaseAdmin.from("otp_requests").delete().eq("id", insertedId);
      } catch (_) {}
    }
    return NextResponse.json({ error: e.message || "خطای ناشناخته" }, { status: 400 });
  }
}
