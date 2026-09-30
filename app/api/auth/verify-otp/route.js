import { NextResponse } from "next/server";
import crypto from "crypto";
import { createClient } from "@supabase/supabase-js";
import { getSupabaseAdmin } from "../../../../lib/supabaseAdmin";

function normalizePhone(p) {
  return (p || "").replace(/\D/g, "").slice(-10);
}

export async function POST(req) {
  try {
    const supabaseAdmin = getSupabaseAdmin();
    const { phone, code } = await req.json();
    const normalized = normalizePhone(phone);
    const fullPhone = "0" + normalized;
    const fakeEmail = "p" + normalized + "@engix.internal";
    const codeHash = crypto.createHash("sha256").update((code || "").trim()).digest("hex");

    const { data: otpRow, error: fetchErr } = await supabaseAdmin
      .from("otp_requests")
      .select("*")
      .eq("phone", fullPhone)
      .eq("consumed", false)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (fetchErr || !otpRow) {
      return NextResponse.json({ error: "کدی برای این شماره ارسال نشده است." }, { status: 400 });
    }
    if (new Date(otpRow.expires_at).getTime() < Date.now()) {
      return NextResponse.json({ error: "کد منقضی شده است. دوباره درخواست کنید." }, { status: 400 });
    }
    if (otpRow.attempts >= 5) {
      return NextResponse.json({ error: "تعداد تلاش بیش از حد مجاز است." }, { status: 400 });
    }
    if (otpRow.code_hash !== codeHash) {
      await supabaseAdmin.from("otp_requests").update({ attempts: otpRow.attempts + 1 }).eq("id", otpRow.id);
      return NextResponse.json({ error: "کد وارد شده اشتباه است." }, { status: 400 });
    }

    await supabaseAdmin.from("otp_requests").update({ consumed: true }).eq("id", otpRow.id);

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
      await supabaseAdmin.auth.admin.updateUserById(userId, {
        password: tempPassword,
        email: fakeEmail,
        email_confirm: true,
      });
    } else {
      const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
        email: fakeEmail,
        password: tempPassword,
        email_confirm: true,
      });
      if (createErr) {
        if (String(createErr.message).toLowerCase().includes("already registered")) {
          // با کاربران زیاد، صفحه‌ی اول (200 تای اول) ممکن است کاربر مدنظر را شامل نشود؛
          // صفحه به صفحه جلو می‌رویم تا پیدا شود (با سقفی برای جلوگیری از حلقه‌ی بی‌پایان)
          let found = null;
          for (let p = 1; p <= 50 && !found; p++) {
            const { data: pageData } = await supabaseAdmin.auth.admin.listUsers({ page: p, perPage: 1000 });
            const users = pageData?.users || [];
            found = users.find((u) => u.email === fakeEmail) || null;
            if (users.length < 1000) break; // به آخرین صفحه رسیدیم
          }
          if (!found) throw new Error(createErr.message);
          userId = found.id;
          await supabaseAdmin.auth.admin.updateUserById(userId, { password: tempPassword, email_confirm: true });
        } else {
          throw new Error(createErr.message);
        }
      } else {
        userId = created.user.id;
        isNewUser = true;
      }
    }

    const anonClient = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);
    const { data: signInData, error: signInErr } = await anonClient.auth.signInWithPassword({
      email: fakeEmail,
      password: tempPassword,
    });
    if (signInErr) throw new Error(signInErr.message);

    return NextResponse.json({
      success: true,
      isNewUser: isNewUser || !existingProfile,
      session: {
        access_token: signInData.session.access_token,
        refresh_token: signInData.session.refresh_token,
      },
    });
  } catch (e) {
    return NextResponse.json({ error: e.message }, { status: 400 });
  }
}
