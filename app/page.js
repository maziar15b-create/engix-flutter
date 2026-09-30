"use client";
import { useEffect, useState, useCallback } from "react";
import dynamic from "next/dynamic";
import { supabase } from "../lib/supabaseClient";
import AuthForm from "../components/AuthForm";
import CompleteProfile from "../components/CompleteProfile";
import HomePanel from "../components/HomePanel";
import ProjectsPanel from "../components/ProjectsPanel";
import MessengerErrorBoundary from "../components/messenger/MessengerErrorBoundary";
import ProfileMenu from "../components/ProfileMenu";
import TopSearch from "../components/TopSearch";
import RoleCenter from "../components/RoleCenter";
import PushNotificationInit from "../components/PushNotificationInit";
import LanguageSwitcher from "../components/LanguageSwitcher";
import { useTranslation } from "../lib/i18n/LanguageContext";
import { usePresence } from "../hooks/usePresence";
import { Home, MessageCircle, HardHat, Users, Wrench } from "lucide-react";

// Only the active tab is ever shown, so these load on demand instead of
// bloating the very first page load with every panel in the app.
const PANEL_LOADING = <div style={{ textAlign: "center", padding: "60px 0", color: "#6B7085", fontSize: 13 }}>در حال بارگذاری...</div>;
const dyn = (loader) => dynamic(loader, { loading: () => PANEL_LOADING, ssr: false });

const ProjectDetail = dyn(() => import("../components/ProjectDetail"));
const MessengerPanel = dyn(() => import("../components/messenger/MessengerPanel"));
const EducationPanel = dyn(() => import("../components/EducationPanel"));
const ProfilePanel = dyn(() => import("../components/ProfilePanel"));
const ToolsPanel = dyn(() => import("../components/tools/ToolsPanel"));
const SocialPanel = dyn(() => import("../components/SocialPanel"));
const SocialProfilePanel = dyn(() => import("../components/SocialProfilePanel"));
const AdminPanel = dyn(() => import("../components/AdminPanel"));

const GOLD_LIGHT = "#FF3D63";
const GOLD = "#C50337";
const GOLD_DEEP = "#7A0224";

function LoadingScreen({ label }) {
  return (
    <div className="wrap" style={{ textAlign: "center", paddingTop: 120, animation: "fadeIn 0.4s ease both" }}>
      <div
        style={{
          width: 44, height: 44, borderRadius: "50%", margin: "0 auto 18px",
          border: "3px solid rgba(197,3,55,0.18)",
          borderTopColor: GOLD,
          animation: "spin 0.9s linear infinite",
        }}
      />
      <div style={{ color: "#6B7085", fontSize: 13 }}>{label}</div>
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}

export default function Page() {
  const { t } = useTranslation();
  const [session, setSession] = useState(undefined);
  const [profile, setProfile] = useState(undefined);
  const [tab, setTab] = useState("home");
  const [visitedTabs, setVisitedTabs] = useState(() => new Set(["home"]));
  const [activeProjectId, setActiveProjectId] = useState(null);
  const [activeRoleLabel, setActiveRoleLabel] = useState(null);
  const [rolesOpen, setRolesOpen] = useState(false);
  const [socialProfileUserId, setSocialProfileUserId] = useState(null);
  const [messengerThreadOpen, setMessengerThreadOpen] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data: listener } = supabase.auth.onAuthStateChange((_event, s) => setSession(s));
    return () => listener.subscription.unsubscribe();
  }, []);

  const loadProfile = useCallback(async () => {
    if (!session) return;
    // با join کردن نقش فعال داخل همین کوئری، به‌جای دو درخواست پشت‌سرهم
    // (پروفایل، بعد نقش)، فقط یک درخواست به سرور می‌زنیم — ورود سریع‌تر می‌شود.
    const { data } = await supabase
      .from("profiles")
      .select("*, active_role:roles!active_role_id(label)")
      .eq("id", session.user.id)
      .maybeSingle();
    setProfile(data || null);
    setActiveRoleLabel(data?.active_role?.label || null);
  }, [session]);

  useEffect(() => { if (session) loadProfile(); }, [session, loadProfile]);

  const loadActiveRoleLabel = useCallback(async () => {
    if (!profile?.active_role_id) { setActiveRoleLabel(null); return; }
    const { data } = await supabase.from("roles").select("label").eq("id", profile.active_role_id).maybeSingle();
    setActiveRoleLabel(data?.label || null);
  }, [profile?.active_role_id]);

  // ردیابی «آنلاین بودن» برای کل اپ (نه فقط تب پیام‌رسان) — هر جای اپ که
  // کاربر باز باشد، is_online/last_seen او در پروفایل به‌روز می‌ماند.
  // همین یک نمونه به MessengerPanel هم پاس داده می‌شود تا دوبار به کانال
  // presence وصل نشویم (وصل‌شدن دوگانه باعث کرش اپ می‌شد).
  const presence = usePresence(profile?.id);

  const changeTab = (nextTab) => {
    setTab(nextTab);
    setSocialProfileUserId(null);
    setVisitedTabs((prev) => (prev.has(nextTab) ? prev : new Set(prev).add(nextTab)));
  };

  if (session === undefined) {
    return <LoadingScreen label={t("common.loading")} />;
  }
  if (!session) return <AuthForm />;
  if (profile === undefined) {
    return <LoadingScreen label={t("common.loadingProfile")} />;
  }
  if (!profile) return <CompleteProfile userId={session.user.id} onDone={loadProfile} />;

  if (activeProjectId) {
    return (
      <div className="wrap">
        <PushNotificationInit userId={profile.id} />
        <ProjectDetail profile={profile} projectId={activeProjectId} onBack={() => setActiveProjectId(null)} />
      </div>
    );
  }

  const navItems = [
    { key: "home", label: t("nav.home"), Icon: Home },
    { key: "messages", label: t("nav.messages"), Icon: MessageCircle },
    { key: "projects", label: t("nav.projects"), Icon: HardHat },
    { key: "social", label: t("nav.social"), Icon: Users },
    { key: "tools", label: t("nav.tools"), Icon: Wrench },
  ];

  return (
    <div className="wrap" style={{ paddingBottom: 118 }}>
      <PushNotificationInit userId={profile.id} />

      {/* ===== هدر ===== */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 24 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <div
            style={{
              width: 32, height: 32, borderRadius: "50%",
              background: `linear-gradient(150deg, ${GOLD_LIGHT}, ${GOLD} 55%, ${GOLD_DEEP} 100%)`,
              display: "flex", alignItems: "center", justifyContent: "center",
              boxShadow: `0 8px 18px -6px rgba(197,3,55,0.55)`,
              flexShrink: 0,
            }}
          >
            <span style={{ color: "#FFFFFF", fontWeight: 800, fontSize: 14 }}>E</span>
          </div>
          <div
            style={{
              fontSize: 19, fontWeight: 800, letterSpacing: 0.5,
              background: `linear-gradient(180deg, ${GOLD_LIGHT} 0%, ${GOLD} 60%, ${GOLD_DEEP} 100%)`,
              WebkitBackgroundClip: "text", backgroundClip: "text", color: "transparent",
            }}
          >
            EngiX
          </div>
        </div>

        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <TopSearch />
          <LanguageSwitcher />
          {tab === "social" ? (
            <button
              onClick={() => setSocialProfileUserId(profile.id)}
              className="pressable"
              style={{
                width: 36, height: 36, borderRadius: "50%",
                background: "linear-gradient(160deg, #26232C, #141318)",
                border: "1px solid rgba(197,3,55,0.4)", display: "flex", alignItems: "center",
                justifyContent: "center", fontSize: 16, cursor: "pointer", overflow: "hidden",
                boxShadow: "0 10px 20px -10px rgba(0,0,0,0.7)",
              }}
              aria-label={t("nav.socialProfileAria")}
            >
              {profile.avatar_url ? (
                <img loading="lazy" decoding="async" src={profile.avatar_url} alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
              ) : "👤"}
            </button>
          ) : (
            <ProfileMenu
              profile={profile}
              activeRoleLabel={activeRoleLabel}
              onOpenProfile={() => changeTab("profile")}
              onOpenAdmin={() => changeTab("admin")}
              onOpenRoles={() => setRolesOpen(true)}
            />
          )}
        </div>
      </div>

      {/* ===== محتوای صفحه ===== */}
      {/* نکته‌ی مهم برای سرعت: هر پنل فقط یک‌بار mount می‌شود و با
          display:none/block مخفی یا نمایش داده می‌شود — نه هر بار
          ساخته و نابود. این‌طوری برگشتن به یک تب، دوباره کل داده‌ها
          را از سرور نمی‌گیرد و فوری نمایش داده می‌شود. */}
      <div className="panel">
        <span className="corner corner-tl" /><span className="corner corner-tr" />
        <span className="corner corner-bl" /><span className="corner corner-br" />

        {visitedTabs.has("home") && (
          <div style={{ display: tab === "home" ? "block" : "none" }}>
            <HomePanel onNavigate={changeTab} profile={profile} />
          </div>
        )}
        {visitedTabs.has("projects") && (
          <div style={{ display: tab === "projects" ? "block" : "none" }}>
            <ProjectsPanel profile={profile} onOpen={setActiveProjectId} />
          </div>
        )}
        {visitedTabs.has("messages") && (
          <div
            style={
              // وقتی یک گفتگو باز است، چت را به‌صورت تمام‌صفحه (fixed) نمایش می‌دهیم
              // تا بتواند از ارتفاع واقعی صفحه‌نمایش استفاده کند (هدر بالا، پیام‌ها
              // با اسکرول داخلی وسط، ورودی پیام پایین). قبلاً این بخش به‌عنوان یک
              // div معمولیِ داخل صفحه‌ی اسکرول‌شونده رندر می‌شد که ارتفاع مشخصی
              // نداشت، در نتیجه هدر (اسم/عکس طرف مقابل) و چیدمان پیام‌ها/ورودی
              // به‌هم می‌ریخت. state مربوط به این کار (messengerThreadOpen) از قبل
              // در کد وجود داشت اما جایی برای تغییر چیدمان استفاده نشده بود.
              tab === "messages" && messengerThreadOpen
                ? {
                    position: "fixed",
                    inset: 0,
                    zIndex: 60,
                    display: "flex",
                    flexDirection: "column",
                    background: "var(--bg-0)",
                  }
                : { display: tab === "messages" ? "block" : "none" }
            }
          >
            <MessengerErrorBoundary>
              <MessengerPanel
                profile={profile}
                presence={presence}
                onThreadOpenChange={setMessengerThreadOpen}
                onOpenProfile={(userId) => {
                  changeTab("social");
                  setSocialProfileUserId(userId);
                }}
              />
            </MessengerErrorBoundary>
          </div>
        )}
        {visitedTabs.has("tools") && (
          <div style={{ display: tab === "tools" ? "block" : "none" }}>
            <ToolsPanel profile={profile} />
          </div>
        )}
        {visitedTabs.has("education") && (
          <div style={{ display: tab === "education" ? "block" : "none" }}>
            <EducationPanel profile={profile} />
          </div>
        )}
        {visitedTabs.has("social") && (
          <div style={{ display: tab === "social" ? "block" : "none" }}>
            {socialProfileUserId ? (
              <SocialProfilePanel profile={profile} userId={socialProfileUserId} onBack={() => setSocialProfileUserId(null)} />
            ) : (
              <SocialPanel profile={profile} onOpenProfile={setSocialProfileUserId} />
            )}
          </div>
        )}
        {visitedTabs.has("profile") && (
          <div style={{ display: tab === "profile" ? "block" : "none" }}>
            <ProfilePanel profile={profile} onUpdated={loadProfile} />
          </div>
        )}
        {visitedTabs.has("admin") && (
          <div style={{ display: tab === "admin" ? "block" : "none" }}>
            <AdminPanel profile={profile} />
          </div>
        )}
      </div>

      {/* ===== نوار پایین شناور ===== */}
      <div
        style={{
          position: "fixed", bottom: 16, left: 14, right: 14, zIndex: 40,
          display: "flex", justifyContent: "space-around", alignItems: "center",
          background: "linear-gradient(160deg, #1D1B22 0%, #141318 100%)",
          border: "1px solid rgba(197,3,55,0.28)",
          borderRadius: 20,
          padding: "9px 6px",
          boxShadow: "0 24px 44px -18px rgba(0,0,0,0.85), 0 1px 0 rgba(255,255,255,0.05) inset",
          maxWidth: 760, margin: "0 auto",
        }}
      >
        {navItems.map(({ key, label, Icon }) => {
          const active = tab === key;
          return (
            <button
              key={key}
              onClick={() => changeTab(key)}
              className="pressable"
              style={{
                background: active ? "linear-gradient(135deg, rgba(255,61,99,0.18), rgba(122,2,36,0.22))" : "none",
                border: "none",
                borderRadius: 13,
                padding: "7px 12px",
                display: "flex", flexDirection: "column", alignItems: "center", gap: 3,
                cursor: "pointer",
                transition: "background 0.2s ease",
              }}
            >
              <span key={active ? `${key}-on` : `${key}-off`} className={active ? "nav-item-icon-active" : ""}>
                <Icon size={19} color={active ? GOLD_LIGHT : "#3F4356"} />
              </span>
              <span style={{ fontSize: 10, color: active ? GOLD_LIGHT : "#3F4356", fontWeight: active ? 700 : 500, transition: "color 0.2s ease" }}>
                {label}
              </span>
            </button>
          );
        })}
      </div>

      {rolesOpen && (
        <RoleCenter
          profile={profile}
          onClose={() => setRolesOpen(false)}
          onChanged={() => { loadProfile(); loadActiveRoleLabel(); }}
        />
      )}
    </div>
  );
}
