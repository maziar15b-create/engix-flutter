"use client";
import { createContext, useContext, useEffect, useMemo, useState, useCallback } from "react";
import { LOCALES, DEFAULT_LOCALE, STORAGE_KEY, getLocaleMeta, isRTL } from "./config";

import fa from "./dictionaries/fa";
import ckb from "./dictionaries/ckb";
import en from "./dictionaries/en";

const DICTIONARIES = { fa, ckb, en };

const LanguageContext = createContext(null);

function readValue(dict, key) {
  return key.split(".").reduce((acc, part) => (acc && typeof acc === "object" ? acc[part] : undefined), dict);
}

function interpolate(str, vars) {
  if (!vars) return str;
  return Object.keys(vars).reduce((acc, k) => acc.replaceAll(`{${k}}`, vars[k]), str);
}

export function LanguageProvider({ children }) {
  const [locale, setLocaleState] = useState(DEFAULT_LOCALE);
  const [ready, setReady] = useState(false);

  // خواندن زبان ذخیره‌شده از localStorage در اولین رندر سمت کلاینت
  useEffect(() => {
    try {
      const saved = window.localStorage.getItem(STORAGE_KEY);
      if (saved && DICTIONARIES[saved]) {
        setLocaleState(saved);
      }
    } catch {
      // localStorage ممکنه در بعضی WebViewها در دسترس نباشه — نادیده می‌گیریم
    }
    setReady(true);
  }, []);

  // اعمال dir/lang روی <html> هر بار زبان عوض میشه
  useEffect(() => {
    const meta = getLocaleMeta(locale);
    document.documentElement.lang = locale;
    document.documentElement.dir = meta.dir;
  }, [locale]);

  const setLocale = useCallback((code) => {
    if (!DICTIONARIES[code]) return;
    setLocaleState(code);
    try {
      window.localStorage.setItem(STORAGE_KEY, code);
    } catch {
      // در دسترس نبودن localStorage مشکلی ایجاد نمی‌کند، فقط پایدار نمی‌ماند
    }
  }, []);

  const t = useCallback(
    (key, vars) => {
      const dict = DICTIONARIES[locale] || DICTIONARIES[DEFAULT_LOCALE];
      const value = readValue(dict, key) ?? readValue(DICTIONARIES[DEFAULT_LOCALE], key) ?? key;
      return typeof value === "string" ? interpolate(value, vars) : value;
    },
    [locale]
  );

  const value = useMemo(
    () => ({
      locale,
      setLocale,
      t,
      dir: getLocaleMeta(locale).dir,
      isRTL: isRTL(locale),
      locales: LOCALES,
      ready,
    }),
    [locale, setLocale, t, ready]
  );

  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
}

export function useLanguage() {
  const ctx = useContext(LanguageContext);
  if (!ctx) throw new Error("useLanguage must be used inside <LanguageProvider>");
  return ctx;
}

// میانبر رایج: فقط تابع ترجمه
export function useTranslation() {
  const { t, locale, dir, isRTL } = useLanguage();
  return { t, locale, dir, isRTL };
}
