"use client";
import { useEffect, useState, useCallback, useRef } from "react";
import { supabase } from "../lib/supabaseClient";
import {
  fetchMessages,
  sendMessage,
  editMessage,
  deleteMessage,
  markMessagesAsRead,
  fetchReadReceipts,
} from "../services/messengerService";
import { subscribeToMessages } from "../lib/realtime";

function cacheKey(conversationId) { return "engix_messages_cache_" + conversationId; }

function readCache(conversationId) {
  try {
    const raw = localStorage.getItem(cacheKey(conversationId));
    return raw ? JSON.parse(raw) : null;
  } catch (e) {
    return null;
  }
}

function writeCache(conversationId, messages) {
  try {
    // فقط آخرین ۵۰ پیام کش می‌شود — کافی است برای دیدن چند پیام آخر بدون اینترنت،
    // بدون این‌که حافظه‌ی گوشی با تاریخچه‌ی کامل پر شود.
    const trimmed = messages.slice(-50);
    localStorage.setItem(cacheKey(conversationId), JSON.stringify(trimmed));
  } catch (e) {
    // فضای ذخیره‌سازی پر است یا در دسترس نیست — نادیده گرفته می‌شود
  }
}

export function useMessages(conversationId, currentUserId) {
  const [messages, setMessages] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [error, setError] = useState(null);
  const [sending, setSending] = useState(false);
  const [readMessageIds, setReadMessageIds] = useState(new Set());
  const [isOffline, setIsOffline] = useState(false);

  const oldestLoadedRef = useRef(null);
  const clearedAtRef = useRef(null);
  const hasFreshDataRef = useRef(false);

  const loadClearedAt = useCallback(async () => {
    if (!conversationId || !currentUserId) return null;
    const { data } = await supabase
      .from("conversation_members")
      .select("cleared_at")
      .eq("conversation_id", conversationId)
      .eq("user_id", currentUserId)
      .maybeSingle();
    return data ? data.cleared_at : null;
  }, [conversationId, currentUserId]);

  const filterCleared = useCallback((page) => {
    if (!clearedAtRef.current) return page;
    const clearedTime = new Date(clearedAtRef.current).getTime();
    return page.filter(function (m) { return new Date(m.created_at).getTime() > clearedTime; });
  }, []);

  // تیک دوگانه: برای پیام‌هایی که خودم فرستادم، بررسی می‌کند کدام‌ها خوانده شده‌اند
  const refreshReadReceipts = useCallback(async (msgList) => {
    if (!currentUserId) return;
    const ownIds = (msgList || []).filter((m) => m.sender_id === currentUserId).map((m) => m.id);
    if (ownIds.length === 0) return;
    try {
      const readSet = await fetchReadReceipts(ownIds);
      setReadMessageIds((prev) => new Set([...prev, ...readSet]));
    } catch (e) {
      console.error("refreshReadReceipts failed:", e.message);
    }
  }, [currentUserId]);

  // هر بار گفتگو عوض می‌شود، اول از کش محلی (اگر باشد) فوری نمایش بده —
  // حتی پیش از پاسخ سرور یا حتی اگر اصلاً اینترنت نباشد
  useEffect(() => {
    if (!conversationId) return;
    hasFreshDataRef.current = false;
    const cached = readCache(conversationId);
    if (cached && cached.length > 0) {
      setMessages(cached);
      setLoading(false);
      setIsOffline(true); // تا وقتی داده‌ی تازه از سرور نرسیده، این را «احتمالاً قدیمی» علامت می‌زنیم
    } else {
      setMessages([]);
      setLoading(true);
    }
  }, [conversationId]);

  const loadInitial = useCallback(async () => {
    if (!conversationId) return;
    try {
      clearedAtRef.current = await loadClearedAt();
      const page = await fetchMessages(conversationId);
      const filtered = filterCleared(page);
      setMessages(filtered);
      hasFreshDataRef.current = true;
      setIsOffline(false);
      oldestLoadedRef.current = page.length > 0 ? page[0].created_at : null;
      setHasMore(page.length > 0);
      setError(null);
      writeCache(conversationId, filtered);
      refreshReadReceipts(filtered);
    } catch (e) {
      // آفلاین یا خطای شبکه: اگر از کش چیزی نشان داده شده، همان بماند
      // (پیام خطا فقط وقتی نشان داده می‌شود که اصلاً داده‌ای برای نمایش نیست)
      if (!hasFreshDataRef.current && messages.length === 0) setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [conversationId, loadClearedAt, filterCleared, refreshReadReceipts]);

  const loadMore = useCallback(async () => {
    if (!conversationId) return;
    if (loadingMore) return;
    if (!hasMore) return;
    if (!oldestLoadedRef.current) return;

    setLoadingMore(true);
    try {
      const page = await fetchMessages(conversationId, {
        beforeCreatedAt: oldestLoadedRef.current,
      });
      if (page.length === 0) {
        setHasMore(false);
      } else {
        const filtered = filterCleared(page);
        setMessages(function (prev) {
          return filtered.concat(prev);
        });
        oldestLoadedRef.current = page[0].created_at;
        refreshReadReceipts(filtered);
        if (filtered.length === 0) {
          // این صفحه کامل قبل از زمان پاک‌کردن بوده؛ صفحه‌ی قبلی‌تر را هم بررسی کن
          setHasMore(true);
        }
      }
    } catch (e) {
      // بارگذاری بیشتر معمولاً نیاز به اینترنت دارد؛ اگر آفلاین است فقط بی‌صدا رد شو
    } finally {
      setLoadingMore(false);
    }
  }, [conversationId, loadingMore, hasMore, filterCleared, refreshReadReceipts]);

  useEffect(() => {
    loadInitial();
  }, [loadInitial]);

  useEffect(() => {
    if (!conversationId) return;
    const unsubscribe = subscribeToMessages(conversationId, {
      onInsert: (msg) => {
        setMessages(function (prev) {
          const exists = prev.some(function (m) { return m.id === msg.id; });
          if (exists) return prev;
          const next = prev.concat([msg]);
          writeCache(conversationId, next);
          return next;
        });
      },
      onUpdate: (msg) => {
        setMessages(function (prev) {
          const next = prev.map(function (m) {
            return m.id === msg.id ? msg : m;
          });
          writeCache(conversationId, next);
          return next;
        });
      },
      onDelete: (msg) => {
        setMessages(function (prev) {
          const next = prev.filter(function (m) { return m.id !== msg.id; });
          writeCache(conversationId, next);
          return next;
        });
      },
    });
    return unsubscribe;
  }, [conversationId]);

  // اشتراک real-time روی message_reads: وقتی طرف مقابل پیام من را می‌خواند،
  // بلافاصله تیک دوم فعال شود (بدون نیاز به رفرش دستی)
  useEffect(() => {
    if (!conversationId || !currentUserId) return;
    const channel = supabase
      .channel(`message_reads:${conversationId}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "message_reads" },
        (payload) => {
          const messageId = payload.new?.message_id;
          if (!messageId) return;
          setMessages((prev) => {
            if (prev.some((m) => m.id === messageId)) {
              setReadMessageIds((prevRead) => new Set(prevRead).add(messageId));
            }
            return prev;
          });
        }
      )
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [conversationId, currentUserId]);

  const send = useCallback(
    async (params) => {
      if (!conversationId) return;
      if (!currentUserId) return;
      setSending(true);
      try {
        await sendMessage({
          conversationId: conversationId,
          senderId: currentUserId,
          content: params.content,
          attachment: params.attachment,
          replyTo: params.replyTo,
          forwardedFrom: params.forwardedFrom,
        });
        setError(null);

        // ارسال نوتیفیکیشن به بقیه‌ی اعضا — عمداً await نمی‌شود (fire-and-forget)
        // تا اگر کند بود یا خطا داد، ارسال خودِ پیام رو کند یا مختل نکنه.
        supabase.auth.getSession().then(({ data }) => {
          const token = data?.session?.access_token;
          if (!token) return;
          fetch("/api/notifications/send-message-push", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${token}`,
            },
            body: JSON.stringify({
              conversationId,
              senderId: currentUserId,
              text: params.content,
            }),
          }).catch((err) => console.error("push notification trigger failed:", err.message));
        });
      } catch (e) {
        setError(e.message);
        throw e;
      } finally {
        setSending(false);
      }
    },
    [conversationId, currentUserId]
  );

  const edit = useCallback(async (messageId, newContent) => {
    await editMessage(messageId, newContent);
  }, []);

  const remove = useCallback(async (messageId) => {
    await deleteMessage(messageId);
  }, []);

  const markAsRead = useCallback(async () => {
    if (!conversationId) return;
    if (!currentUserId) return;
    if (messages.length === 0) return;
    const last = messages[messages.length - 1];
    try {
      await markMessagesAsRead(conversationId, currentUserId, last.created_at);
    } catch (e) {
      console.error("markMessagesAsRead failed:", e.message);
    }
  }, [conversationId, currentUserId, messages]);

  return {
    messages: messages,
    loading: loading,
    loadingMore: loadingMore,
    hasMore: hasMore,
    error: error,
    sending: sending,
    readMessageIds: readMessageIds,
    isOffline: isOffline,
    loadMore: loadMore,
    send: send,
    edit: edit,
    remove: remove,
    markAsRead: markAsRead,
  };
}
