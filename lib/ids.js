export function dmId(userIdA, userIdB) {
  const arr = [String(userIdA), String(userIdB)].sort();
  return "dm_" + arr[0] + "_" + arr[1];
}

export function generateId(prefix) {
  var p = prefix || "id";
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return p + "_" + crypto.randomUUID();
  }
  var rand = Math.random().toString(36).slice(2) + Date.now().toString(36);
  return p + "_" + rand;
}

export function conversationChannelName(conversationId) {
  return "conversation:" + conversationId;
}

export function presenceChannelName() {
  return "presence:engix";
}

export function typingChannelName(conversationId) {
  return "typing:" + conversationId;
}

export var FIELD_OPTIONS = ["عمران", "معماری", "برق", "مکانیک", "نقشه‌برداری", "شهرسازی"];

export var ROLE_KEYS = ["ناظر", "مجری", "طراح", "مالک", "پیمانکار"];

export var ROLE_LABELS = {
  "ناظر": "ناظر",
  "مجری": "مجری",
  "طراح": "طراح",
  "مالک": "مالک",
  "پیمانکار": "پیمانکار",
};

export function genProjectCode() {
  var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  var code = "";
  for (var i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}
