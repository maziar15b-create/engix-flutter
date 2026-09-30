import { supabase } from "../lib/supabaseClient";

export async function clearConversationForMe(userId, conversationId) {
  const { error } = await supabase
    .from("conversation_members")
    .update({ cleared_at: new Date().toISOString() })
    .eq("conversation_id", conversationId)
    .eq("user_id", userId);
  if (error) throw new Error(error.message);
}

export async function hideConversationForMe(userId, conversationId) {
  const { error } = await supabase
    .from("conversation_members")
    .update({ is_hidden: true })
    .eq("conversation_id", conversationId)
    .eq("user_id", userId);
  if (error) throw new Error(error.message);
}

export async function deleteConversationCompletely(conversationId) {
  const { error } = await supabase.from("conversations").delete().eq("id", conversationId);
  if (error) throw new Error(error.message);
}
