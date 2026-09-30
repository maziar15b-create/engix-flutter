"use client";
import { useEffect, useState, useCallback } from "react";
import { supabase } from "../../lib/supabaseClient";
import { fetchProfilesMap } from "../../lib/messengerUtils";
import { createGroupOrChannel } from "../../services/messengerService";

/**
 * Form for creating a new group or channel: pick type, set a name,
 * and select members from the user's existing contacts.
 */
export default function NewGroupView({ profile, onCancel, onCreated }) {
  const [type, setType] = useState("group"); // "group" | "channel"
  const [name, setName] = useState("");
  const [contacts, setContacts] = useState(null);
  const [selectedIds, setSelectedIds] = useState(new Set());
  const [creating, setCreating] = useState(false);
  const [error, setError] = useState("");

  const loadContacts = useCallback(async () => {
    const { data } = await supabase.from("contacts").select("contact_id").eq("owner_id", profile.id);
    const pMap = await fetchProfilesMap((data || []).map((r) => r.contact_id));
    setContacts((data || []).map((r) => pMap[r.contact_id]).filter(Boolean));
  }, [profile.id]);

  useEffect(() => {
    loadContacts();
  }, [loadContacts]);

  const toggleSelect = (id) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const handleCreate = async () => {
    setError("");
    const trimmedName = name.trim();
    if (!trimmedName) {
      setError("نام گروه/کانال را وارد کنید.");
      return;
    }
    if (selectedIds.size === 0) {
      setError("حداقل یک عضو انتخاب کنید.");
      return;
    }
    setCreating(true);
    try {
      const conversationId = await createGroupOrChannel({
        type,
        name: trimmedName,
        creatorId: profile.id,
        memberIds: [...selectedIds],
      });
      onCreated(conversationId);
    } catch (e) {
      setError(e.message);
    } finally {
      setCreating(false);
    }
  };

  return (
    <div>
      <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 18 }}>
        <button className="btn-ghost" style={{ padding: "6px 12px" }} onClick={onCancel}>
          ← بازگشت
        </button>
        <div className="section-title" style={{ marginBottom: 0 }}>
          ایجاد گروه یا کانال جدید
        </div>
      </div>

      <div style={{ display: "flex", gap: 6, marginBottom: 16 }}>
        <div
          className={"role-chip" + (type === "group" ? " role-chip-active" : "")}
          onClick={() => setType("group")}
        >
          گروه
        </div>
        <div
          className={"role-chip" + (type === "channel" ? " role-chip-active" : "")}
          onClick={() => setType("channel")}
        >
          کانال
        </div>
      </div>

      <input
        className="field-input"
        placeholder={type === "group" ? "نام گروه" : "نام کانال"}
        value={name}
        onChange={(e) => setName(e.target.value)}
        style={{ marginBottom: 18, width: "100%" }}
      />

      <div className="section-sub" style={{ marginBottom: 8 }}>
        انتخاب اعضا از مخاطبین ({selectedIds.size} انتخاب‌شده)
      </div>

      {contacts === null && <div style={{ color: "#94A3B8", fontSize: 13 }}>در حال بارگذاری...</div>}
      {contacts && contacts.length === 0 && (
        <div style={{ color: "#6B7F99", fontSize: 13 }}>
          هنوز مخاطبی ندارید. اول از تب «مخاطبین» کسی را اضافه کنید.
        </div>
      )}

      {contacts &&
        contacts.map((c) => {
          const selected = selectedIds.has(c.id);
          return (
            <div
              key={c.id}
              onClick={() => toggleSelect(c.id)}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 10,padding: "10px 0",
                borderBottom: "1px solid rgba(255,255,255,0.08)",
                cursor: "pointer",
              }}
            >
              <span
                style={{
                  width: 16,
                  height: 16,
                  borderRadius: 3,
                  border: "1.5px solid #FF6B35",
                  background: selected ? "#FF6B35" : "transparent",
                  flexShrink: 0,
                }}
              />
              <div>
                <div style={{ fontSize: 13.5 }}>{c.name}</div>
                <div className="mono" style={{ fontSize: 11, color: "#6B7F99" }}>
                  {c.code}
                </div>
              </div>
            </div>
          );
        })}

      {error && <div style={{ color: "#F87171", fontSize: 12.5, marginTop: 12 }}>{error}</div>}

      <button
        className="btn-primary"
        style={{ marginTop: 18, width: "100%" }}
        disabled={creating}
        onClick={handleCreate}
      >
        {creating ? "در حال ایجاد..." : type === "group" ? "ایجاد گروه" : "ایجاد کانال"}
      </button>
    </div>
  );
}
