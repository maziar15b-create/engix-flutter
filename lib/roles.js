import { supabase } from "./supabaseClient";

// همه‌ی نقش‌های سیستمی موجود (از دیتابیس، نه هاردکد)
export async function fetchAllRoles() {
  const { data, error } = await supabase
    .from("roles")
    .select("*")
    .eq("is_active", true)
    .order("sort_order", { ascending: true });
  if (error) throw error;
  return data || [];
}

// نقش‌هایی که کاربر فعال کرده
export async function fetchMyRoles(userId) {
  const { data, error } = await supabase
    .from("user_roles")
    .select("role_id, roles(*)")
    .eq("user_id", userId);
  if (error) throw error;
  return (data || []).map((r) => r.roles).filter(Boolean).sort((a, b) => a.sort_order - b.sort_order);
}

export async function addMyRole(userId, roleId) {
  return supabase.from("user_roles").insert({ user_id: userId, role_id: roleId });
}

export async function removeMyRole(userId, roleId) {
  return supabase.from("user_roles").delete().eq("user_id", userId).eq("role_id", roleId);
}

// تغییر نقش فعال — بدون خروج و ورود مجدد
export async function setActiveRole(userId, roleId) {
  return supabase.from("profiles").update({ active_role_id: roleId }).eq("id", userId);
}

export function groupRolesByCategory(roles) {
  const map = {};
  for (const r of roles) {
    if (!map[r.category]) map[r.category] = [];
    map[r.category].push(r);
  }
  return map;
}
