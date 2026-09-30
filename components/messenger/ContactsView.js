"use client";
import { useEffect, useState, useCallback } from "react";
import { supabase } from "../../lib/supabaseClient";
import { fetchProfilesMap } from "../../lib/messengerUtils";
import { getOrCreateDirectConversation } from "../../services/messengerService";
import { Capacitor } from "@capacitor/core";
import { Contacts } from "@capacitor-community/contacts";

const GOLD_LIGHT = "#FF3D63";
const GOLD = "#C50337";

function normalizePhone(p) {
  return (p || "").replace(/\D/g, "").slice(-10);
}

export default function ContactsView({ profile, onStartDirectChat, onNewGroup }) {
  const [contacts, setContacts] = useState(null);
  const [phone, setPhone] = useState("");
  const [msg, setMsg] = useState("");
  const [starting, setStarting] = useState(false);

  const [syncing, setSyncing] = useState(false);
  const [syncMsg, setSyncMsg] = useState("");
  const [foundMatches, setFoundMatches] = useState([]);

  const refresh = useCallback(async () => {
    const { data } = await supabase.from("contacts").select("contact_id").eq("owner_id", profile.id);
    const pMap = await fetchProfilesMap((data || []).map((r) => r.contact_id));
    setContacts((data || []).map((r) => pMap[r.contact_id]).filter(Boolean));
  }, [profile.id]);

  useEffect(() => { refresh(); }, [refresh]);

  const addContact = async () => {
    setMsg("");
    const raw = phone.trim();
    if (!raw) { setMsg("شماره موبایل را وارد کنید."); return; }
    const target = normalizePhone(raw);
    const { data: allProfiles } = await supabase
      .from("profiles")
      .select("id, code, name, phone")
      .not("phone", "is", null);
    const eng = (allProfiles || []).find((p) => normalizePhone(p.phone) === target);
    if (!eng) { setMsg("کاربری با این شماره موبایل پیدا نشد."); return; }
    if (eng.id === profile.id) { setMsg("این شماره خودتان است."); return; }
    const { error } = await supabase.from("contacts").insert({ owner_id: profile.id, contact_id: eng.id });
    if (error) { setMsg(error.code === "23505" ? "قبلاً اضافه شده." : error.message); return; }
    setPhone("");
    setMsg("افزوده شد.");
    refresh();
  };

  const startChat = async (otherId) => {
    setStarting(true);
    try {
      const conversationId = await getOrCreateDirectConversation(profile.id, otherId);
      onStartDirectChat(conversationId);
    } catch (e) {
      setMsg(e.message);
    } finally {
      setStarting(false);
    }
  };

  const syncPhoneContacts = async () => {
    setSyncMsg(""); setFoundMatches([]); setSyncing(true);
    try {
      const perm = await Contacts.requestPermissions();
      if (perm.contacts !== "granted") { setSyncMsg("اجازه دسترسی به مخاطبین داده نشد."); setSyncing(false); return; }
      const result = await Contacts.getContacts({ projection: { name: true, phones: true } });
      const deviceNumbers = new Set();
      (result.contacts || []).forEach((c) =>
        (c.phones || []).forEach((ph) => {
          const n = normalizePhone(ph.number);
          if (n) deviceNumbers.add(n);
        })
      );
      const existingIds = new Set((contacts || []).map((c) => c.id));
      const { data: allProfiles } = await supabase
        .from("profiles")
        .select("id, code, name, phone")
        .not("phone", "is", null);
      const matches = (allProfiles || []).filter(
        (p) => p.id !== profile.id && !existingIds.has(p.id) && deviceNumbers.has(normalizePhone(p.phone))
      );
      if (matches.length === 0) setSyncMsg("همکار جدیدی از مخاطبین گوشی پیدا نشد.");
      setFoundMatches(matches.map((m) => ({ ...m, selected: true })));
    } catch (e) {
      setSyncMsg("خطا در خواندن مخاطبین: " + e.message);
    }
    setSyncing(false);
  };

  const toggleMatch = (id) =>
    setFoundMatches((prev) => prev.map((m) => (m.id === id ? { ...m, selected: !m.selected } : m)));

  const addSelectedMatches = async () => {
    const toAdd = foundMatches.filter((m) => m.selected);
    for (const m of toAdd) {
      try { await supabase.from("contacts").insert({ owner_id: profile.id, contact_id: m.id }); } catch (e) { /* ignore */ }
    }
    setFoundMatches([]);
    setSyncMsg("مخاطبین انتخاب‌شده اضافه شدند.");
    refresh();
  };

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "flex-end", marginBottom: 14 }}>
        <button className="btn-primary" onClick={onNewGroup}>+ ساخت گروه یا کانال</button>
      </div>

      <div style={{ fontSize: 15, fontWeight: 700, marginBottom: 4, color: "#F2ECDD" }}>مخاطبین</div>
      <div style={{ fontSize: 12.5, color: "#8C8474", marginBottom: 12 }}>با شماره موبایل، همکار را به مخاطبین اضافه کنید.</div>
      <div style={{ display: "flex", gap: 8, marginBottom: 10 }}>
        <input className="field-input mono" placeholder="شماره موبایل" inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} />
        <button className="btn-primary" onClick={addContact}>افزودن</button>
      </div>
      {msg && <div style={{ fontSize: 12.5, color: "#8C8474", marginBottom: 14 }}>{msg}</div>}

      {Capacitor.isNativePlatform() && (
        <div style={{ marginBottom: 20, borderTop: "1px solid rgba(197,3,55,0.15)", paddingTop: 16 }}>
          <button className="btn-ghost" disabled={syncing} onClick={syncPhoneContacts}>
            {syncing ? "در حال بررسی..." : "همگام‌سازی با مخاطبین گوشی"}
          </button>
          {syncMsg && <div style={{ fontSize: 12.5, color: "#8C8474", marginTop: 10 }}>{syncMsg}</div>}
          {foundMatches.length > 0 && (
            <div style={{ marginTop: 12 }}>
              <div style={{ fontSize: 12.5, color: "#8C8474", marginBottom: 8 }}>این افراد از مخاطبین گوشی شما در EngiX ثبت‌نام کرده‌اند:</div>
              {foundMatches.map((m) => (
                <div key={m.id} onClick={() => toggleMatch(m.id)} style={{ display: "flex", alignItems: "center", gap: 10, padding: "8px 0", borderBottom: "1px solid rgba(197,3,55,0.1)", cursor: "pointer" }}>
                  <span style={{ width: 16, height: 16, borderRadius: 4, border: `1.5px solid ${GOLD}`, background: m.selected ? GOLD : "transparent", flexShrink: 0 }} />
                  <span style={{ fontSize: 13.5, color: "#E7E1D2" }}>{m.name}</span>
                  <span className="mono" style={{ fontSize: 11, color: "#5E5748" }}>{m.code}</span>
                </div>
              ))}
              <button className="btn-primary" onClick={addSelectedMatches} style={{ marginTop: 10 }}>افزودن انتخاب‌شده‌ها</button>
            </div>
          )}
        </div>
      )}

      {contacts === null && <div style={{ color: "#8C8474", fontSize: 13 }}>در حال بارگذاری...</div>}
      {contacts && contacts.length === 0 && <div style={{ color: "#5E5748", fontSize: 13 }}>هنوز مخاطبی اضافه نکرده‌اید.</div>}
      {contacts && contacts.map((c) => (
        <div key={c.id} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "12px 14px", marginBottom: 8, background: "linear-gradient(160deg, #1D1B22, #141318)", border: "1px solid rgba(197,3,55,0.14)", borderRadius: 10 }}>
          <div>
            <div style={{ fontSize: 13.5, color: "#F2ECDD" }}>{c.name}</div>
            <div className="mono" style={{ fontSize: 11, color: "#5E5748" }}>{c.code}</div>
          </div>
          <button className="btn-ghost" style={{ padding: "6px 14px", fontSize: 12 }} disabled={starting} onClick={() => startChat(c.id)}>پیام</button>
        </div>
      ))}
    </div>
  );
}
