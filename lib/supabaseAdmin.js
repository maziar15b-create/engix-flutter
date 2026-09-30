import { createClient } from "@supabase/supabase-js";

// ⚠️ فقط سمت سرور استفاده شود (Route Handlers / API). این فایل هرگز
// نباید در کامپوننت‌های "use client" ایمپورت شود، چون کلید سرویس‌رول
// دسترسی کامل به دیتابیس دارد و RLS را دور می‌زند.

let adminClient = null;

export function getSupabaseAdmin() {
  if (adminClient) return adminClient;

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceKey) {
    throw new Error(
      "SUPABASE_SERVICE_ROLE_KEY تنظیم نشده — این متغیر باید فقط در تنظیمات سرور (Vercel Environment Variables) اضافه شود، نه در .env.local عمومی کلاینت."
    );
  }

  adminClient = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return adminClient;
}
