import { NextResponse } from "next/server";
import { getSupabaseAdmin } from "../../../../lib/supabaseAdmin";

export async function GET(req) {
  try {
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

    const { data: profile, error: profileError } = await supabaseAdmin
      .from("profiles")
      .select("is_admin")
      .eq("id", userData.user.id)
      .single();

    if (profileError || !profile?.is_admin) {
      return NextResponse.json({ error: "دسترسی غیرمجاز." }, { status: 403 });
    }

    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const [
      totalRes,
      onlineRes,
      todayRes,
      activeProjectsRes,
      jobSeekingRes,
      hiringRes,
    ] = await Promise.all([
      supabaseAdmin.from("profiles").select("id", { count: "exact", head: true }),
      supabaseAdmin.from("profiles").select("id", { count: "exact", head: true }).eq("is_online", true),
      supabaseAdmin
        .from("profiles")
        .select("id", { count: "exact", head: true })
        .gte("last_seen", startOfToday.toISOString()),
      // پروژه‌ها فعلاً فیلد status ندارند، پس همه‌ی پروژه‌های ثبت‌شده «فعال» شمرده می‌شوند
      supabaseAdmin.from("projects").select("id", { count: "exact", head: true }),
      supabaseAdmin
        .from("job_listings")
        .select("id", { count: "exact", head: true })
        .eq("status", "active")
        .eq("listing_type", "job_seeking"),
      supabaseAdmin
        .from("job_listings")
        .select("id", { count: "exact", head: true })
        .eq("status", "active")
        .eq("listing_type", "hiring"),
    ]);

    return NextResponse.json({
      total: totalRes.count ?? 0,
      online: onlineRes.count ?? 0,
      today: todayRes.count ?? 0,
      activeProjects: activeProjectsRes.count ?? 0,
      jobSeekingListings: jobSeekingRes.count ?? 0,
      hiringListings: hiringRes.count ?? 0,
    });
  } catch (e) {
    return NextResponse.json({ error: e.message }, { status: 500 });
  }
}
