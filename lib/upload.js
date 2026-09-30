import { supabase } from "./supabaseClient";
import { generateId } from "./ids";

var BUCKET = "messenger-attachments";

var MAX_SIZE_BYTES = 25 * 1024 * 1024;

var ALLOWED_TYPES = {
  image: ["image/jpeg", "image/png", "image/webp", "image/gif"],
  pdf: ["application/pdf"],
  word: [
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  ],
  voice: ["audio/webm", "audio/mp4", "audio/mpeg", "audio/ogg", "audio/wav"],
};

function detectAttachmentType(mimeType) {
  var types = Object.keys(ALLOWED_TYPES);
  for (var i = 0; i < types.length; i++) {
    var type = types[i];
    if (ALLOWED_TYPES[type].indexOf(mimeType) !== -1) return type;
  }
  return null;
}

function extensionFromName(name) {
  var idx = name.lastIndexOf(".");
  return idx >= 0 ? name.slice(idx) : "";
}

export async function uploadAttachment(file, conversationId, options) {
  var opts = options || {};
  var mimeType = file.type || "application/octet-stream";
  var attachmentType = detectAttachmentType(mimeType);

  if (!attachmentType) {
    throw new Error("نوع فایل پشتیبانی نمی‌شود: " + mimeType);
  }
  if (file.size > MAX_SIZE_BYTES) {
    throw new Error("حجم فایل بیشتر از حد مجاز (۲۵ مگابایت) است.");
  }

  var originalName = opts.fileName || file.name || (attachmentType + "-file");
  var ext = extensionFromName(originalName) || (attachmentType === "voice" ? ".webm" : "");
  var storagePath = conversationId + "/" + generateId(attachmentType) + ext;

  const { error: uploadError } = await supabase.storage
    .from(BUCKET)
    .upload(storagePath, file, { contentType: mimeType, upsert: false });

  if (uploadError) {
    throw new Error("آپلود ناموفق بود: " + uploadError.message);
  }

  const { data: publicUrlData } = supabase.storage.from(BUCKET).getPublicUrl(storagePath);

  return {
    type: attachmentType,
    file_url: publicUrlData.publicUrl,
    file_meta: {
      name: originalName,
      size: file.size,
      mime_type: mimeType,
      storage_path: storagePath,
    },
  };
}

export async function deleteAttachment(storagePath) {
  if (!storagePath) return;
  const { error } = await supabase.storage.from(BUCKET).remove([storagePath]);
  if (error) {
    console.error("Failed to delete attachment:", error.message);
  }
}

// حذف دسته‌ای چند فایل در یک درخواست، به‌جای یک فراخوانی جدا برای هر فایل
export async function deleteAttachments(storagePaths) {
  const paths = (storagePaths || []).filter(Boolean);
  if (paths.length === 0) return;
  const { error } = await supabase.storage.from(BUCKET).remove(paths);
  if (error) {
    console.error("Failed to delete attachments:", error.message);
  }
}
