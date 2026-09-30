import { supabase } from "../lib/supabaseClient";

export async function setUserOnline(userId) {
  const { error } = await supabase
    .from("profiles")
    .update({ is_online: true, last_seen: new Date().toISOString() })
    .eq("id", userId);
  if (error) throw new Error(error.message);
}

export async function setUserOffline(userId) {
  const { error } = await supabase
    .from("profiles")
    .update({ is_online: false, last_seen: new Date().toISOString() })
    .eq("id", userId);
  if (error) throw new Error(error.message);
}

export async function fetchPresenceForUsers(userIds) {
  const ids = userIds || [];
  const unique = [...new Set(ids.filter(Boolean))];
  if (unique.length === 0) return {};

  const { data, error } = await supabase
    .from("profiles")
    .select("id, is_online, last_seen")
    .in("id", unique);
  if (error) throw new Error(error.message);

  const map = {};
  (data || []).forEach(function (p) {
    map[p.id] = { is_online: p.is_online, last_seen: p.last_seen };
  });
  return map;
}

export function formatLastSeen(lastSeenIso) {
  if (!lastSeenIso) return "نامشخص";
  const diffMs = Date.now() - new Date(lastSeenIso).getTime();
  const diffMin = Math.floor(diffMs / 60000);

  if (diffMin < 1) return "همین الان";
  if (diffMin < 60) return diffMin + " دقیقه پیش";
  const diffHours = Math.floor(diffMin / 60);
  if (diffHours < 24) return diffHours + " ساعت پیش";
  const diffDays = Math.floor(diffHours / 24);
  if (diffDays < 7) return diffDays + " روز پیش";
  return new Date(lastSeenIso).toLocaleDateString("fa-IR");
}
