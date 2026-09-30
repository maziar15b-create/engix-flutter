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
    .from("blocks")
    .select("blocked_id, created_at, blocked:profiles!blocks_blocked_id_fkey(id, name, username, avatar_url)")
    .eq("blocker_id", user.id)
    .order("created_at", { ascending: false });
  if (error) return NextResponse.json({ error: error.message }, { status: 500 });

  return NextResponse.json({ blocked: data });
}

export async function POST(req) {
  const supabaseAdmin = getSupabaseAdmin();
  const user = await auth(req, supabaseAdmin);
  if (!user) return NextResponse.json({ error: "نشست نامعتبر است." }, { status: 401 });

  const { username, code } = await req.json();
  let target;
  if (username) {
    const { data } = await supabaseAdmin.from("profiles").select("id").eq("username", username).maybeSingle();
    target = data;
  } else if (code) {
    const { data } = await supabaseAdmin.from("profiles").select("id").eq("code", code).maybeSingle();
    target = data;
  }
  if (!target) return NextResponse.json({ error: "کاربری پیدا نشد." }, { status: 404 });
  if (target.id === user.id) return NextResponse.json({ error: "نمی‌توانید خودتان را مسدود کنید." }, { status: 400 });

  const { error } = await supabaseAdmin.from("blocks").insert({ blocker_id: user.id, blocked_id: target.id });
  if (error && error.code !== "23505") return NextResponse.json({ error: error.message }, { status: 500 });

  await supabaseAdmin.from("follows").delete().eq("follower_id", user.id).eq("following_id", target.id);
  await supabaseAdmin.from("follows").delete().eq("follower_id", target.id).eq("following_id", user.id);

  return NextResponse.json({ success: true });
}

export async function DELETE(req) {
  const supabaseAdmin = getSupabaseAdmin();
  const user = await auth(req, supabaseAdmin);
  if (!user) return NextResponse.json({ error: "نشست نامعتبر است." }, { status: 401 });

  const { blockedId } = await req.json();
  const { error } = await supabaseAdmin
    .from("blocks")
    .delete()
    .eq("blocker_id", user.id)
    .eq("blocked_id", blockedId);
  if (error) return NextResponse.json({ error: error.message }, { status: 500 });

  return NextResponse.json({ success: true });
}
