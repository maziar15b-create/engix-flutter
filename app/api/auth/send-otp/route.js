import { NextResponse } from "next/server";
import crypto from "crypto";
import { getSupabaseAdmin } from "../../../../lib/supabaseAdmin";

function normalizePhone(p) {
  return (p || "").replace(/\D/g, "").slice(-10);
}

// شماره/کد تست فقط در صورتی فعال می‌شود که در متغیرهای محیطی تنظیم شده باشد
// (به‌صورت پیش‌فرض در پروداکشن غیرفعال است — قبلاً این مقادیر مستقیم در کد
// هاردکد شده بودند که یک راه دور زدن امنیتی ثابت و عمومی محسوب می‌شد)
const BYPASS_PHONE = process.env.OTP_BYPASS_PHONE || null;
const BYPASS_CODE = process.env.OTP_BYPASS_CODE || null;

// جلوگیری از سوءاستفاده (پیامک‌بمب / هزینه‌تراشی روی Kavenegar):
// حداقل فاصله بین دو درخواست متوالی برای یک شماره، و سقف تعداد درخواست در بازه‌ی طولانی‌تر
const COOLDOWN_SECONDS = 60;
const MAX_REQUESTS_PER_WINDOW = 8;
const WINDOW_MINUTES = 60;

export async function POST(req) {
  try {
    const supabaseAdmin = getSupabaseAdmin();
    const { phone } = await req.json();
    const normalized = normalizePhone(phone);
    if (normalized.length !== 10) {
      return NextResponse.json({ error: "شماره موبایل معتبر نیست." }, { status: 400 });
    }
    const fullPhone = "0" + normalized;
    const isBypass = !!BYPASS_PHONE && !!BYPASS_CODE && normalized === BYPASS_PHONE;

    if (!isBypass) {
      // ۱) فاصله‌ی حداقلی از آخرین درخواست همین شماره
      const { data: lastReq } = await supabaseAdmin
        .from("otp_requests")
        .select("created_at")
        .eq("phone", fullPhone)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (lastReq) {
        const secondsSinceLast = (Date.now() - new Date(lastReq.created_at).getTime()) / 1000;
        if (secondsSinceLast < COOLDOWN_SECONDS) {
          const wait = Math.ceil(COOLDOWN_SECONDS - secondsSinceLast);
          return NextResponse.json(
            { error: `لطفاً ${wait} ثانیه دیگر دوباره تلاش کنید.` },
            { status: 429 }
          );
        }
      }

      // ۲) سقف تعداد درخواست در یک بازه‌ی زمانی، برای جلوگیری از اسپم مداوم
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

    const code = isBypass ? BYPASS_CODE : Math.floor(100000 + Math.random() * 900000).toString();
    const codeHash = crypto.createHash("sha256").update(code).digest("hex");
    const expiresAt = new Date(Date.now() + (isBypass ? 60 : 2) * 60 * 1000).toISOString();

    const { error: dbErr } = await supabaseAdmin.from("otp_requests").insert({
      phone: fullPhone,
      code_hash: codeHash,
      expires_at: expiresAt,
    });
    if (dbErr) throw new Error(dbErr.message);

    if (!isBypass) {
      const params = new URLSearchParams({
        receptor: fullPhone,
        token: code,
        template: process.env.KAVENEGAR_TEMPLATE || "otpverify",
      });
      const res = await fetch(
        `https://api.kavenegar.com/v1/${process.env.KAVENEGAR_API_KEY}/verify/lookup.json?${params.toString()}`
      );
      const data = await res.json();
      if (!res.ok || (data.return && data.return.status !== 200)) {
        throw new Error((data.return && data.return.message) || "ارسال پیامک ناموفق بود.");
      }
    }

    return NextResponse.json({ success: true });
  } catch (e) {
    return NextResponse.json({ error: e.message }, { status: 400 });
  }
}
