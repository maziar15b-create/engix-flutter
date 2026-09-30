import { supabase } from "./supabaseClient";

export async function notifyUser(userId, type, title, body) {
  try {
    const { data: prof } = await supabase.from("profiles").select("notification_prefs").eq("id", userId).maybeSingle();
    const prefs = (prof && prof.notification_prefs) || {};
    if (prefs[type] === false) return;
    await supabase.from("notifications").insert({ user_id: userId, type, title, body });

    // تا اینجا فقط یک ردیف در دیتابیس ثبت شد (برای لیست نوتیفیکیشن‌های داخل اپ).
    // بدون این بخش، هیچ push واقعی به گوشی نمی‌رفت و در نتیجه نه صدایی پخش
    // می‌شد و نه چیزی روی نوار اعلان‌های گوشی نشان داده می‌شد.
    // عمداً await نمی‌شود (fire-and-forget) تا کند بودن/خطای شبکه، جریان اصلی را کند نکند.
    triggerPush([userId], title, body, { type }).catch(() => {});
  } catch (e) {
    /* ignore */
  }
}

// چند نفر را همزمان با یک درخواست پوش می‌کند (مثلاً همه‌ی اعضای پروژه هنگام اطلاعیه)
export async function notifyUsers(userIds, type, title, body) {
  const ids = (userIds || []).filter(Boolean);
  if (ids.length === 0) return;
  try {
    const { data: profs } = await supabase.from("profiles").select("id, notification_prefs").in("id", ids);
    const allowedIds = (profs || [])
      .filter((p) => (p.notification_prefs || {})[type] !== false)
      .map((p) => p.id);
    if (allowedIds.length === 0) return;
    await supabase.from("notifications").insert(allowedIds.map((uid) => ({ user_id: uid, type, title, body })));
    triggerPush(allowedIds, title, body, { type }).catch(() => {});
  } catch (e) {
    /* ignore */
  }
}

async function triggerPush(userIds, title, body, data) {
  const { data: sessionData } = await supabase.auth.getSession();
  const token = sessionData?.session?.access_token;
  if (!token) return;
  await fetch("/api/notifications/send-push", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ userIds, title, body, data }),
  });
}
