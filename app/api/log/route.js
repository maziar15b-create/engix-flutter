import { NextResponse } from "next/server";
import { getSupabaseAdmin } from "../../../lib/supabaseAdmin";

const ALLOWED_LEVELS = ["error", "warn", "info"];
const MAX_STRING_LEN = 4000; // جلوی رشته‌های غول‌آسا (که هزینه/فضای دیتابیس رو بی‌دلیل بالا می‌برن) رو می‌گیرد

function clampString(value, maxLen) {
  if (value === null || value === undefined) return null;
  const s = String(value);
  return s.length > maxLen ? s.slice(0, maxLen) : s;
}

export async function POST(req) {
  try {
    const body = await req.json();

    // فقط فیلدهای مورد انتظار را می‌پذیریم؛ ورودی خام کلاینت مستقیم به دیتابیس
    // پاس داده نمی‌شود تا کسی نتواند با کلیدهای دلخواه، ستون‌های دیگر جدول را ست کند.
    const level = ALLOWED_LEVELS.includes(body?.level) ? body.level : "error";
    const payload = {
      level,
      source: "client",
      message: clampString(body?.message, MAX_STRING_LEN) || "(no message)",
      stack: clampString(body?.stack, MAX_STRING_LEN),
      url: clampString(body?.url, 2000),
      user_id: typeof body?.user_id === "string" ? body.user_id.slice(0, 200) : null,
      extra: body?.extra && typeof body.extra === "object" ? body.extra : null,
    };

    const supabaseAdmin = getSupabaseAdmin();
    await supabaseAdmin.from("app_logs").insert(payload);
    return NextResponse.json({ ok: true });
  } catch (e) {
    console.error("log route failed:", e);
    return NextResponse.json({ ok: false }, { status: 500 });
  }
}
