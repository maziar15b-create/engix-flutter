import { NextResponse } from "next/server";
import { getSupabaseAdmin } from "../../../../lib/supabaseAdmin";

async function auth(req, supabaseAdmin) {
  const authHeader = req.headers.get("authorization") || "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data } = await supabaseAdmin.auth.getUser(token);
  return data?.user || null;
}

export async function GET(req) {
  const supabaseAdmin = getSupabaseAdmin();
  const user = await auth(req, supabaseAdmin);
  if (!user) return NextResponse.json({ error: "نشست نامعتبر است." }, { status: 401 });

  const { data, error } = await supabaseAdmin
    .from("user_sessions")
    .select("*")
    .eq("user_id", user.id)
    .order("last_active", { ascending: false });
  if (error) return NextResponse.json({ error: error.message }, { status: 500 });

  return NextResponse.json({ sessions: data });
}

export async function POST(req) {
  const supabaseAdmin = getSupabaseAdmin();
  const user = await auth(req, supabaseAdmin);
  if (!user) return NextResponse.json({ error: "نشست نامعتبر است." }, { status: 401 });

  const { deviceInfo } = await req.json();
  const { error } = await supabaseAdmin.from("user_sessions").insert({
    user_id: user.id,
    device_info: deviceInfo || "دستگاه نامشخص",
  });
  if (error) return NextResponse.json({ error: error.message }, { status: 500 });

  return NextResponse.json({ success: true });
}

export async function DELETE(req) {
  const supabaseAdmin = getSupabaseAdmin();
  const user = await auth(req, supabaseAdmin);
  if (!user) return NextResponse.json({ error: "نشست نامعتبر است." }, { status: 401 });

  const body = await req.json().catch(() => ({}));
  const { sessionId, mode } = body;

  if (sessionId) {
    // حذف یک نشست مشخص — فقط اگر واقعاً مال خود کاربر باشد
    const { data: session, error: findErr } = await supabaseAdmin
      .from("user_sessions")
      .select("id, user_id")
      .eq("id", sessionId)
      .maybeSingle();
    if (findErr || !session) return NextResponse.json({ error: "نشست پیدا نشد." }, { status: 404 });
    if (session.user_id !== user.id) {
      return NextResponse.json({ error: "اجازه‌ی حذف این نشست را ندارید." }, { status: 403 });
    }
    const { error: delErr } = await supabaseAdmin.from("user_sessions").delete().eq("id", sessionId);
    if (delErr) return NextResponse.json({ error: delErr.message }, { status: 500 });
    return NextResponse.json({ success: true });
  }

  // حذف همه‌ی نشست‌های دیگر (به‌جز جدیدترین = همین دستگاه)
  await supabaseAdmin.auth.admin.signOut(user.id, "others");
  const { data: sessions } = await supabaseAdmin
    .from("user_sessions")
    .select("id")
    .eq("user_id", user.id)
    .order("created_at", { ascending: false });
  if (sessions && sessions.length > 1) {
    const idsToDelete = sessions.slice(1).map((s) => s.id);
    await supabaseAdmin.from("user_sessions").delete().in("id", idsToDelete);
  }

  return NextResponse.json({ success: true });
}
