"use client";
import { useState, useRef } from "react";
import OnlineStatus from "./OnlineStatus";
import {
  addMembers,
  removeMember,
  promoteToAdmin,
  demoteToMember,
  leaveConversation,
  transferOwnership,
  updateConversationInfo,
} from "../../services/membersService";
import { supabase } from "../../lib/supabaseClient";
import { fetchProfilesMap } from "../../lib/messengerUtils";

/**
 * Manage members of a group/channel: view list with roles/online
 * status, add members from contacts, promote/demote/remove (owner
 * & admin only), rename the group, change its avatar, leave, or
 * transfer ownership.
 */
export default function MembersPanel({
  profile,
  conversationId,
  conversation,
  members,
  myRole,
  presence,
  onBack,
  onMembersChanged,
}) {
  const [error, setError] = useState("");
  const [renaming, setRenaming] = useState(false);
  const [newName, setNewName] = useState(conversation?.name || "");
  const [addingOpen, setAddingOpen] = useState(false);
  const [contacts, setContacts] = useState(null);
  const [avatarUploading, setAvatarUploading] = useState(false);
  const avatarInputRef = useRef(null);

  const canManage = myRole === "owner" || myRole === "admin";
  const isOwner = myRole === "owner";

  const loadContactsNotInGroup = async () => {
    const { data } = await supabase.from("contacts").select("contact_id").eq("owner_id", profile.id);
    const pMap = await fetchProfilesMap((data || []).map((r) => r.contact_id));
    const memberIds = new Set(members.map((m) => m.user_id));
    setContacts(Object.values(pMap).filter((c) => !memberIds.has(c.id)));
  };

  const openAddMembers = async () => {
    setAddingOpen(true);
    await loadContactsNotInGroup();
  };

  const handleAdd = async (userId) => {
    try {
      await addMembers(conversationId, [userId]);
      setAddingOpen(false);
      onMembersChanged();
    } catch (e) {
      setError(e.message);
    }
  };

  const handleRemove = async (userId) => {
    try {
      await removeMember(conversationId, userId);
      onMembersChanged();
    } catch (e) {
      setError(e.message);
    }
  };

  const handlePromote = async (userId) => {
    try {
      await promoteToAdmin(conversationId, userId);
      onMembersChanged();
    } catch (e) {
      setError(e.message);
    }
  };

  const handleDemote = async (userId) => {
    try {
      await demoteToMember(conversationId, userId);
      onMembersChanged();
    } catch (e) {
      setError(e.message);
    }
  };

  const handleLeave = async () => {
    try {
      await leaveConversation(conversationId, profile.id);
      onBack();
    } catch (e) {
      setError(e.message);
    }
  };

  const handleTransferAndLeave = async (newOwnerId) => {
    try {
      await transferOwnership(conversationId, profile.id, newOwnerId);
      await leaveConversation(conversationId, profile.id);
      onBack();
    } catch (e) {
      setError(e.message);
    }
  };

  const saveRename = async () => {
    const trimmed = newName.trim();
    if (!trimmed) return;
    try {
      await updateConversationInfo(conversationId, { name: trimmed });
      setRenaming(false);
      onMembersChanged();
    } catch (e) {
      setError(e.message);
    }
  };

  const uploadAvatar = async (e) => {
    const file = e.target.files && e.target.files[0];
    if (!file) return;
    setError("");
    setAvatarUploading(true);
    const AVATAR_ALLOWED_TYPES = ["image/jpeg", "image/png", "image/webp", "image/gif"];
    if (!AVATAR_ALLOWED_TYPES.includes(file.type)) {
      setError("فرمت این عکس (مثلاً HEIC) پشتیبانی نمی‌شود. لطفاً JPG، PNG، WebP یا GIF انتخاب کنید.");
      return;
    }
    try {
      const ext = (file.name.split(".").pop() || "jpg").toLowerCase();
      // نام فایل هر بار یکتاست تا آدرس عمومی عوض شود و عکس قدیمیِ کش‌شده
      // به‌جای عکس جدید نمایش داده نشود.
      const path = `conversations/${conversationId}/avatar-${Date.now()}.${ext}`;
      const { error: upErr } = await supabase.storage.from("avatars").upload(path, file, { upsert: true, contentType: file.type });
      if (upErr) throw upErr;
      const { data } = supabase.storage.from("avatars").getPublicUrl(path);
      await updateConversationInfo(conversationId, { avatar_url: data.publicUrl });
      onMembersChanged();
    } catch (e) {
      setError(e.message);
    } finally {
      setAvatarUploading(false);
    }
  };

  const roleLabel = (role) => (role === "owner" ? "مالک" : role === "admin" ? "مدیر" : "عضو");

  return (
    <div>
      <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 18 }}>
        <button data-native-back="true" className="btn-ghost" style={{ padding: "6px 12px" }} onClick={onBack}>
          ←
        </button>
        {renaming ? (
          <div style={{ display: "flex", gap: 6, flex: 1 }}>
            <input className="field-input" value={newName} onChange={(e) => setNewName(e.target.value)} style={{ flex: 1 }} />
            <button className="btn-primary" style={{ padding: "6px 12px" }} onClick={saveRename}>
              ذخیره
            </button>
          </div>
        ) : (<div className="section-title" style={{ marginBottom: 0, flex: 1 }}>
            {conversation?.name || "اعضا"}
            {canManage && (
              <button
                className="btn-ghost"
                style={{ padding: "2px 8px", fontSize: 11, marginRight: 8 }}
                onClick={() => setRenaming(true)}
              >
                ✏️ تغییر نام
              </button>
            )}
          </div>
        )}
      </div>

      {canManage && (
        <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 18 }}>
          <div
            style={{
              width: 56, height: 56, borderRadius: "50%", flexShrink: 0, overflow: "hidden",
              background: "linear-gradient(155deg, #26232C, #0B0A0D)", border: "1px solid rgba(197,3,55,0.3)",
              display: "flex", alignItems: "center", justifyContent: "center",
            }}
          >
            {conversation?.avatar_url ? (
              <img loading="lazy" decoding="async" src={conversation.avatar_url} alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
            ) : (
              <span style={{ fontSize: 22 }}>{conversation?.type === "channel" ? "📣" : "👥"}</span>
            )}
          </div>
          <input ref={avatarInputRef} type="file" accept="image/*" style={{ display: "none" }} onChange={uploadAvatar} />
          <button className="btn-ghost" disabled={avatarUploading} onClick={() => avatarInputRef.current && avatarInputRef.current.click()}>
            {avatarUploading ? "در حال آپلود..." : "تغییر عکس گروه/کانال"}
          </button>
        </div>
      )}

      {canManage && (
        <button className="btn-primary" style={{ marginBottom: 16 }} onClick={openAddMembers}>
          + افزودن عضو
        </button>
      )}

      {addingOpen && (
        <div className="panel" style={{ padding: 14, marginBottom: 16 }}>
          <div className="section-sub" style={{ marginBottom: 8 }}>افزودن از مخاطبین</div>
          {contacts === null && <div style={{ fontSize: 12.5, color: "#94A3B8" }}>در حال بارگذاری...</div>}
          {contacts && contacts.length === 0 && (
            <div style={{ fontSize: 12.5, color: "#6B7F99" }}>همه‌ی مخاطبین شما عضو هستند یا مخاطبی ندارید.</div>
          )}
          {contacts &&
            contacts.map((c) => (
              <div key={c.id} style={{ display: "flex", justifyContent: "space-between", padding: "6px 0" }}>
                <span style={{ fontSize: 13 }}>{c.name}</span>
                <button className="btn-ghost" style={{ padding: "3px 10px", fontSize: 11 }} onClick={() => handleAdd(c.id)}>
                  افزودن
                </button>
              </div>
            ))}
          <button className="btn-ghost" style={{ marginTop: 8, fontSize: 12 }} onClick={() => setAddingOpen(false)}>
            بستن
          </button>
        </div>
      )}

      <div className="section-sub">{members.length} عضو</div>
      {members.map((m) => {
        const online = presence.isOnline(m.user_id);
        const isMe = m.user_id === profile.id;
        return (
          <div
            key={m.user_id}
            style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "10px 0", borderBottom: "1px solid rgba(255,255,255,0.08)" }}
          >
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <OnlineStatus isOnline={online} size={8} />
              <div>
                <div style={{ fontSize: 13.5 }}>
                  {m.profiles?.name || "کاربر"} {isMe && "(شما)"}
                </div>
                <span className="badge" style={{ fontSize: 10 }}>{roleLabel(m.role)}</span>
              </div>
            </div>

            {canManage && !isMe && m.role !== "owner" && (
              <div style={{ display: "flex", gap: 4 }}>
                {m.role === "member" ? (
                  <button className="btn-ghost" style={{ padding: "3px 8px", fontSize: 11 }} onClick={() => handlePromote(m.user_id)}>
                    ارتقا به مدیر
                  </button>
                ) : (
                  <button className="btn-ghost" style={{ padding: "3px 8px", fontSize: 11 }} onClick={() => handleDemote(m.user_id)}>
                    عزل از مدیریت
                  </button>
                )}
                <button
                  className="btn-ghost"
                  style={{ padding: "3px 8px", fontSize: 11, color: "#F87171" }}
                  onClick={() => handleRemove(m.user_id)}
                >
                  حذف
                </button>
              </div>
            )}
          </div>
        );
      })}

      {error && <div className="error-text">{error}</div>}

      <div style={{ marginTop: 20, borderTop: "1px solid rgba(255,255,255,0.1)", paddingTop: 16 }}>
        {isOwner && members.length > 1 ? (
          <div style={{ fontSize: 12, color: "#94A3B8" }}>
            برای خروج، ابتدا باید مالکیت را به عضو دیگری منتقل کنید:{members
              .filter((m) => m.user_id !== profile.id)
              .map((m) => (
                <button
                  key={m.user_id}
                  className="btn-ghost"
                  style={{ display: "block", marginTop: 8, width: "100%" }}
                  onClick={() => handleTransferAndLeave(m.user_id)}
                >
                  انتقال مالکیت به {m.profiles?.name} و خروج
                </button>
              ))}
          </div>
        ) : (
          <button className="btn-ghost" style={{ color: "#F87171" }} onClick={handleLeave}>
            خروج از {conversation?.type === "channel" ? "کانال" : "گروه"}
          </button>
        )}
      </div>
    </div>
  );
}
