import { supabase } from "../lib/supabaseClient";
import { dmId, generateId } from "../lib/ids";
import { deleteAttachment, deleteAttachments } from "../lib/upload";

var PAGE_SIZE = 30;

export async function getOrCreateDirectConversation(userId, otherUserId) {
  // این کار حالا از طریق یک تابع دیتابیسی (RPC) با SECURITY DEFINER انجام می‌شود
  // تا مشکلات RLS و race condition هنگام ساخت گفتگوی مشترک بین دو کاربر رخ ندهد.
  const { data, error } = await supabase.rpc("get_or_create_direct_conversation", {
    other_user_id: otherUserId,
  });
  if (error) throw new Error(error.message);
  return data;
}

export async function createGroupOrChannel(params) {
  const type = params.type;
  const name = params.name;
  const creatorId = params.creatorId;
  const memberIds = params.memberIds || [];

  const id = generateId(type);

  const { error: convError } = await supabase
    .from("conversations")
    .insert({ id: id, type: type, name: name, created_by: creatorId });
  if (convError) throw new Error(convError.message);

  const uniqueMemberIds = [...new Set(memberIds.filter(function (m) { return m !== creatorId; }))];
  const rows = [{ conversation_id: id, user_id: creatorId, role: "owner" }];
  uniqueMemberIds.forEach(function (uid) {
    rows.push({ conversation_id: id, user_id: uid, role: "member" });
  });

  const { error: membersError } = await supabase.from("conversation_members").insert(rows);
  if (membersError) throw new Error(membersError.message);

  return id;
}

export async function fetchUserConversations(userId) {
  const { data, error } = await supabase
    .from("conversation_members")
    .select("is_muted, is_pinned, is_archived, role, conversations(id, type, name, avatar_url, created_at)")
    .eq("user_id", userId);
  if (error) throw new Error(error.message);
  return (data || [])
    .filter(function (row) { return row.conversations; })
    .map(function (row) {
      return Object.assign({}, row.conversations, row);
    });
}

export async function setConversationPref(conversationId, userId, prefs) {
  const { error } = await supabase
    .from("conversation_members")
    .update(prefs)
    .eq("conversation_id", conversationId)
    .eq("user_id", userId);
  if (error) throw new Error(error.message);
}

export async function fetchMessages(conversationId, options) {
  const beforeCreatedAt = options && options.beforeCreatedAt;
  let query = supabase
    .from("messages")
    .select("*")
    .eq("conversation_id", conversationId)
    .order("created_at", { ascending: false })
    .limit(PAGE_SIZE);

  if (beforeCreatedAt) {
    query = query.lt("created_at", beforeCreatedAt);
  }

  const { data, error } = await query;
  if (error) throw new Error(error.message);
  return (data || []).reverse();
}

export async function sendMessage(params) {
  const conversationId = params.conversationId;
  const senderId = params.senderId;
  const content = params.content || "";
  const attachment = params.attachment || null;
  const replyTo = params.replyTo || null;
  const forwardedFrom = params.forwardedFrom || null;

  const row = {
    conversation_id: conversationId,
    sender_id: senderId,
    type: attachment ? attachment.type : "text",
    content: content || null,
    file_url: attachment ? attachment.file_url : null,
    file_meta: attachment ? attachment.file_meta : null,
    reply_to: replyTo,
    forwarded_from: forwardedFrom,
  };

  const { data, error } = await supabase.from("messages").insert(row).select().single();
  if (error) throw new Error(error.message);
  return data;
}

// پیام‌های موجود را بدون کپی مجدد فایل، به یک یا چند گفتگوی دیگر فوروارد می‌کند
// (بین کانال/گروه/گفتگوی خصوصی، در هر جهتی)
export async function forwardMessage(message, targetConversationId, senderId) {
  const attachment = message.file_url
    ? { type: message.type, file_url: message.file_url, file_meta: message.file_meta }
    : null;
  return sendMessage({
    conversationId: targetConversationId,
    senderId: senderId,
    content: message.content,
    attachment: attachment,
    forwardedFrom: message.sender_id,
  });
}

export async function editMessage(messageId, newContent) {
  const { error } = await supabase
    .from("messages")
    .update({ content: newContent, is_edited: true })
    .eq("id", messageId);
  if (error) throw new Error(error.message);
}

export async function deleteMessage(messageId) {
  const { data: msg } = await supabase.from("messages").select("file_meta").eq("id", messageId).maybeSingle();

  const { error } = await supabase
    .from("messages")
    .update({ is_deleted: true, content: null, file_url: null, file_meta: null })
    .eq("id", messageId);
  if (error) throw new Error(error.message);

  if (msg && msg.file_meta && msg.file_meta.storage_path) {
    await deleteAttachment(msg.file_meta.storage_path);
  }
}

// چند پیام را با هم حذف می‌کند (برای حالت انتخاب چندتایی).
// قبلاً این تابع پیام‌ها را یکی‌یکی و به‌صورت متوالی (sequential await در
// حلقه) حذف می‌کرد که برای انتخاب‌های بزرگ (چند ده/صد پیام) کند بود؛ اکنون
// در یک select/update دسته‌ای و یک درخواست حذفِ گروهیِ فایل انجام می‌شود.
export async function deleteMessages(messageIds) {
  const ids = (messageIds || []).filter(Boolean);
  if (ids.length === 0) return;

  const { data: msgs } = await supabase.from("messages").select("id, file_meta").in("id", ids);

  const { error } = await supabase
    .from("messages")
    .update({ is_deleted: true, content: null, file_url: null, file_meta: null })
    .in("id", ids);
  if (error) throw new Error(error.message);

  const storagePaths = (msgs || [])
    .map((m) => m.file_meta && m.file_meta.storage_path)
    .filter(Boolean);
  if (storagePaths.length > 0) {
    await deleteAttachments(storagePaths);
  }
}

export async function markMessagesAsRead(conversationId, userId, upToCreatedAt) {
  const { data: unread } = await supabase
    .from("messages")
    .select("id")
    .eq("conversation_id", conversationId)
    .lte("created_at", upToCreatedAt)
    .neq("sender_id", userId);

  if (!unread || unread.length === 0) return;

  const rows = unread.map(function (m) {
    return { message_id: m.id, user_id: userId, read_at: new Date().toISOString() };
  });
  const { error } = await supabase.from("message_reads").upsert(rows, { onConflict: "message_id,user_id" });
  if (error) throw new Error(error.message);
}

// برای تیک دوگانه: مشخص می‌کند کدام‌یک از پیام‌های ارسالی من توسط طرف مقابل خوانده شده‌اند.
// وجود حداقل یک رکورد در message_reads برای یک پیام (که همیشه از یک خواننده غیر از فرستنده است)
// یعنی آن پیام خوانده شده است.
export async function fetchReadReceipts(messageIds) {
  if (!messageIds || messageIds.length === 0) return new Set();
  const { data, error } = await supabase
    .from("message_reads")
    .select("message_id")
    .in("message_id", messageIds);
  if (error) throw new Error(error.message);
  return new Set((data || []).map(function (r) { return r.message_id; }));
}

export async function searchMessagesInConversation(conversationId, searchQuery) {
  const pattern = "%" + searchQuery + "%";
  const { data, error } = await supabase
    .from("messages")
    .select("*")
    .eq("conversation_id", conversationId)
    .eq("is_deleted", false)
    .ilike("content", pattern)
    .order("created_at", { ascending: false })
    .limit(50);
  if (error) throw new Error(error.message);
  return data || [];
}
