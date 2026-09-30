import { NextResponse } from "next/server";
import { getSupabaseAdmin } from "../../../../lib/supabaseAdmin";
import { fetchRssItems } from "../../../../lib/rss";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

const MAX_NEW_ITEMS_PER_SOURCE = 5;
const DEFAULT_IMPORTANCE = 3;

export async function GET(req) {
  return runSync(req);
}
export async function POST(req) {
  return runSync(req);
}

async function isAuthorized(req, supabase) {
  const auth = req.headers.get("authorization") || "";
  const token = auth.replace(/^Bearer\s+/i, "");

  // حالت ۱: فراخوانی خودکار (مثلاً از Vercel Cron) با CRON_SECRET
  if (process.env.CRON_SECRET && token === process.env.CRON_SECRET) {
    return true;
  }

  // حالت ۲: فراخوانی دستی از پنل مدیریت — با نشست یک کاربر ادمین لاگین‌شده
  if (token) {
    const { data: userData, error: userError } = await supabase.auth.getUser(token);
    if (!userError && userData?.user) {
      const { data: profile } = await supabase
        .from("profiles")
        .select("is_admin")
        .eq("id", userData.user.id)
        .single();
      if (profile?.is_admin) return true;
    }
  }

  return false;
}

// حذف تگ‌های HTML ساده از توضیحات RSS، برای این‌که summary تمیز ذخیره بشه
function stripHtml(text) {
  if (!text) return "";
  return text.replace(/<[^>]*>/g, "").trim().slice(0, 500);
}

async function runSync(req) {
  const supabase = getSupabaseAdmin();

  if (!(await isAuthorized(req, supabase))) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const report = { sources: [], inserted: 0, skipped: 0, errors: [] };

  const { data: sources, error: sourcesErr } = await supabase
    .from("news_sources")
    .select("*")
    .eq("is_active", true);

  if (sourcesErr) {
    return NextResponse.json({ error: sourcesErr.message }, { status: 500 });
  }

  const { data: categories } = await supabase.from("news_categories").select("id, key");
  const categoryIdByKey = Object.fromEntries((categories || []).map((c) => [c.key, c.id]));

  for (const source of sources || []) {
    const sourceReport = { name: source.name, fetched: 0, inserted: 0, error: null };
    try {
      const items = await fetchRssItems(source.rss_url, MAX_NEW_ITEMS_PER_SOURCE);
      sourceReport.fetched = items.length;

      for (const item of items) {
        const { data: existing } = await supabase
          .from("news")
          .select("id")
          .eq("url", item.link)
          .maybeSingle();
        if (existing) { report.skipped++; continue; }

        // بدون تحلیل هوش مصنوعی — مستقیم از عنوان/توضیح خود RSS استفاده می‌شود
        const categoryId = categoryIdByKey[source.default_category_key] || null;

        const { error: insertErr } = await supabase.from("news").insert({
          source_id: source.id,
          category_id: categoryId,
          title: item.title,
          summary: stripHtml(item.description),
          keywords: null,
          importance: DEFAULT_IMPORTANCE,
          url: item.link,
          published_at: item.publishedAt ? new Date(item.publishedAt).toISOString() : null,
        });

        if (insertErr) {
          report.errors.push(`Insert (${source.name}): ${insertErr.message}`);
        } else {
          report.inserted++;
          sourceReport.inserted++;
        }
      }

      await supabase.from("news_sources").update({ last_fetched_at: new Date().toISOString() }).eq("id", source.id);
    } catch (e) {
      sourceReport.error = e.message;
      report.errors.push(`${source.name}: ${e.message}`);
    }
    report.sources.push(sourceReport);
  }

  return NextResponse.json(report);
}
