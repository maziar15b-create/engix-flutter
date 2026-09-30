import { supabase } from "../lib/supabaseClient";

/**
 * Group/channel membership management: adding/removing members,
 * promoting/demoting admins, leaving a conversation, and fetching
 * the member list with profile info attached.
 */

/**
 * Fetches all members of a conversation joined with their profile info.
 * Returns rows shaped like: { user_id, role, profiles: { id, name, code, avatar_url } }
 */
export async function fetchConversationMembers(conversationId) {
  // نکته: قبلاً اینجا با select تو در تو (embedded) سعی می‌شد پروفایل هر
  // عضو مستقیم از طریق رابطه‌ی خودکار PostgREST گرفته بشه، اما به‌خاطر یک
  // مشکل در schema cache دیتابیس، این رابطه شناسایی نمی‌شد و کل کوئری با
  // خطا شکست می‌خورد (حتی با وجود foreign key واقعی در دیتابیس). برای اینکه
  // دیگه به این رابطه‌ی PostgREST وابسته نباشیم، اینجا با دو کوئری ساده و
  // جدا (بدون embedded join) کار می‌کنیم و خودمان دستی به‌هم وصل می‌کنیم.
  const { data: memberRows, error } = await supabase
    .from("conversation_members")
    .select("user_id, role, joined_at")
    .eq("conversation_id", conversationId)
    .order("joined_at", { ascending: true });
  if (error) throw new Error(error.message);
  if (!memberRows || memberRows.length === 0) return [];

  const userIds = memberRows.map(function (m) { return m.user_id; });
  const { data: profileRows, error: profErr } = await supabase
    .from("profiles")
    .select("id, name, code, avatar_url")
    .in("id", userIds);
  if (profErr) throw new Error(profErr.message);

  const profileById = {};
  (profileRows || []).forEach(function (p) { profileById[p.id] = p; });

  return memberRows.map(function (m) {
    return {
      user_id: m.user_id,
      role: m.role,
      joined_at: m.joined_at,
      profiles: profileById[m.user_id] || null,
    };
  });
}

/**
 * Returns the current user's role in a conversation ("owner" | "admin" | "member" | null).
 */
export async function getMemberRole(conversationId, userId) {
  const { data, error } = await supabase
    .from("conversation_members")
    .select("role")
    .eq("conversation_id", conversationId)
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data ? data.role : null;
}

/**
 * Adds one or more users to a group/channel. Only meant to be called
 * after the caller has verified (via getMemberRole) that the acting
 * user is owner/admin — RLS enforces this server-side as well.
 */
export async function addMembers(conversationId, userIds = []) {
  const rows = userIds.map((userId) => ({
    conversation_id: conversationId,
    user_id: userId,
    role: "member",
  }));
  if (rows.length === 0) return;
  const { error } = await supabase.from("conversation_members").insert(rows);
  if (error) throw new Error(error.message);
}

/**
 * Removes a member from a group/channel (kick).
 */
export async function removeMember(conversationId, userId) {
  const { error } = await supabase
    .from("conversation_members")
    .delete()
    .eq("conversation_id", conversationId)
    .eq("user_id", userId);
  if (error) throw new Error(error.message);
}

/**
 * Promotes a member to admin.
 */
export async function promoteToAdmin(conversationId, userId) {
  const { error } = await supabase
    .from("conversation_members")
    .update({ role: "admin" })
    .eq("conversation_id", conversationId)
    .eq("user_id", userId);
  if (error) throw new Error(error.message);
}

/**
 * Demotes an admin back to a regular member. Owners cannot be demoted
 * via this function (ownership transfer would need a dedicated flow).
 */
export async function demoteToMember(conversationId, userId) {
  const { error } = await supabase
    .from("conversation_members")
    .update({ role: "member" })
    .eq("conversation_id", conversationId)
    .eq("user_id", userId)
    .neq("role", "owner");
  if (error) throw new Error(error.message);
}

/**
 * Current user leaves a group/channel. If they are the owner and other
 * members remain, ownership should be transferred first by the caller
 * (e.g. prompting them to pick a new owner) — this function refuses
 * to leave an owner with no successor to keep data consistent.
 */
export async function leaveConversation(conversationId, userId) {
  const { data: members, error: fetchError } = await supabase
    .from("conversation_members")
    .select("user_id, role")
    .eq("conversation_id", conversationId);
  if (fetchError) throw new Error(fetchError.message);

  const me = (members || []).find((m) => m.user_id === userId);
  const others = (members || []).filter((m) => m.user_id !== userId);

  if (me?.role === "owner" && others.length > 0) {
    throw new Error("قبل از خروج، باید مالکیت گروه را به عضو دیگری منتقل کنید.");
  }

  const { error } = await supabase
    .from("conversation_members")
    .delete()
    .eq("conversation_id", conversationId)
    .eq("user_id", userId);
  if (error) throw new Error(error.message);
}/**
 * Transfers ownership of a group/channel to another existing member,
 * demoting the current owner to admin.
 */
export async function transferOwnership(conversationId, currentOwnerId, newOwnerId) {
  const { error: promoteError } = await supabase
    .from("conversation_members")
    .update({ role: "owner" })
    .eq("conversation_id", conversationId)
    .eq("user_id", newOwnerId);
  if (promoteError) throw new Error(promoteError.message);

  const { error: demoteError } = await supabase
    .from("conversation_members")
    .update({ role: "admin" })
    .eq("conversation_id", conversationId)
    .eq("user_id", currentOwnerId);
  if (demoteError) throw new Error(demoteError.message);
}

/**
 * Updates group/channel metadata (name, avatar_url). Only owner/admin
 * should be allowed to call this (enforced by caller + RLS).
 */
export async function updateConversationInfo(conversationId, updates) {
  const { error } = await supabase
    .from("conversations")
    .update(updates) // e.g. { name: "..." } or { avatar_url: "..." }
    .eq("id", conversationId);
  if (error) throw new Error(error.message);
}
