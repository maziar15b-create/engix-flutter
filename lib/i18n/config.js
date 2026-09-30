// پیکربندی زبان‌های EngiX
// برای افزودن زبان جدید (مثلاً عربی/ترکی که فعلاً غیرفعال‌اند):
// 1) یک فایل دیکشنری جدید در lib/i18n/dictionaries بسازید (کپی از en.js)
// 2) آن را در دیکشنری‌های پایین import و در LOCALES اضافه کنید

export const LOCALES = [
  { code: "fa", label: "فارسی", nativeLabel: "فارسی", dir: "rtl" },
  { code: "ckb", label: "کوردی سۆرانی", nativeLabel: "کوردی", dir: "rtl" },
  { code: "en", label: "English", nativeLabel: "English", dir: "ltr" },
  // زبان‌های آماده برای فعال‌سازی بعدی (دیکشنری‌شان ساخته نشده):
  // { code: "ar", label: "العربية", nativeLabel: "العربية", dir: "rtl" },
  // { code: "tr", label: "Türkçe", nativeLabel: "Türkçe", dir: "ltr" },
];

export const DEFAULT_LOCALE = "fa";
export const STORAGE_KEY = "engix_locale";

export function getLocaleMeta(code) {
  return LOCALES.find((l) => l.code === code) || LOCALES.find((l) => l.code === DEFAULT_LOCALE);
}

export function isRTL(code) {
  return getLocaleMeta(code).dir === "rtl";
}
