import { supabase } from "./supabaseClient";

var BUCKET = "project-media";
var MAX_SIZE_BYTES = 60 * 1024 * 1024;

var ALLOWED_TYPES = {
  image: ["image/jpeg", "image/png", "image/webp", "image/gif"],
  video: ["video/mp4", "video/webm", "video/quicktime"],
  voice: ["audio/webm", "audio/mp4", "audio/mpeg", "audio/ogg", "audio/wav"],
};

function detectMediaType(mimeType) {
  var types = Object.keys(ALLOWED_TYPES);
  for (var i = 0; i < types.length; i++) {
    if (ALLOWED_TYPES[types[i]].indexOf(mimeType) !== -1) return types[i];
  }
  return null;
}

function extensionFromName(name) {
  var idx = name.lastIndexOf(".");
  return idx >= 0 ? name.slice(idx) : "";
}

export async function uploadProjectMedia(file, projectId) {
  var mimeType = file.type || "application/octet-stream";
  var mediaType = detectMediaType(mimeType);
  if (!mediaType) throw new Error("نوع فایل پشتیبانی نمی‌شود.");
  if (file.size > MAX_SIZE_BYTES) throw new Error("حجم فایل بیشتر از حد مجاز (۶۰ مگابایت) است.");

  var ext = extensionFromName(file.name || "") || (mediaType === "voice" ? ".webm" : "");
  var storagePath = projectId + "/" + Date.now() + "-" + Math.random().toString(36).slice(2, 8) + ext;

  const { error: uploadError } = await supabase.storage
    .from(BUCKET)
    .upload(storagePath, file, { contentType: mimeType, upsert: false });
  if (uploadError) throw new Error("آپلود ناموفق بود: " + uploadError.message);

  const { data: publicUrlData } = supabase.storage.from(BUCKET).getPublicUrl(storagePath);
  return { type: mediaType, url: publicUrlData.publicUrl };
}
