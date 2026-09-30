"use client";
import { useEffect, useState, useCallback, useMemo, useRef } from "react";
import { fetchUserConversations, setConversationPref } from "../services/messengerService";
import { fetchProfilesMap } from "../lib/messengerUtils";
import { subscribeToUserConversations } from "../lib/realtime";
import { supabase } from "../lib/supabaseClient";

function cacheKey(userId) { return "engix_chats_cache_" + userId; }

function readCache(userId) {
  try {
    const raw = localStorage.getItem(cacheKey(userId));
    return raw ? JSON.parse(raw) : null;
  } catch (e) {
    return null;
  }
}

function writeCache(userId, chats) {
  try {
    localStorage.setItem(cacheKey(userId), JSON.stringify(chats));
  } catch (e) {
    // فضای ذخیره‌سازی پر است یا در دسترس نیست — نادیده گرفته می‌شود
  }
}

export function useChats(userId) {
  const [rawChats, setRawChats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const hydratedFromCacheRef = useRef(false);
  const hasDataRef = useRef(false);

  // در همان اولین رندر، اگر نسخه‌ی ذخیره‌شده‌ای از قبل روی گوشی هست، فوری نشانش بده
  // (حتی پیش از اینکه پاسخ سرور برسد، یا حتی اگر اصلاً اینترنت نباشد)
  useEffect(() => {
    if (!userId || hydratedFromCacheRef.current) return;
    hydratedFromCacheRef.current = true;
    const cached = readCache(userId);
    if (cached) {
      setRawChats(cached);
      hasDataRef.current = true;
      setLoading(false);
    }
  }, [userId]);

  const refresh = useCallback(async () => {
    if (!userId) return;
    try {
      const conversations = await fetchUserConversations(userId);

      const { data: myMemberships } = await supabase
        .from("conversation_members")
        .select("conversation_id, is_hidden")
        .eq("user_id", userId);
      const hiddenIds = new Set(
        (myMemberships || []).filter((m) => m.is_hidden).map((m) => m.conversation_id)
      );
      const visibleConversations = conversations.filter((c) => !hiddenIds.has(c.id));

      const directIds = visibleConversations.filter((c) => c.type === "direct").map((c) => c.id);

      let otherByConversation = {};
      if (directIds.length > 0) {
        const { data: allMembers } = await supabase
          .from("conversation_members")
          .select("conversation_id, user_id")
          .in("conversation_id", directIds);
        (allMembers || []).forEach((m) => {
          if (m.user_id !== userId) otherByConversation[m.conversation_id] = m.user_id;
        });
      }

      visibleConversations.forEach((c) => {
        if (c.type === "direct") c._otherUserId = otherByConversation[c.id] || null;
      });

      const directOtherIds = Object.values(otherByConversation).filter(Boolean);
      const profilesMap = await fetchProfilesMap(directOtherIds);

      const resolved = visibleConversations.map((c) => {
        if (c.type === "direct") {
          const other = profilesMap[c._otherUserId];
          return {
            ...c,
            displayName: other ? other.name : "کاربر حذف‌شده",
            displayAvatar: other ? other.avatar_url : null,
          };
        }
        return { ...c, displayName: c.name || "بدون نام", displayAvatar: c.avatar_url };
      });

      setRawChats(resolved);
      hasDataRef.current = true;
      writeCache(userId, resolved);
      setError(null);
    } catch (e) {
      // آفلاین یا خطای شبکه: اگر قبلاً نسخه‌ی کش‌شده نشان داده شده، همان بماند
      // (پیام خطا فقط وقتی نشان داده می‌شود که اصلاً داده‌ای برای نمایش نیست)
      if (!hasDataRef.current) setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [userId]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  // فقط با شناسه‌های گفتگوهای خودِ کاربر subscribe می‌کنیم (نه کل جدول
  // conversations) تا رویدادهای گفتگوهای دیگران را دریافت نکنیم. هر بار که
  // فهرست گفتگوهای کاربر عوض شود (عضو گفتگوی جدیدی شود/گفتگویی حذف شود)
  // دوباره subscribe می‌شود.
  const conversationIdsKey = useMemo(
    () => (rawChats || []).map((c) => c.id).sort().join(","),
    [rawChats]
  );

  useEffect(() => {
    if (!userId) return;
    const ids = conversationIdsKey ? conversationIdsKey.split(",") : [];
    const unsubscribe = subscribeToUserConversations(userId, ids, { onChange: refresh });
    return unsubscribe;
  }, [userId, conversationIdsKey, refresh]);

  const { pinned, active, archived } = useMemo(() => {
    const list = rawChats || [];
    const sorted = [...list].sort(
      (a, b) => new Date(b.created_at) - new Date(a.created_at)
    );
    return {
      pinned: sorted.filter((c) => c.is_pinned && !c.is_archived),
      active: sorted.filter((c) => !c.is_pinned && !c.is_archived),
      archived: sorted.filter((c) => c.is_archived),
    };
  }, [rawChats]);

  const togglePin = useCallback(
    async (conversationId, current) => {
      await setConversationPref(conversationId, userId, { is_pinned: !current });
      refresh();
    },
    [userId, refresh]
  );

  const toggleMute = useCallback(
    async (conversationId, current) => {
      await setConversationPref(conversationId, userId, { is_muted: !current });
      refresh();
    },
    [userId, refresh]
  );

  const toggleArchive = useCallback(
    async (conversationId, current) => {
      await setConversationPref(conversationId, userId, { is_archived: !current });
      refresh();
    },
    [userId, refresh]
  );

  return {
    chats: rawChats || [],
    pinned,
    active,
    archived,
    loading,
    error,
    refresh,
    togglePin,
    toggleMute,
    toggleArchive,
  };
}
