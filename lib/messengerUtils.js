import { supabase } from "./supabaseClient";

export function normalizePhone(p) {
  return (p || "").replace(/\D/g, "").slice(-10);
}

export async function fetchProfilesMap(ids) {
  const unique = [...new Set(ids.filter(Boolean))];
  if (unique.length === 0) return {};
  const { data } = await supabase.from("profiles").select("id, code, name, avatar_url").in("id", unique);
  const map = {};
  (data || []).forEach((p) => { map[p.id] = p; });
  return map;
}
