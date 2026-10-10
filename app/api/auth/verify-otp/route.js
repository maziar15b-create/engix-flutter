import { NextResponse } from "next/server";
import crypto from "crypto";
import { createClient } from "@supabase/supabase-js";
import { getSupabaseAdmin } from "../../../../lib/supabaseAdmin";

export const maxDuration = 30;

function normalizePhone(p) {
  return (p || "")
    .replace(/[۰-۹]/g, (d) => String("۰۱۲۳۴۵۶۷۸۹".indexOf(d)))
    .replace(/[٠-٩]/g, (d) => String("٠١٢٣٤٥٦٧٨٩".indexOf(d)))
    .replace(/\D/g, "")
    .slice(-10);
}

function normalizeCode(c) {
  return String(c || "")
    .replace(/[۰-۹]/g, (d) => String("۰۱۲۳۴۵۶۷۸۹".indexOf(d)))
    .replace(/[٠-٩]/g, (d) => String("٠١٢٣٤٥٦٧٨٩".indexOf(d)))
    .replace(/\D/g, "");
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export async function POST(req) {
  let supabaseAdmin = null;
  let consumedId = null;
  try {
    supabaseAdmin = getSupabaseAdmin();
    const { phone, code } = await req.json();
    const normalized = normalizePhone(phone);
    if (normalized.length !== 10) {
      return NextResponse.json({ error: "شماره موبایل معتبر نیست." }, { status: 400 });
    }
    const cleanCode = normalizeCode(code);
    if (!cleanCode) {
      return NextResponse.json({ error: "کد تایید را وارد کنید." }, { status: 400 });
    }
    const fullPhone = "0" + normalized;
    const fakeEmail = "p" + normalized + "@engix.internal";
    const codeHash = crypto.createHash("sha256").update(cleanCode).digest("hex");

    const { data: rows, error: fetchErr } = await supabaseAdmin
      .from("otp_requests")
      .select("*")
      .eq("phone", fullPhone)
      .eq("consumed", false)
      .order("created_at", { ascending: false })
      .limit(5);

    if (fetchErr) throw new Error("خطای موقت سرور. دوباره تلاش کنید.");
    if (!rows || rows.length === 0) {
      return NextResponse.json({ error: "کدی برای این شماره ارسال نشده یا قبلاً استفاده شده است. دوباره کد بگیرید." }, { status: 400 });
    }

    const now = Date.now();
    const live = rows.filter((r) => new Date(r.expires_at).getTime() >= now);
    if (live.length === 0) {
      return NextResponse.json({ error: "کد منقضی شده است. دوباره درخواست کنید." }, { status: 400 });
    }
    const usable = live.filter((r) => r.attempts < 5);
    if (usable.length === 0) {
      return NextResponse.json({ error: "تعداد تلاش بیش از حد مجاز است. دوباره کد بگیرید." }, { status: 400 });
    }

    const otpRow = usable.find((r) => r.code_hash === codeHash);
    if (!otpRow) {
      const latest = usable[0];
      await supabaseAdmin.from("otp_requests").update({ attempts: latest.attempts + 1 }).eq("id", latest.id);
      return NextResponse.json({ error: "کد وارد شده اشتباه است." }, { status: 400 });
    }

    const { data: claimed, error: claimErr } = await supabaseAdmin
      .from("otp_requests")
      .update({ consumed: true })
      .eq("id", otpRow.id)
      .eq("consumed", false)
      .select("id");
    if (claimErr) throw new Error("خطای موقت سرور. دوباره تلاش کنید.");
    if (!claimed || claimed.length === 0) {
      return NextResponse.json({ error: "این کد قبلاً استفاده شده است." }, { status: 400 });
    }
    consumedId = otpRow.id;

    const tempPassword = crypto.randomBytes(24).toString("hex");
    let userId = null;
    let isNewUser = false;

    const { data: existingProfile } = await supabaseAdmin
      .from("profiles")
      .select("id")
      .eq("phone", fullPhone)
      .maybeSingle();

    if (existingProfile) {
      userId = existingProfile.id;
      const { error: updErr } = await supabaseAdmin.auth.admin.updateUserById(userId, {
        password: tempPassword,
        email: fakeEmail,
        email_confirm: true,
      });
      if (updErr) throw new Error(updErr.message);
    } else {
      const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
        email: fakeEmail,
        password: tempPassword,
        email_confirm: true,
      });
      if (createErr) {
        const msg = String(createErr.message).toLowerCase();
        if (msg.includes("already") && msg.includes("regist")) {
          let found = null;
          for (let p = 1; p <= 50 && !found; p++) {
            const { data: pageData } = await supabaseAdmin.auth.admin.listUsers({ page: p, perPage: 1000 });
            const users = pageData?.users || [];
            found = users.find((u) => u.email === fakeEmail) || null;
            if (users.length < 1000) break;
          }
          if (!found) throw new Error(createErr.message);
          userId = found.id;
          const { error: updErr } = await supabaseAdmin.auth.admin.updateUserById(userId, {
            password: tempPassword,
            email_confirm: true,
          });
          if (updErr) throw new Error(updErr.message);
        } else {
          throw new Error(createErr.message);
        }
      } else {
        userId = created.user.id;
        isNewUser = true;
      }
    }

    const anonClient = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    let signInData = null;
    let signInErr = null;
    for (let i = 0; i < 4; i++) {
      const r = await anonClient.auth.signInWithPassword({ email: fakeEmail, password: tempPassword });
      signInData = r.data;
      signInErr = r.error;
      if (!signInErr && signInData?.session) break;
      await sleep(350 * (i + 1));
    }
    if (signInErr || !signInData?.session) {
      throw new Error("ورود ناموفق بود. دوباره تلاش کنید.");
    }

    return NextResponse.json({
      success: true,
      isNewUser: isNewUser || !existingProfile,
      session: {
        access_token: signInData.session.access_token,
        refresh_token: signInData.session.refresh_token,
      },
    });
  } catch (e) {
    if (consumedId && supabaseAdmin) {
      try {
        await supabaseAdmin.from("otp_requests").update({ consumed: false }).eq("id", consumedId);
      } catch (_) {}
    }
    return NextResponse.json({ error: e.message || "خطای ناشناخته" }, { status: 400 });
  }
}
