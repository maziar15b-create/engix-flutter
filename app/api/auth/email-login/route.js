import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { getSupabaseAdmin } from "../../../../lib/supabaseAdmin";

export async function POST(req) {
  try {
    const { email, password } = await req.json();
    if (!email || !email.trim() || !password || password.length < 6) {
      return NextResponse.json({ error: "ایمیل و رمز عبور (حداقل ۶ کاراکتر) را وارد کنید." }, { status: 400 });
    }
    const cleanEmail = email.trim().toLowerCase();

    const anonClient = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);
    let { data: signInData, error: signInErr } = await anonClient.auth.signInWithPassword({
      email: cleanEmail,
      password,
    });

    if (signInErr) {
      const admin = getSupabaseAdmin();
      const { error: createErr } = await admin.auth.admin.createUser({
        email: cleanEmail,
        password,
        email_confirm: true,
      });
      if (createErr && !String(createErr.message).toLowerCase().includes("already registered")) {
        return NextResponse.json({ error: createErr.message }, { status: 400 });
      }

      const retry = await anonClient.auth.signInWithPassword({ email: cleanEmail, password });
      signInData = retry.data;
      signInErr = retry.error;
    }

    if (signInErr) {
      return NextResponse.json({ error: "ایمیل یا رمز عبور اشتباه است." }, { status: 400 });
    }

    return NextResponse.json({
      success: true,
      session: {
        access_token: signInData.session.access_token,
        refresh_token: signInData.session.refresh_token,
      },
    });
  } catch (e) {
    return NextResponse.json({ error: e.message }, { status: 400 });
  }
}
