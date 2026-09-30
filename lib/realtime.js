import { supabase } from "./supabaseClient";
import {
  conversationChannelName,
  typingChannelName,
} from "./ids";

export function subscribeToMessages(conversationId, callbacks) {
  const cb = callbacks || {};
  const filterStr = "conversation_id=eq." + conversationId;

  const channel = supabase
    .channel(conversationChannelName(conversationId))
    .on(
      "postgres_changes",
      { event: "INSERT", schema: "public", table: "messages", filter: filterStr },
      function (payload) { if (cb.onInsert) cb.onInsert(payload.new); }
    )
    .on(
      "postgres_changes",
      { event: "UPDATE", schema: "public", table: "messages", filter: filterStr },
      function (payload) { if (cb.onUpdate) cb.onUpdate(payload.new); }
    )
    .on(
      "postgres_changes",
      { event: "DELETE", schema: "public", table: "messages", filter: filterStr },
      function (payload) { if (cb.onDelete) cb.onDelete(payload.old); }
    )
    .subscribe();

  return function () {
    supabase.removeChannel(channel);
  };
}

// نکته‌ی مقیاس‌پذیری: قبلاً این تابع بدون هیچ فیلتری روی رویداد UPDATE جدول
// conversations subscribe می‌کرد — یعنی با هر تغییر در *هر* گفتگویی در کل
// سیستم (مثلاً تغییر نام یک گروه)، این رویداد برای همه‌ی کاربران آنلاین
// پلتفرم (حتی اعضای آن گفتگو نبودند) پخش می‌شد و باعث یک refresh کامل در
// سمت هرکدام می‌شد. با تعداد کاربر بالا این باعث فشار سنگین روی دیتابیس و
// شبکه می‌شود. اکنون این listener فقط با فهرست شناسه‌ی گفتگوهای خودِ کاربر
// فیلتر می‌شود (باید هر بار که این فهرست تغییر کرد، دوباره subscribe شود).
export function subscribeToUserConversations(userId, conversationIds, callbacks) {
  const cb = callbacks || {};
  const memberFilterStr = "user_id=eq." + userId;
  const ids = (conversationIds || []).filter(Boolean);

  const channel = supabase.channel("user-conversations:" + userId);

  channel.on(
    "postgres_changes",
    { event: "*", schema: "public", table: "conversation_members", filter: memberFilterStr },
    function () { if (cb.onChange) cb.onChange(); }
  );

  if (ids.length > 0) {
    channel.on(
      "postgres_changes",
      { event: "UPDATE", schema: "public", table: "conversations", filter: `id=in.(${ids.join(",")})` },
      function () { if (cb.onChange) cb.onChange(); }
    );
  }

  channel.subscribe();

  return function () {
    supabase.removeChannel(channel);
  };
}

export function subscribeToTyping(conversationId, callbacks) {
  const cb = callbacks || {};
  const channel = supabase
    .channel(typingChannelName(conversationId))
    .on("broadcast", { event: "typing" }, function (payload) {
      if (cb.onTyping) cb.onTyping(payload.payload);
    })
    .subscribe();

  return {
    send: function (data) {
      channel.send({ type: "broadcast", event: "typing", payload: data });
    },
    unsubscribe: function () {
      supabase.removeChannel(channel);
    },
  };
}

// نکته‌ی مقیاس‌پذیری: نسخه‌ی قبلی این تابع همه‌ی کاربران پلتفرم را روی یک
// کانال presence سراسری (presence:engix) جمع می‌کرد. در آن مدل، وضعیت کامل
// "چه کسانی الان آنلاین‌اند" روی هر sync برای *همه*‌ی کلاینت‌های متصل (حتی
// کسانی که اصلاً با هم گفتگو ندارند) کامل ارسال می‌شد و هر ورود/خروج یک
// کاربر هم به همه broadcast می‌شد؛ با هزاران کاربر همزمان، این مدل ترافیک و
// پردازش سمت کلاینت را به‌شدت بالا می‌برد (فن‌اوت O(n) در هر رویداد).
// اکنون به‌جای کانال سراسری، وضعیت آنلاین/آخرین بازدید فقط در پروفایل کاربر
// (ستون‌های is_online / last_seen) نگه‌داری و به‌صورت دوره‌ای (poll) برای
// همان کاربرانی که واقعاً لازم است (مثلاً اعضای گفتگوی باز) خوانده می‌شود.
// این تابع همچنان برای سازگاری نگه داشته شده اما دیگر جایی صدا زده نمی‌شود.
export function subscribeToPresence() {
  return function () {};
}
