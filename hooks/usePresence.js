"use client";
import { useEffect, useState, useCallback, useRef } from "react";
import { setUserOnline, setUserOffline, fetchPresenceForUsers } from "../services/presenceService";

// اگر آخرین heartbeat کاربر بیشتر از این مدت قبل بوده، حتی اگر ستون is_online
// همچنان true باشد (مثلاً به‌خاطر کرش مرورگر که رویداد beforeunload را از
// دست داده)، او را آفلاین در نظر می‌گیریم.
const STALE_AFTER_MS = 90 * 1000;
const HEARTBEAT_INTERVAL_MS = 45 * 1000;
const POLL_INTERVAL_MS = 20 * 1000;

/**
 * Tracks the current user's own online presence (persists heartbeat to the
 * profiles table) and exposes a way to look up live-ish online state for a
 * set of other users (e.g. conversation members) via periodic polling of
 * the persisted state.
 *
 * این نسخه دیگر از یک کانال presence سراسری (broadcast به همه‌ی کاربران
 * پلتفرم) استفاده نمی‌کند تا با تعداد کاربر بالا فشار غیرضروری روی شبکه/سرور
 * ایجاد نشود؛ به‌جایش وضعیت در دیتابیس نگه داشته و برای کاربران مدنظر با
 * فاصله‌ی کوتاه poll می‌شود.
 */
export function usePresence(currentUserId) {
  const [persistedPresence, setPersistedPresence] = useState({});
  const trackedIdsRef = useRef([]);

  // Heartbeat: به‌صورت دوره‌ای وضعیت آنلاین بودن خودمان را در دیتابیس تازه نگه می‌داریم
  useEffect(() => {
    if (!currentUserId) return;

    setUserOnline(currentUserId).catch((e) => console.error("setUserOnline failed:", e.message));

    const heartbeat = setInterval(() => {
      if (document.visibilityState === "hidden") return;
      setUserOnline(currentUserId).catch(() => {});
    }, HEARTBEAT_INTERVAL_MS);

    const handleVisibility = () => {
      if (document.visibilityState === "hidden") {
        setUserOffline(currentUserId).catch(() => {});
      } else {
        setUserOnline(currentUserId).catch(() => {});
      }
    };
    const handleBeforeUnload = () => {
      setUserOffline(currentUserId).catch(() => {});
    };

    document.addEventListener("visibilitychange", handleVisibility);
    window.addEventListener("beforeunload", handleBeforeUnload);

    return () => {
      clearInterval(heartbeat);
      document.removeEventListener("visibilitychange", handleVisibility);
      window.removeEventListener("beforeunload", handleBeforeUnload);
      setUserOffline(currentUserId).catch(() => {});
    };
  }, [currentUserId]);

  /**
   * Loads persisted last_seen/is_online info for a batch of user ids
   * (e.g. members of the currently open conversation). Call this from
   * ChatHeader / MembersPanel when they mount with a list of ids.
   * The same ids are then polled periodically until the caller requests
   * a different set.
   */
  const loadPresenceFor = useCallback(async (userIds) => {
    const ids = [...new Set((userIds || []).filter(Boolean))];
    trackedIdsRef.current = ids;
    if (ids.length === 0) return;
    try {
      const map = await fetchPresenceForUsers(ids);
      setPersistedPresence((prev) => ({ ...prev, ...map }));
    } catch (e) {
      console.error("loadPresenceFor failed:", e.message);
    }
  }, []);

  // Poll دوره‌ای برای آخرین لیست شناسه‌های درخواست‌شده
  useEffect(() => {
    const interval = setInterval(() => {
      const ids = trackedIdsRef.current;
      if (!ids || ids.length === 0) return;
      fetchPresenceForUsers(ids)
        .then((map) => setPersistedPresence((prev) => ({ ...prev, ...map })))
        .catch(() => {});
    }, POLL_INTERVAL_MS);
    return () => clearInterval(interval);
  }, []);

  /**
   * "Is this user online right now?" — بر اساس وضعیت پایدارشده در دیتابیس،
   * با در نظر گرفتن staleness (اگر آخرین heartbeat خیلی قدیمی باشد، آفلاین
   * فرض می‌شود حتی اگر پرچم is_online هنوز true مانده باشد).
   */
  const isOnline = useCallback(
    (userId) => {
      const entry = persistedPresence[userId];
      if (!entry || !entry.is_online) return false;
      if (!entry.last_seen) return true;
      const age = Date.now() - new Date(entry.last_seen).getTime();
      return age < STALE_AFTER_MS;
    },
    [persistedPresence]
  );

  const getLastSeen = useCallback(
    (userId) => persistedPresence[userId]?.last_seen || null,
    [persistedPresence]
  );

  return {
    isOnline,
    getLastSeen,
    loadPresenceFor,
  };
}
