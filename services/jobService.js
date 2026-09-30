import { supabase } from "../lib/supabaseClient";
import { fetchProfilesMap } from "../lib/messengerUtils";

export async function fetchListings(filterType, limit) {
  let query = supabase
    .from("job_listings")
    .select("*")
    .eq("status", "active")
    .order("created_at", { ascending: false })
    .limit(limit || 20);
  if (filterType && filterType !== "all") query = query.eq("listing_type", filterType);

  const { data, error } = await query;
  if (error) throw new Error(error.message);

  const rows = data || [];
  const profilesMap = await fetchProfilesMap(rows.map((r) => r.author_id));
  return rows.map((r) => ({
    ...r,
    authorName: profilesMap[r.author_id] ? profilesMap[r.author_id].name : "—",
  }));
}

export async function fetchMyListings(userId) {
  const { data, error } = await supabase
    .from("job_listings")
    .select("*")
    .eq("author_id", userId)
    .order("created_at", { ascending: false });
  if (error) throw new Error(error.message);
  return data || [];
}

// پرداخت فعلاً کاملاً حذف شده — آگهی مستقیم بعد از ثبت "active" می‌شود
export async function createListing(authorId, payload) {
  const { data, error } = await supabase
    .from("job_listings")
    .insert({
      author_id: authorId,
      listing_type: payload.listingType,
      title: payload.title.trim(),
      description: payload.description ? payload.description.trim() : null,
      location: payload.location ? payload.location.trim() : null,
      role: payload.role ? payload.role.trim() : null,
      salary: payload.salary ? payload.salary.trim() : null,
      work_type: payload.workType || null,
      phone: payload.phone ? payload.phone.trim() : null,
      status: "active",
    })
    .select()
    .single();
  if (error) throw new Error(error.message);

  return { listing: data };
}

export async function closeListing(id) {
  const { error } = await supabase.from("job_listings").update({ status: "closed" }).eq("id", id);
  if (error) throw new Error(error.message);
}

export async function deleteListing(id) {
  const { error } = await supabase.from("job_listings").delete().eq("id", id);
  if (error) throw new Error(error.message);
}
