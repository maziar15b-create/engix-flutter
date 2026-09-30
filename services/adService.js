import { supabase } from "../lib/supabaseClient";

const ROLE_OPTIONS = [
  { value: "design", label: "طراح" },
  { value: "execution", label: "مجری" },
  { value: "supervision", label: "ناظر" },
  { value: "site_manager", label: "مدیر کارگاه" },
];

export { ROLE_OPTIONS };

// فقط تبلیغات فعال (active = true) را برمی‌گرداند — این تابع برای نمایش عمومی استفاده می‌شود
export async function fetchActiveAds() {
  const { data, error } = await supabase
    .from("ads")
    .select("*")
    .eq("active", true)
    .order("priority", { ascending: false })
    .order("created_at", { ascending: false })
    .limit(30); // این کوئری هر بار در خانه اجرا می‌شود؛ بدون سقف با زیاد شدن تبلیغ‌ها کند می‌شد
  if (error) throw new Error(error.message);
  return data || [];
}

// همه‌ی تبلیغات فعالی که برای این پروفایل مجاز هستند را برمی‌گرداند
// (برای چرخش خودکار بین چند تبلیغ در AdBanner استفاده می‌شود)
export async function fetchEligibleAdsForProfile(profile) {
  const ads = await fetchActiveAds();
  const userRoles = (profile && profile.roles) || [];
  return ads.filter((ad) => {
    if (!ad.target_roles || ad.target_roles.length === 0) return true;
    return ad.target_roles.some((r) => userRoles.includes(r));
  });
}

// نسخه‌ی قدیمی — فقط اولین تبلیغ مجاز را برمی‌گرداند (برای سازگاری با کدهای قبلی)
export async function fetchAdForProfile(profile) {
  const eligible = await fetchEligibleAdsForProfile(profile);
  return eligible[0] || null;
}

export async function recordImpression(adId) {
  try {
    await supabase.rpc("increment_ad_stat", { ad_id: adId, stat: "impression" });
  } catch (e) {}
}

export async function recordClick(adId) {
  try {
    await supabase.rpc("increment_ad_stat", { ad_id: adId, stat: "click" });
  } catch (e) {}
}

export async function uploadAdImage(file) {
  if (!file) return null;
  const ext = (file.name.split(".").pop() || "jpg").toLowerCase();
  const path = `${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;
  const { error } = await supabase.storage.from("ad-images").upload(path, file, {
    upsert: false,
    contentType: file.type || "image/jpeg",
  });
  if (error) throw new Error(error.message);
  const { data } = supabase.storage.from("ad-images").getPublicUrl(path);
  return data.publicUrl;
}

// این تابع برای پنل ادمین است و همه‌ی تبلیغات (فعال و غیرفعال) را برمی‌گرداند
export async function fetchAllAdsAdmin() {
  const { data, error } = await supabase
    .from("ads")
    .select("*")
    .order("created_at", { ascending: false });
  if (error) throw new Error(error.message);
  return data || [];
}

export async function createAd(payload) {
  const { data, error } = await supabase.from("ads").insert(payload).select().single();
  if (error) throw new Error(error.message);
  return data;
}

export async function updateAd(id, payload) {
  const { error } = await supabase.from("ads").update(payload).eq("id", id);
  if (error) throw new Error(error.message);
}

export async function deleteAd(id) {
  const { error } = await supabase.from("ads").delete().eq("id", id);
  if (error) throw new Error(error.message);
}

// ثبت تبلیغ توسط کاربران عادی (نه ادمین) — غیرفعال ثبت می‌شه تا پرداخت زرین‌پال تایید بشه
export async function createUserAd(userId, payload) {
  const { data, error } = await supabase
    .from("ads")
    .insert({
      title: payload.title.trim(),
      body: payload.body ? payload.body.trim() : null,
      image_url: payload.imageUrl || null,
      target_url: payload.targetUrl || null,
      button_text: payload.buttonText || "مشاهده",
      created_by: userId,
      active: false,
    })
    .select()
    .single();
  if (error) throw new Error(error.message);

  const paymentUrl = await requestAdPayment(userId, data.id);
  return { ad: data, paymentUrl };
}

export async function requestAdPayment(userId, adId, meta = {}) {
  const { data: sessionData } = await supabase.auth.getSession();
  const token = sessionData?.session?.access_token;
  if (!token) throw new Error("لطفاً دوباره وارد شوید.");

  const res = await fetch("/api/payments/request", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({
      itemType: "ad",
      itemId: adId,
      description: "هزینه ثبت تبلیغ",
      mobile: meta.mobile,
      email: meta.email,
    }),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(json.error || "خطا در اتصال به درگاه پرداخت");
  return json.paymentUrl;
}
