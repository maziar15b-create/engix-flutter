import { supabase } from "../lib/supabaseClient";
import { fetchProfilesMap } from "../lib/messengerUtils";

async function fetchProfileCards(ids) {
  const unique = [...new Set(ids.filter(Boolean))];
  if (unique.length === 0) return {};
  const { data } = await supabase.from("profiles").select("id, name, code, avatar_url").in("id", unique);
  const map = {};
  (data || []).forEach((p) => { map[p.id] = p; });
  return map;
}

export async function fetchBlockedIds(userId) {
  const { data, error } = await supabase.from("blocks").select("blocked_id").eq("blocker_id", userId);
  if (error) throw new Error(error.message);
  return (data || []).map((b) => b.blocked_id);
}

export async function fetchIsBlocked(blockerId, blockedId) {
  const { data, error } = await supabase.from("blocks").select("blocker_id").eq("blocker_id", blockerId).eq("blocked_id", blockedId).maybeSingle();
  if (error) throw new Error(error.message);
  return !!data;
}

export async function blockUser(blockerId, blockedId) {
  if (blockerId === blockedId) throw new Error("امکان مسدود کردن خودتان وجود ندارد.");
  const { error } = await supabase.from("blocks").insert({ blocker_id: blockerId, blocked_id: blockedId });
  if (error && error.code !== "23505") throw new Error(error.message);
  await supabase.from("follows").delete().eq("follower_id", blockerId).eq("following_id", blockedId);
  await supabase.from("follows").delete().eq("follower_id", blockedId).eq("following_id", blockerId);
}

export async function unblockUser(blockerId, blockedId) {
  const { error } = await supabase.from("blocks").delete().eq("blocker_id", blockerId).eq("blocked_id", blockedId);
  if (error) throw new Error(error.message);
}

export async function fetchFollowersList(userId) {
  const { data, error } = await supabase.from("follows").select("follower_id").eq("following_id", userId);
  if (error) throw new Error(error.message);
  const ids = (data || []).map((f) => f.follower_id);
  const map = await fetchProfileCards(ids);
  return ids.map((id) => map[id]).filter(Boolean);
}

export async function fetchFollowingList(userId) {
  const { data, error } = await supabase.from("follows").select("following_id").eq("follower_id", userId);
  if (error) throw new Error(error.message);
  const ids = (data || []).map((f) => f.following_id);
  const map = await fetchProfileCards(ids);
  return ids.map((id) => map[id]).filter(Boolean);
}

// همه‌ی کاربرانی که viewer دنبال می‌کند، یکجا (برای جلوگیری از N+1 روی دکمه‌های دنبال‌کردن در فید)
async function fetchFollowingSet(viewerId) {
  if (!viewerId) return new Set();
  const { data, error } = await supabase.from("follows").select("following_id").eq("follower_id", viewerId);
  if (error) throw new Error(error.message);
  return new Set((data || []).map((f) => f.following_id));
}

async function attachMeta(posts, viewerId) {
  if (posts.length === 0) return [];
  const postIds = posts.map((p) => p.id);
  const authorIds = posts.map((p) => p.author_id);

  const [{ data: likeRows }, { data: commentRows }, { data: savedRows }, profilesMap, followingSet] = await Promise.all([
    supabase.from("post_likes").select("post_id, user_id").in("post_id", postIds),
    supabase.from("post_comments").select("post_id").in("post_id", postIds),
    viewerId
      ? supabase.from("saved_posts").select("post_id").eq("user_id", viewerId).in("post_id", postIds)
      : Promise.resolve({ data: [] }),
    fetchProfilesMap(authorIds),
    fetchFollowingSet(viewerId),
  ]);

  const likeCountByPost = {};
  const likedByViewer = {};
  (likeRows || []).forEach((l) => {
    likeCountByPost[l.post_id] = (likeCountByPost[l.post_id] || 0) + 1;
    if (l.user_id === viewerId) likedByViewer[l.post_id] = true;
  });

  const commentCountByPost = {};
  (commentRows || []).forEach((c) => {
    commentCountByPost[c.post_id] = (commentCountByPost[c.post_id] || 0) + 1;
  });

  const savedSet = new Set((savedRows || []).map((s) => s.post_id));

  return posts.map((p) => ({
    ...p,
    text: p.content,
    image_url: p.media_url,
    media: Array.isArray(p.media) && p.media.length ? p.media : (p.media_url ? [{ type: "image", url: p.media_url }] : []),
    authorName: profilesMap[p.author_id] ? profilesMap[p.author_id].name : "—",
    authorCode: profilesMap[p.author_id] ? profilesMap[p.author_id].code : null,
    authorAvatar: profilesMap[p.author_id] ? profilesMap[p.author_id].avatar_url : null,
    likeCount: likeCountByPost[p.id] || 0,
    likedByMe: !!likedByViewer[p.id],
    commentCount: commentCountByPost[p.id] || 0,
    savedByMe: savedSet.has(p.id),
    isFollowingAuthor: followingSet.has(p.author_id),
  }));
}

export async function fetchFeed(viewerId, limit, filter = "following") {
  const blockedIds = await fetchBlockedIds(viewerId);
  let authorFilterIds = null;

  if (filter === "following") {
    const { data: followingRows, error: followErr } = await supabase
      .from("follows")
      .select("following_id")
      .eq("follower_id", viewerId);
    if (followErr) throw new Error(followErr.message);
    authorFilterIds = (followingRows || []).map((f) => f.following_id);
    authorFilterIds.push(viewerId);
    if (authorFilterIds.length === 0) return [];
  }

  let query = supabase
    .from("posts")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(limit || 50);
  if (authorFilterIds) query = query.in("author_id", authorFilterIds);
  if (blockedIds.length > 0) query = query.not("author_id", "in", `(${blockedIds.join(",")})`);

  const { data: postsData, error } = await query;
  if (error) throw new Error(error.message);

  return attachMeta(postsData || [], viewerId);
}

export async function fetchExploreFeed(viewerId, limit) {
  const blockedIds = await fetchBlockedIds(viewerId);
  let query = supabase
    .from("posts")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(limit || 50);
  if (blockedIds.length > 0) query = query.not("author_id", "in", `(${blockedIds.join(",")})`);

  const { data, error } = await query;
  if (error) throw new Error(error.message);
  return attachMeta(data || [], viewerId);
}

export async function fetchUserPosts(authorId, viewerId) {
  const { data, error } = await supabase
    .from("posts")
    .select("*")
    .eq("author_id", authorId)
    .order("created_at", { ascending: false });
  if (error) throw new Error(error.message);
  return attachMeta(data || [], viewerId);
}

export async function fetchSavedPosts(viewerId) {
  const { data: savedRows, error } = await supabase
    .from("saved_posts")
    .select("post_id, created_at")
    .eq("user_id", viewerId)
    .order("created_at", { ascending: false });
  if (error) throw new Error(error.message);
  const postIds = (savedRows || []).map((s) => s.post_id);
  if (postIds.length === 0) return [];
  const { data: postsData, error: postsErr } = await supabase.from("posts").select("*").in("id", postIds);
  if (postsErr) throw new Error(postsErr.message);
  const withMeta = await attachMeta(postsData || [], viewerId);
  const order = {};
  postIds.forEach((id, i) => { order[id] = i; });
  return withMeta.sort((a, b) => order[a.id] - order[b.id]);
}

export async function savePost(userId, postId) {
  const { error } = await supabase.from("saved_posts").insert({ user_id: userId, post_id: postId });
  if (error && error.code !== "23505") throw new Error(error.message);
}

export async function unsavePost(userId, postId) {
  const { error } = await supabase.from("saved_posts").delete().eq("user_id", userId).eq("post_id", postId);
  if (error) throw new Error(error.message);
}

export async function fetchUserProfileCard(userId) {
  const { data, error } = await supabase
    .from("profiles")
    .select("id, name, code, avatar_url")
    .eq("id", userId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data;
}

export async function createPost(authorId, text, mediaItems) {
  // mediaItems: آرایه‌ای از {type: "image"|"video", url} — می‌تواند خالی باشد.
  const trimmed = (text || "").trim();
  const items = Array.isArray(mediaItems) ? mediaItems : (mediaItems ? [{ type: "image", url: mediaItems }] : []);
  if (!trimmed && items.length === 0) throw new Error("متن یا رسانه‌ی پست خالی است.");
  const firstImage = items.find((m) => m.type === "image");
  const { data, error } = await supabase
    .from("posts")
    .insert({
      author_id: authorId,
      type: "post",
      content: trimmed,
      media_url: firstImage ? firstImage.url : null, // برای سازگاری با نسخه‌های قدیمی
      media: items,
    })
    .select()
    .single();
  if (error) throw new Error(error.message);
  return { ...data, text: data.content, image_url: data.media_url, media: items };
}

export async function updatePost(postId, text) {
  const trimmed = (text || "").trim();
  if (!trimmed) throw new Error("متن پست خالی است.");
  const { error } = await supabase
    .from("posts")
    .update({ content: trimmed, updated_at: new Date().toISOString() })
    .eq("id", postId);
  if (error) throw new Error(error.message);
}

export async function deletePost(postId) {
  const { error } = await supabase.from("posts").delete().eq("id", postId);
  if (error) throw new Error(error.message);
}

export async function uploadPostImage(userId, file) {
  if (!file) return null;
  const ext = (file.name.split(".").pop() || "jpg").toLowerCase();
  const path = `${userId}/${Date.now()}.${ext}`;
  const { error } = await supabase.storage.from("post-images").upload(path, file, {
    upsert: false,
    contentType: file.type || "image/jpeg",
  });
  if (error) throw new Error(error.message);
  const { data } = supabase.storage.from("post-images").getPublicUrl(path);
  return data.publicUrl;
}

export async function uploadPostMedia(userId, file) {
  // نسخه‌ی عمومی‌شده‌ی uploadPostImage — هم عکس و هم ویدیو را می‌پذیرد و
  // نوع رسانه را هم برمی‌گرداند تا در آرایه‌ی media پست ذخیره شود.
  if (!file) return null;
  const isVideo = file.type.startsWith("video/");
  const ext = (file.name.split(".").pop() || (isVideo ? "mp4" : "jpg")).toLowerCase();
  const path = `${userId}/${Date.now()}-${Math.random().toString(36).slice(2, 7)}.${ext}`;
  const { error } = await supabase.storage.from("post-images").upload(path, file, {
    upsert: false,
    contentType: file.type || (isVideo ? "video/mp4" : "image/jpeg"),
  });
  if (error) throw new Error(error.message);
  const { data } = supabase.storage.from("post-images").getPublicUrl(path);
  return { type: isVideo ? "video" : "image", url: data.publicUrl };
}

export async function toggleLike(postId, userId, isCurrentlyLiked) {
  if (isCurrentlyLiked) {
    const { error } = await supabase
      .from("post_likes")
      .delete()
      .eq("post_id", postId)
      .eq("user_id", userId);
    if (error) throw new Error(error.message);
    return false;
  }
  const { error } = await supabase.from("post_likes").insert({ post_id: postId, user_id: userId });
  if (error) {
    if (error.code === "23505") return true;
    throw new Error(error.message);
  }
  return true;
}

export async function fetchComments(postId) {
  const { data, error } = await supabase
    .from("post_comments")
    .select("*")
    .eq("post_id", postId)
    .order("created_at", { ascending: true });
  if (error) throw new Error(error.message);
  const rows = data || [];
  const profilesMap = await fetchProfilesMap(rows.map((c) => c.author_id));
  return rows.map((c) => ({
    ...c,
    authorName: profilesMap[c.author_id] ? profilesMap[c.author_id].name : "—",
  }));
}

export async function addComment(postId, authorId, text) {
  const trimmed = (text || "").trim();
  if (!trimmed) throw new Error("متن نظر خالی است.");
  const { error } = await supabase
    .from("post_comments")
    .insert({ post_id: postId, author_id: authorId, text: trimmed });
  if (error) throw new Error(error.message);
}

export async function updateComment(commentId, text) {
  const trimmed = (text || "").trim();
  if (!trimmed) throw new Error("متن نظر خالی است.");
  const { error } = await supabase
    .from("post_comments")
    .update({ text: trimmed, updated_at: new Date().toISOString() })
    .eq("id", commentId);
  if (error) throw new Error(error.message);
}

export async function deleteComment(commentId) {
  const { error } = await supabase.from("post_comments").delete().eq("id", commentId);
  if (error) throw new Error(error.message);
}

export async function followUser(followerId, followingId) {
  if (followerId === followingId) throw new Error("امکان دنبال کردن خودتان وجود ندارد.");
  const { error } = await supabase
    .from("follows")
    .insert({ follower_id: followerId, following_id: followingId });
  if (error && error.code !== "23505") throw new Error(error.message);
}

export async function unfollowUser(followerId, followingId) {
  const { error } = await supabase
    .from("follows")
    .delete()
    .eq("follower_id", followerId)
    .eq("following_id", followingId);
  if (error) throw new Error(error.message);
}

export async function fetchFollowStatus(followerId, followingId) {
  const { data, error } = await supabase
    .from("follows")
    .select("follower_id")
    .eq("follower_id", followerId)
    .eq("following_id", followingId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return !!data;
}

export async function fetchFollowCounts(userId) {
  const [{ count: followers }, { count: following }] = await Promise.all([
    supabase.from("follows").select("follower_id", { count: "exact", head: true }).eq("following_id", userId),
    supabase.from("follows").select("following_id", { count: "exact", head: true }).eq("follower_id", userId),
  ]);
  return { followers: followers || 0, following: following || 0 };
}

export async function fetchPostCount(userId) {
  const { count, error } = await supabase
    .from("posts")
    .select("id", { count: "exact", head: true })
    .eq("author_id", userId);
  if (error) throw new Error(error.message);
  return count || 0;
}
