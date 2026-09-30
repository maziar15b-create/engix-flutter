import { supabase } from "./supabaseClient";

export async function saveFcmToken(userId, token) {
  if (!userId || !token) return;
  const { error } = await supabase
    .from("profiles")
    .update({ fcm_token: token })
    .eq("id", userId);
  if (error) {
    console.error("saveFcmToken failed:", error.message);
  }
}
